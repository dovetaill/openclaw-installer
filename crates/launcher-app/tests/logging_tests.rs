#![allow(dead_code)]

#[path = "../src/install_root.rs"]
mod install_root;

#[path = "../src/logging.rs"]
mod logging;

use std::path::PathBuf;

fn temp_install_root(name: &str) -> PathBuf {
    let root = std::env::temp_dir().join(format!(
        "openclaw-launcher-logging-{}-{}-{}",
        name,
        std::process::id(),
        std::thread::current().name().unwrap_or("main")
    ));

    if root.exists() {
        std::fs::remove_dir_all(&root).unwrap();
    }

    std::fs::create_dir_all(&root).unwrap();
    root
}

#[test]
fn init_logging_creates_install_local_logs_directory() {
    let install_root = temp_install_root("init");

    let state = logging::init_logging_for_install_root(&install_root).unwrap();

    assert_eq!(state.log_dir, install_root.join("data").join("logs"));
    assert!(state.log_dir.is_dir());

    std::fs::remove_dir_all(&install_root).unwrap();
}

#[test]
fn info_and_error_records_append_to_launcher_log() {
    let install_root = temp_install_root("events");

    let state = logging::init_logging_for_install_root(&install_root).unwrap();
    logging::write_info(&state, "launcher starting").unwrap();
    logging::write_error(&state, "launcher failed to schedule startup").unwrap();

    let contents = std::fs::read_to_string(state.log_dir.join("launcher.log")).unwrap();

    assert!(contents.contains("INFO"));
    assert!(contents.contains("launcher starting"));
    assert!(contents.contains("ERROR"));
    assert!(contents.contains("launcher failed to schedule startup"));

    std::fs::remove_dir_all(&install_root).unwrap();
}

#[test]
fn crash_records_append_to_launcher_crash_log() {
    let install_root = temp_install_root("crash");

    let state = logging::init_logging_for_install_root(&install_root).unwrap();
    logging::write_crash(
        &state,
        "panic",
        Some("src/main.rs:42"),
        "simulated panic payload",
        "stack backtrace:\n<frames>",
    )
    .unwrap();

    let contents = std::fs::read_to_string(state.log_dir.join("launcher-crash.log")).unwrap();

    assert!(contents.contains("panic"));
    assert!(contents.contains("src/main.rs:42"));
    assert!(contents.contains("simulated panic payload"));
    assert!(contents.contains("stack backtrace"));

    std::fs::remove_dir_all(&install_root).unwrap();
}
