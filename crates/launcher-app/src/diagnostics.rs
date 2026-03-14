use std::path::PathBuf;
use std::process::Command;

use runtime_config::env::{build_launcher_env, child_process_path};
use runtime_config::layout::InstallLayout;

use crate::browser::open_target;

#[allow(dead_code)]
pub fn diagnostics_commands(install_root: &str) -> Vec<String> {
    let layout = install_layout(install_root);
    let node_exe = quote(&windows_child(&layout.node_dir(), "node.exe"));
    let openclaw_entry = quote(&windows_child(&layout.openclaw_dir(), "openclaw.mjs"));
    let logs_dir = quote(&PathBuf::from(format!(r"{}\data\logs", normalize_install_root(install_root))));
    let config_dir = quote(&layout.config_dir());

    vec![
        format!("open log dir -> {logs_dir}"),
        format!("open config dir -> {config_dir}"),
        format!("openclaw config validate -> {node_exe} {openclaw_entry} config validate"),
        format!("openclaw skills check -> {node_exe} {openclaw_entry} skills check"),
    ]
}

pub fn open_log_dir(install_root: &str) -> Result<(), String> {
    let target = PathBuf::from(format!(r"{}\data\logs", normalize_install_root(install_root)));
    open_target(&ensure_directory_target(&target)?)
}

pub fn open_config_dir(install_root: &str) -> Result<(), String> {
    let layout = install_layout(install_root);
    open_target(&ensure_directory_target(&layout.config_dir())?)
}

pub fn validate_config(install_root: &str) -> Result<(), String> {
    run_embedded_openclaw(install_root, ["config", "validate"])
}

pub fn check_skills(install_root: &str) -> Result<(), String> {
    run_embedded_openclaw(install_root, ["skills", "check"])
}

fn run_embedded_openclaw<const N: usize>(
    install_root: &str,
    args: [&str; N],
) -> Result<(), String> {
    let layout = install_layout(install_root);
    let node_exe = windows_child(&layout.node_dir(), "node.exe");
    let openclaw_entry = windows_child(&layout.openclaw_dir(), "openclaw.mjs");

    if !node_exe.exists() {
        return Err(format!(
            "embedded node runtime not found: {}",
            node_exe.to_string_lossy()
        ));
    }

    if !openclaw_entry.exists() {
        return Err(format!(
            "embedded openclaw entrypoint not found: {}",
            openclaw_entry.to_string_lossy()
        ));
    }

    let mut command = Command::new(&node_exe);
    command.arg(&openclaw_entry);
    command.args(args);

    for (key, value) in build_launcher_env(&layout) {
        command.env(key, value);
    }

    let mut current_env = std::env::vars_os();
    command.env("PATH", child_process_path(&layout, &mut current_env));

    let status = command
        .status()
        .map_err(|error| format!("failed to run diagnostic command: {error}"))?;

    status
        .success()
        .then_some(())
        .ok_or_else(|| format!("diagnostic command exited with status {status}"))
}

fn install_layout(install_root: &str) -> InstallLayout {
    InstallLayout::new(normalize_install_root(install_root).into())
}

fn normalize_install_root(root: &str) -> String {
    root.trim_end_matches(['\\', '/']).to_string()
}

fn windows_child(base: &std::path::Path, leaf: &str) -> PathBuf {
    PathBuf::from(format!(r"{}\{}", base.to_string_lossy(), leaf))
}

fn quote(path: &std::path::Path) -> String {
    format!("\"{}\"", path.to_string_lossy())
}

pub fn ensure_directory_target(path: &std::path::Path) -> Result<String, String> {
    std::fs::create_dir_all(path)
        .map_err(|error| format!("failed to prepare directory target {}: {error}", path.to_string_lossy()))?;

    Ok(path.to_string_lossy().into_owned())
}
