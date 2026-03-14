#![allow(dead_code)]

#[path = "../src/browser.rs"]
mod browser;

use std::path::PathBuf;

#[test]
fn dashboard_url_includes_fragment_token_from_openclaw_config() {
    let temp_root = std::env::temp_dir().join(format!(
        "openclaw-dashboard-url-test-{}",
        std::process::id()
    ));
    let config_dir = temp_root.join("data").join("config");
    let config_path = config_dir.join("openclaw.json");

    if temp_root.exists() {
        std::fs::remove_dir_all(&temp_root).unwrap();
    }

    std::fs::create_dir_all(&config_dir).unwrap();
    std::fs::write(
        &config_path,
        r#"{"gateway":{"auth":{"token":"test-token-123"}}}"#,
    )
    .unwrap();

    let url = browser::dashboard_url(temp_root.to_str().unwrap(), "18789").unwrap();

    assert_eq!(url, "http://127.0.0.1:18789/#token=test-token-123");

    std::fs::remove_dir_all(&temp_root).unwrap();
}

#[test]
fn dashboard_url_falls_back_to_local_root_when_token_is_unavailable() {
    let temp_root = PathBuf::from(std::env::temp_dir()).join(format!(
        "openclaw-dashboard-url-missing-token-{}",
        std::process::id()
    ));

    if temp_root.exists() {
        std::fs::remove_dir_all(&temp_root).unwrap();
    }

    std::fs::create_dir_all(&temp_root).unwrap();

    let url = browser::dashboard_url(temp_root.to_str().unwrap(), "18789").unwrap();

    assert_eq!(url, "http://127.0.0.1:18789/");

    std::fs::remove_dir_all(&temp_root).unwrap();
}
