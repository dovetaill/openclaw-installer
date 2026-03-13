use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstallLayout {
    root: PathBuf,
}

impl InstallLayout {
    pub fn new(root: PathBuf) -> Self {
        Self { root }
    }

    pub fn root(&self) -> &PathBuf {
        &self.root
    }

    pub fn app_dir(&self) -> PathBuf {
        self.child("app")
    }

    pub fn data_dir(&self) -> PathBuf {
        self.child("data")
    }

    pub fn config_dir(&self) -> PathBuf {
        self.child("data\\config")
    }

    pub fn node_dir(&self) -> PathBuf {
        self.child("app\\node")
    }

    pub fn openclaw_dir(&self) -> PathBuf {
        self.child("app\\openclaw")
    }

    pub fn workspace_dir(&self) -> PathBuf {
        self.child("data\\workspace")
    }

    pub fn managed_skills_dir(&self) -> PathBuf {
        self.child("data\\skills")
    }

    pub fn npmrc_path(&self) -> PathBuf {
        self.child("data\\config\\npmrc")
    }

    pub fn openclaw_config_path(&self) -> PathBuf {
        self.child("data\\config\\openclaw.json")
    }

    fn child(&self, suffix: &str) -> PathBuf {
        PathBuf::from(format!(r"{}\{}", self.root_string(), suffix))
    }

    fn root_string(&self) -> String {
        self.root
            .to_string_lossy()
            .trim_end_matches(['\\', '/'])
            .to_string()
    }
}
