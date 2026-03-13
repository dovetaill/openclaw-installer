use runtime_config::layout::InstallLayout;

#[test]
fn install_layout_builds_expected_paths() {
    let layout = InstallLayout::new("D:\\OpenClaw".into());

    assert_eq!(layout.app_dir().to_string_lossy(), "D:\\OpenClaw\\app");
    assert_eq!(layout.data_dir().to_string_lossy(), "D:\\OpenClaw\\data");
    assert_eq!(
        layout.openclaw_config_path().to_string_lossy(),
        "D:\\OpenClaw\\data\\config\\openclaw.json"
    );
}
