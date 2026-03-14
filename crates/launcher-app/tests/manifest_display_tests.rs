#![allow(dead_code)]

#[path = "../src/metadata.rs"]
mod metadata;

use runtime_config::manifest::PayloadManifest;

fn manifest(runtime_display_name: &str, runtime_version: &str) -> PayloadManifest {
    serde_json::from_str(&format!(
        r#"{{
  "installer_version": "0.1.0",
  "node_version": "24.x",
  "runtime_display_name": "{runtime_display_name}",
  "runtime_version": "{runtime_version}",
  "runtime_display_version": "{runtime_display_name} v{runtime_version}",
  "entries": []
}}"#
    ))
    .unwrap()
}

#[test]
fn runtime_label_uses_manifest_runtime_display() {
    let manifest = manifest("OpenClaw", "2026.3.13");

    assert_eq!(
        metadata::runtime_label(Some(&manifest)),
        "Runtime: OpenClaw v2026.3.13"
    );
}

#[test]
fn runtime_label_falls_back_to_unknown_without_manifest() {
    assert_eq!(metadata::runtime_label(None), "Runtime: unknown");
}

#[test]
fn installer_repository_url_matches_project_repository() {
    assert_eq!(
        metadata::installer_repository_url(),
        "https://github.com/kitlabs-app/openclaw-installer"
    );
}
