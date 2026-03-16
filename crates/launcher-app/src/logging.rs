use std::backtrace::Backtrace;
use std::fs::{create_dir_all, OpenOptions};
use std::io::Write;
use std::panic::{self, PanicHookInfo};
use std::path::{Path, PathBuf};
use std::sync::{Once, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

use crate::install_root;

static GLOBAL_LOGGING_STATE: OnceLock<LoggingState> = OnceLock::new();
static PANIC_HOOK_INSTALLED: Once = Once::new();

#[derive(Debug, Clone)]
pub struct LoggingState {
    pub install_root: PathBuf,
    pub log_dir: PathBuf,
    launcher_log_path: PathBuf,
    crash_log_path: PathBuf,
}

pub fn init_global_logging() -> Result<&'static LoggingState, String> {
    if let Some(state) = GLOBAL_LOGGING_STATE.get() {
        return Ok(state);
    }

    let install_root = install_root::resolve_install_root()?;
    let state = init_logging_for_install_root(&install_root)?;

    let _ = GLOBAL_LOGGING_STATE.set(state);
    Ok(GLOBAL_LOGGING_STATE
        .get()
        .expect("global logging state should be initialized"))
}

pub fn init_logging_for_install_root(install_root: &Path) -> Result<LoggingState, String> {
    let log_dir = install_root.join("data").join("logs");
    create_dir_all(&log_dir).map_err(|error| {
        format!(
            "failed to create launcher log directory {}: {error}",
            log_dir.to_string_lossy()
        )
    })?;

    Ok(LoggingState {
        install_root: install_root.to_path_buf(),
        launcher_log_path: log_dir.join("launcher.log"),
        crash_log_path: log_dir.join("launcher-crash.log"),
        log_dir,
    })
}

pub fn install_panic_hook(_state: &'static LoggingState) {
    PANIC_HOOK_INSTALLED.call_once(|| {
        let previous_hook = panic::take_hook();
        panic::set_hook(Box::new(move |info| {
            let _ = record_panic(info);
            previous_hook(info);
        }));
    });
}

pub fn log_info(message: &str) -> Result<(), String> {
    match GLOBAL_LOGGING_STATE.get() {
        Some(state) => write_info(state, message),
        None => Ok(()),
    }
}

pub fn log_error(message: &str) -> Result<(), String> {
    match GLOBAL_LOGGING_STATE.get() {
        Some(state) => write_error(state, message),
        None => Ok(()),
    }
}

pub fn write_info(state: &LoggingState, message: &str) -> Result<(), String> {
    append_log_line(&state.launcher_log_path, "INFO", message)
}

pub fn write_error(state: &LoggingState, message: &str) -> Result<(), String> {
    append_log_line(&state.launcher_log_path, "ERROR", message)
}

pub fn write_crash(
    state: &LoggingState,
    kind: &str,
    location: Option<&str>,
    message: &str,
    backtrace: &str,
) -> Result<(), String> {
    ensure_parent_directory(&state.crash_log_path)?;
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&state.crash_log_path)
        .map_err(|error| {
            format!(
                "failed to open crash log {}: {error}",
                state.crash_log_path.to_string_lossy()
            )
        })?;

    writeln!(
        file,
        "[{}] [{}] kind={kind}",
        timestamp(),
        std::process::id()
    )
    .map_err(|error| format!("failed to write crash header: {error}"))?;

    if let Some(location) = location {
        writeln!(file, "location: {location}")
            .map_err(|error| format!("failed to write crash location: {error}"))?;
    }

    writeln!(file, "message: {message}")
        .map_err(|error| format!("failed to write crash message: {error}"))?;
    writeln!(file, "backtrace:\n{backtrace}")
        .map_err(|error| format!("failed to write crash backtrace: {error}"))?;
    writeln!(file, "---").map_err(|error| format!("failed to finalize crash log: {error}"))?;

    Ok(())
}

pub fn record_top_level_error(error: &dyn std::fmt::Display) -> Result<(), String> {
    log_error(&format!("launcher fatal error: {error}"))
}

fn record_panic(info: &PanicHookInfo<'_>) -> Result<(), String> {
    let Some(state) = GLOBAL_LOGGING_STATE.get() else {
        return Ok(());
    };

    let location = info
        .location()
        .map(|location| format!("{}:{}", location.file(), location.line()));
    let thread_name = std::thread::current()
        .name()
        .map(str::to_string)
        .unwrap_or_else(|| "unnamed".to_string());
    let message = format!("thread={thread_name}; {}", panic_message(info));
    let backtrace = Backtrace::force_capture().to_string();

    let _ = write_error(
        state,
        &format!(
            "launcher panic{}: {}",
            location
                .as_ref()
                .map(|value| format!(" at {value}"))
                .unwrap_or_default(),
            message
        ),
    );

    write_crash(state, "panic", location.as_deref(), &message, &backtrace)
}

fn panic_message(info: &PanicHookInfo<'_>) -> String {
    if let Some(message) = info.payload().downcast_ref::<&str>() {
        return (*message).to_string();
    }

    if let Some(message) = info.payload().downcast_ref::<String>() {
        return message.clone();
    }

    "non-string panic payload".to_string()
}

fn append_log_line(path: &Path, level: &str, message: &str) -> Result<(), String> {
    ensure_parent_directory(path)?;
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .map_err(|error| {
            format!(
                "failed to open log file {}: {error}",
                path.to_string_lossy()
            )
        })?;

    writeln!(
        file,
        "[{}] [{}] [{level}] {message}",
        timestamp(),
        std::process::id()
    )
    .map_err(|error| {
        format!(
            "failed to append log file {}: {error}",
            path.to_string_lossy()
        )
    })
}

fn ensure_parent_directory(path: &Path) -> Result<(), String> {
    let Some(parent) = path.parent() else {
        return Ok(());
    };

    create_dir_all(parent).map_err(|error| {
        format!(
            "failed to create parent directory {}: {error}",
            parent.to_string_lossy()
        )
    })
}

fn timestamp() -> String {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    format!("{}.{:03}", now.as_secs(), now.subsec_millis())
}
