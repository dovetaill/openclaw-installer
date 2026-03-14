use std::path::Path;

#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
pub struct PayloadManifest {
    #[serde(default)]
    pub installer_version: String,
    #[serde(default, rename = "version", skip_serializing)]
    legacy_version: String,
    #[serde(default)]
    pub node_version: String,
    #[serde(default)]
    pub runtime_source: String,
    #[serde(default)]
    pub runtime_package: String,
    #[serde(default)]
    pub runtime_version: String,
    #[serde(default)]
    pub runtime_release_tag: String,
    #[serde(default)]
    pub runtime_release_url: String,
    #[serde(default)]
    pub runtime_display_name: String,
    #[serde(default)]
    pub runtime_display_version: String,
    #[serde(default)]
    pub entries: Vec<BundleEntry>,
}

impl PayloadManifest {
    pub fn from_install_root(root: &Path) -> Result<Self, String> {
        Self::from_path(&root.join("manifest.json"))
    }

    pub fn from_path(path: &Path) -> Result<Self, String> {
        let contents = std::fs::read_to_string(path)
            .map_err(|error| format!("failed to read manifest {}: {error}", path.to_string_lossy()))?;

        let mut manifest: Self = serde_json::from_str(&contents)
            .map_err(|error| format!("failed to parse manifest {}: {error}", path.to_string_lossy()))?;

        if manifest.installer_version.trim().is_empty() {
            manifest.installer_version = manifest.legacy_version.trim().to_string();
        }

        Ok(manifest)
    }

    pub fn runtime_display(&self) -> String {
        if !self.runtime_display_version.trim().is_empty() {
            return self.runtime_display_version.trim().to_string();
        }

        match (
            self.runtime_display_name.trim(),
            self.runtime_version.trim(),
        ) {
            ("", "") => "unknown".into(),
            (name, "") => name.to_string(),
            ("", version) => format!("v{version}"),
            (name, version) => format!("{name} v{version}"),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
pub struct BundleEntry {
    pub name: String,
    pub path: String,
}
