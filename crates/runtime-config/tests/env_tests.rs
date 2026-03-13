use std::ffi::OsString;

use runtime_config::env::{build_launcher_env, child_process_path, DEFAULT_NPMRC_CONTENTS};
use runtime_config::layout::InstallLayout;

#[test]
fn launcher_env_sets_openclaw_paths_and_local_npmrc() {
    let layout = InstallLayout::new("D:\\OpenClaw".into());
    let envs = build_launcher_env(&layout);

    assert_eq!(envs["OPENCLAW_HOME"], "D:\\OpenClaw\\data");
    assert_eq!(envs["OPENCLAW_STATE_DIR"], "D:\\OpenClaw\\data");
    assert_eq!(
        envs["OPENCLAW_CONFIG_PATH"],
        "D:\\OpenClaw\\data\\config\\openclaw.json"
    );
    assert_eq!(envs["NPM_CONFIG_USERCONFIG"], "D:\\OpenClaw\\data\\config\\npmrc");
    assert_eq!(
        DEFAULT_NPMRC_CONTENTS,
        "registry=https://registry.npmmirror.com/\n"
    );
}

#[test]
fn child_process_path_prefixes_embedded_node_dir() {
    let layout = InstallLayout::new("D:\\OpenClaw".into());
    let vars = vec![(
        OsString::from("PATH"),
        OsString::from("C:\\Windows\\System32;C:\\Windows"),
    )]
    .into_iter();

    let path = child_process_path(&layout, &mut vars.into_iter());

    assert_eq!(
        path,
        "D:\\OpenClaw\\app\\node;C:\\Windows\\System32;C:\\Windows"
    );
}
