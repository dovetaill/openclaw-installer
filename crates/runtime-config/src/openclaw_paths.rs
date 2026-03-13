use std::path::PathBuf;

use crate::layout::InstallLayout;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OpenClawPaths {
    pub home: PathBuf,
    pub state_dir: PathBuf,
    pub config_path: PathBuf,
    pub workspace_dir: PathBuf,
    pub managed_skills_dir: PathBuf,
}

impl OpenClawPaths {
    pub fn from_layout(layout: &InstallLayout) -> Self {
        Self {
            home: layout.data_dir(),
            state_dir: layout.data_dir(),
            config_path: layout.openclaw_config_path(),
            workspace_dir: layout.workspace_dir(),
            managed_skills_dir: layout.managed_skills_dir(),
        }
    }
}
