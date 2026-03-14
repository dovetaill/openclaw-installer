#![allow(dead_code)]

#[path = "../src/browser.rs"]
mod browser;

#[path = "../src/diagnostics.rs"]
mod diagnostics;

use diagnostics::diagnostics_commands;
use std::path::PathBuf;

#[test]
fn diagnostics_commands_target_local_embedded_runtime() {
    let cmds = diagnostics_commands("D:\\OpenClaw");

    assert!(cmds.iter().any(|c| c.contains("openclaw config validate")));
    assert!(cmds.iter().any(|c| c.contains("openclaw skills check")));
}

#[test]
fn ensure_directory_target_creates_missing_directories() {
    let temp_root = std::env::temp_dir().join(format!("openclaw-launcher-test-{}", std::process::id()));
    let target_dir = temp_root.join("data").join("logs");

    if temp_root.exists() {
        std::fs::remove_dir_all(&temp_root).unwrap();
    }

    let prepared = diagnostics::ensure_directory_target(&target_dir).unwrap();

    assert_eq!(PathBuf::from(prepared), target_dir);
    assert!(target_dir.is_dir());

    std::fs::remove_dir_all(&temp_root).unwrap();
}
