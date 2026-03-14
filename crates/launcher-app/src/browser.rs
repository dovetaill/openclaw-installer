use std::path::Path;
use std::process::Command;

use serde::Deserialize;

pub fn open_dashboard(install_root: &str, port: &str) -> Result<(), String> {
    let url = dashboard_url(install_root, port)?;
    open_local_url(&url)
}

pub fn dashboard_url(install_root: &str, port: &str) -> Result<String, String> {
    let base = format!("http://127.0.0.1:{port}/");
    let token = read_gateway_token(install_root)?;

    Ok(match token {
        Some(token) => format!("{base}#token={}", encode_fragment_value(&token)),
        None => base,
    })
}

pub fn open_local_url(url: &str) -> Result<(), String> {
    open_target(url)
}

pub fn open_target(target: &str) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    let status = {
        let mut command = Command::new("cmd");
        command.args(["/C", "start", ""]);
        command.arg(target);
        command.status()
    };

    #[cfg(target_os = "macos")]
    let status = Command::new("open").arg(target).status();

    #[cfg(all(unix, not(target_os = "macos")))]
    let status = Command::new("xdg-open").arg(target).status();

    status
        .map_err(|error| format!("failed to open target: {error}"))
        .and_then(|status| {
            status
                .success()
                .then_some(())
                .ok_or_else(|| format!("open command exited with status {status}"))
        })
}

fn read_gateway_token(install_root: &str) -> Result<Option<String>, String> {
    let config_path = Path::new(install_root)
        .join("data")
        .join("config")
        .join("openclaw.json");

    if !config_path.exists() {
        return Ok(None);
    }

    let config = std::fs::read_to_string(&config_path).map_err(|error| {
        format!(
            "failed to read OpenClaw config {}: {error}",
            config_path.to_string_lossy()
        )
    })?;

    let parsed: OpenClawConfig = serde_json::from_str(&config).map_err(|error| {
        format!(
            "failed to parse OpenClaw config {}: {error}",
            config_path.to_string_lossy()
        )
    })?;

    Ok(parsed
        .gateway
        .and_then(|gateway| gateway.auth)
        .and_then(|auth| auth.token)
        .filter(|token| !token.trim().is_empty()))
}

fn encode_fragment_value(raw: &str) -> String {
    let mut encoded = String::new();

    for byte in raw.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                encoded.push(char::from(byte));
            }
            _ => encoded.push_str(&format!("%{byte:02X}")),
        }
    }

    encoded
}

#[derive(Deserialize)]
struct OpenClawConfig {
    gateway: Option<GatewayConfig>,
}

#[derive(Deserialize)]
struct GatewayConfig {
    auth: Option<GatewayAuthConfig>,
}

#[derive(Deserialize)]
struct GatewayAuthConfig {
    token: Option<String>,
}
