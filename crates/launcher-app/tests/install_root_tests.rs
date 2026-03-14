#![allow(dead_code)]

#[path = "../src/install_root.rs"]
mod install_root;

use std::path::PathBuf;

#[test]
fn resolve_install_root_uses_launcher_exe_parent_directory() {
    let launcher_exe = PathBuf::from(r"F:\work\openclaw\install\OpenClaw Launcher.exe");

    let install_root = install_root::resolve_install_root_from_exe_path(&launcher_exe).unwrap();

    assert_eq!(install_root.to_string_lossy(), r"F:\work\openclaw\install");
}
