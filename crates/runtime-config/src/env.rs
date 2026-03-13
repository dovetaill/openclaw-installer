use std::collections::BTreeMap;
use std::ffi::{OsStr, OsString};

use crate::layout::InstallLayout;
use crate::openclaw_paths::OpenClawPaths;

pub const DEFAULT_NPMRC_CONTENTS: &str = "registry=https://registry.npmmirror.com/\n";

pub fn build_launcher_env(layout: &InstallLayout) -> BTreeMap<String, String> {
    let paths = OpenClawPaths::from_layout(layout);
    let mut envs = BTreeMap::new();

    envs.insert("OPENCLAW_HOME".into(), to_string(&paths.home));
    envs.insert("OPENCLAW_STATE_DIR".into(), to_string(&paths.state_dir));
    envs.insert("OPENCLAW_CONFIG_PATH".into(), to_string(&paths.config_path));
    envs.insert("NPM_CONFIG_USERCONFIG".into(), to_string(&layout.npmrc_path()));

    envs
}

pub fn child_process_path<I>(layout: &InstallLayout, vars: &mut I) -> String
where
    I: Iterator<Item = (OsString, OsString)>,
{
    let node_dir = to_string(&layout.node_dir());
    let current_path = vars
        .find_map(|(key, value)| (key == OsStr::new("PATH")).then_some(value))
        .map(|value| value.to_string_lossy().into_owned());

    match current_path {
        Some(path) if !path.is_empty() => format!("{node_dir};{path}"),
        _ => node_dir,
    }
}

fn to_string(path: &std::path::Path) -> String {
    path.to_string_lossy().into_owned()
}
