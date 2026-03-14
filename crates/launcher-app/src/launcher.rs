use std::cell::Cell;

use process_supervisor::port_probe::choose_openclaw_port;
use process_supervisor::supervisor::{format_start_failure, ProcessSupervisor, SupervisorStatus};
use runtime_config::layout::InstallLayout;

pub struct LauncherController {
    layout: InstallLayout,
    supervisor: ProcessSupervisor,
    preflight_port: Cell<Option<u16>>,
}

impl LauncherController {
    pub fn new(layout: InstallLayout) -> Result<Self, String> {
        Ok(Self {
            layout,
            supervisor: ProcessSupervisor::new(),
            preflight_port: Cell::new(None),
        })
    }

    pub fn install_root(&self) -> String {
        self.layout.root().to_string_lossy().into_owned()
    }

    pub fn preflight(&self) -> Result<u16, String> {
        if let Some(port) = self.supervisor.current_port() {
            self.preflight_port.set(Some(port));
            return Ok(port);
        }

        let port = choose_openclaw_port().map_err(|error| error.to_string())?;
        self.preflight_port.set(Some(port));
        Ok(port)
    }

    pub async fn start(&self) -> Result<u16, String> {
        let port = self
            .preflight_port
            .take()
            .or(self.supervisor.current_port())
            .unwrap_or_else(|| choose_openclaw_port().unwrap_or(18_789));

        self.supervisor
            .start_with_port(&self.layout, port)
            .await
            .map_err(|error| format_start_failure(&error, &self.supervisor.stderr_lines()))
    }

    pub async fn stop(&self) -> Result<(), String> {
        self.preflight_port.set(None);
        self.supervisor
            .stop()
            .await
            .map_err(|error| error.to_string())
    }

    pub fn status(&self) -> SupervisorStatus {
        self.supervisor.status()
    }

    pub fn current_port(&self) -> Option<u16> {
        self.supervisor.current_port()
    }
}
