use std::path::PathBuf;

use runtime_config::manifest::PayloadManifest;

#[test]
fn payload_manifest_loads_runtime_metadata_from_install_root() {
    let install_root = PathBuf::from(std::env::temp_dir()).join(format!(
        "openclaw-manifest-test-{}",
        std::process::id()
    ));

    if install_root.exists() {
        std::fs::remove_dir_all(&install_root).unwrap();
    }

    std::fs::create_dir_all(&install_root).unwrap();
    std::fs::write(
        install_root.join("manifest.json"),
        r#"{
  "version": "0.1.0",
  "installer_version": "0.1.0",
  "node_version": "24.x",
  "runtime_source": "translated",
  "runtime_package": "@qingchencloud/openclaw-zh",
  "runtime_version": "2026.3.12-zh.2",
  "runtime_release_tag": "v2026.3.12-zh.2",
  "runtime_release_url": "https://github.com/1186258278/OpenClawChineseTranslation/releases/tag/v2026.3.12-zh.2",
  "runtime_display_name": "OpenClawChineseTranslation",
  "runtime_display_version": "OpenClawChineseTranslation v2026.3.12-zh.2",
  "entries": []
}"#,
    )
    .unwrap();

    let manifest = PayloadManifest::from_install_root(&install_root).unwrap();

    assert_eq!(manifest.runtime_source, "translated");
    assert_eq!(manifest.runtime_version, "2026.3.12-zh.2");
    assert_eq!(
        manifest.runtime_display(),
        "OpenClawChineseTranslation v2026.3.12-zh.2"
    );

    std::fs::remove_dir_all(&install_root).unwrap();
}

#[test]
fn payload_manifest_uses_version_alias_for_installer_version() {
    let install_root = PathBuf::from(std::env::temp_dir()).join(format!(
        "openclaw-manifest-version-alias-test-{}",
        std::process::id()
    ));

    if install_root.exists() {
        std::fs::remove_dir_all(&install_root).unwrap();
    }

    std::fs::create_dir_all(&install_root).unwrap();
    std::fs::write(
        install_root.join("manifest.json"),
        r#"{
  "version": "0.1.0",
  "node_version": "24.x",
  "runtime_display_name": "OpenClaw",
  "runtime_version": "2026.3.13",
  "entries": []
}"#,
    )
    .unwrap();

    let manifest = PayloadManifest::from_install_root(&install_root).unwrap();

    assert_eq!(manifest.installer_version, "0.1.0");
    assert_eq!(manifest.runtime_display(), "OpenClaw v2026.3.13");

    std::fs::remove_dir_all(&install_root).unwrap();
}
