use std::cell::{Cell, RefCell};
use std::io;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use runtime_config::env::{build_launcher_env, child_process_path};
use runtime_config::layout::InstallLayout;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::{Child, Command};

use crate::port_probe::choose_openclaw_port;
use crate::readiness::wait_for_tcp_ready;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SupervisorStatus {
    Idle,
    Starting,
    Ready,
    Failed,
    Stopped,
}

pub const STARTUP_POLL_INTERVAL: Duration = Duration::from_millis(250);
pub const STARTUP_MAX_ATTEMPTS: usize = 180;

pub struct ProcessSupervisor {
    child: RefCell<Option<Child>>,
    current_port: Cell<Option<u16>>,
    status: Cell<SupervisorStatus>,
    stdout_lines: Arc<Mutex<Vec<String>>>,
    stderr_lines: Arc<Mutex<Vec<String>>>,
}

pub fn openclaw_gateway_args(port: u16) -> Vec<String> {
    vec![
        "gateway".into(),
        "run".into(),
        "--allow-unconfigured".into(),
        "--port".into(),
        port.to_string(),
    ]
}

pub fn startup_timeout() -> Duration {
    Duration::from_millis(STARTUP_POLL_INTERVAL.as_millis() as u64 * STARTUP_MAX_ATTEMPTS as u64)
}

pub fn format_start_failure(error: &io::Error, stderr_lines: &[String]) -> String {
    const MAX_STDERR_LINES: usize = 8;

    if stderr_lines.is_empty() {
        return error.to_string();
    }

    let recent_lines = stderr_lines
        .iter()
        .rev()
        .take(MAX_STDERR_LINES)
        .cloned()
        .collect::<Vec<_>>();

    format!(
        "{error}\nRecent stderr:\n{}",
        recent_lines
            .into_iter()
            .rev()
            .map(|line| format!("- {line}"))
            .collect::<Vec<_>>()
            .join("\n")
    )
}

impl Default for ProcessSupervisor {
    fn default() -> Self {
        Self::new()
    }
}

impl ProcessSupervisor {
    pub fn new() -> Self {
        Self {
            child: RefCell::new(None),
            current_port: Cell::new(None),
            status: Cell::new(SupervisorStatus::Idle),
            stdout_lines: Arc::new(Mutex::new(Vec::new())),
            stderr_lines: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub async fn start(&self, layout: &InstallLayout) -> io::Result<u16> {
        let port = choose_openclaw_port()?;
        self.start_with_port(layout, port).await
    }

    pub async fn start_with_port(&self, layout: &InstallLayout, port: u16) -> io::Result<u16> {
        self.refresh_terminated_child();

        if matches!(
            self.status.get(),
            SupervisorStatus::Starting | SupervisorStatus::Ready
        ) {
            if let Some(current_port) = self.current_port.get() {
                return Ok(current_port);
            }
        }

        self.cleanup_child().await?;
        self.clear_output_buffers();

        let node_exe = windows_child(&layout.node_dir(), "node.exe");
        let openclaw_entry = windows_child(&layout.openclaw_dir(), "openclaw.mjs");

        if !node_exe.exists() {
            self.fail_start();
            return Err(io::Error::new(
                io::ErrorKind::NotFound,
                format!("missing embedded runtime: {}", node_exe.to_string_lossy()),
            ));
        }

        if !openclaw_entry.exists() {
            self.fail_start();
            return Err(io::Error::new(
                io::ErrorKind::NotFound,
                format!(
                    "missing OpenClaw entrypoint: {}",
                    openclaw_entry.to_string_lossy()
                ),
            ));
        }

        let mut command = Command::new(&node_exe);
        command.arg(&openclaw_entry);
        command.args(openclaw_gateway_args(port));
        command.stdout(Stdio::piped());
        command.stderr(Stdio::piped());

        for (key, value) in build_launcher_env(layout) {
            command.env(key, value);
        }

        let mut current_env = std::env::vars_os();
        command.env("PATH", child_process_path(layout, &mut current_env));

        self.status.set(SupervisorStatus::Starting);
        let mut child = match command.spawn() {
            Ok(child) => child,
            Err(error) => {
                self.fail_start();
                return Err(error);
            }
        };

        if let Some(stdout) = child.stdout.take() {
            collect_output(stdout, self.stdout_lines.clone());
        }

        if let Some(stderr) = child.stderr.take() {
            collect_output(stderr, self.stderr_lines.clone());
        }

        self.current_port.set(Some(port));
        self.child.replace(Some(child));

        match wait_for_tcp_ready(port, STARTUP_MAX_ATTEMPTS, STARTUP_POLL_INTERVAL).await {
            Ok(()) => {
                self.status.set(SupervisorStatus::Ready);
                Ok(port)
            }
            Err(error) => {
                let cleanup_error = self.cleanup_child().await.err();
                self.status.set(SupervisorStatus::Failed);

                if let Some(cleanup_error) = cleanup_error {
                    return Err(io::Error::new(
                        cleanup_error.kind(),
                        format!("{error}; cleanup failed: {cleanup_error}"),
                    ));
                }

                Err(error)
            }
        }
    }

    pub async fn stop(&self) -> io::Result<()> {
        self.cleanup_child().await?;
        self.status.set(SupervisorStatus::Stopped);
        Ok(())
    }

    pub async fn restart(&self, layout: &InstallLayout) -> io::Result<u16> {
        self.stop().await?;
        self.start(layout).await
    }

    pub fn status(&self) -> SupervisorStatus {
        self.refresh_terminated_child();
        self.status.get()
    }

    pub fn current_port(&self) -> Option<u16> {
        self.refresh_terminated_child();
        self.current_port.get()
    }

    pub fn stdout_lines(&self) -> Vec<String> {
        self.stdout_lines.lock().unwrap().clone()
    }

    pub fn stderr_lines(&self) -> Vec<String> {
        self.stderr_lines.lock().unwrap().clone()
    }

    fn clear_output_buffers(&self) {
        self.stdout_lines.lock().unwrap().clear();
        self.stderr_lines.lock().unwrap().clear();
    }

    fn fail_start(&self) {
        self.current_port.set(None);
        self.status.set(SupervisorStatus::Failed);
    }

    fn refresh_terminated_child(&self) {
        let child_exited = {
            let mut child_slot = self.child.borrow_mut();
            match child_slot.as_mut() {
                Some(child) => match child.try_wait() {
                    Ok(Some(_)) | Err(_) => true,
                    Ok(None) => false,
                },
                None => false,
            }
        };

        if child_exited {
            self.child.borrow_mut().take();
            self.current_port.set(None);

            if matches!(
                self.status.get(),
                SupervisorStatus::Starting | SupervisorStatus::Ready
            ) {
                self.status.set(SupervisorStatus::Failed);
            }
        }
    }

    async fn cleanup_child(&self) -> io::Result<()> {
        let child = self.child.borrow_mut().take();

        if let Some(mut child) = child {
            match child.try_wait()? {
                Some(_) => {}
                None => {
                    let _ = child.kill().await;
                    let _ = child.wait().await;
                }
            }
        }

        self.current_port.set(None);
        Ok(())
    }
}

fn collect_output<R>(reader: R, sink: Arc<Mutex<Vec<String>>>)
where
    R: tokio::io::AsyncRead + Unpin + Send + 'static,
{
    tokio::spawn(async move {
        let mut lines = BufReader::new(reader).lines();
        while let Ok(Some(line)) = lines.next_line().await {
            sink.lock().unwrap().push(line);
        }
    });
}

fn windows_child(base: &Path, leaf: &str) -> PathBuf {
    PathBuf::from(format!(r"{}\{}", base.to_string_lossy(), leaf))
}
