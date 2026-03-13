#[derive(Debug, Clone, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
pub struct PayloadManifest {
    pub version: String,
    pub node_version: String,
    pub entries: Vec<BundleEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
pub struct BundleEntry {
    pub name: String,
    pub path: String,
}
