use std::path::{Path, PathBuf};

pub fn resolve_install_root() -> Result<PathBuf, String> {
    let launcher_exe = std::env::current_exe()
        .map_err(|error| format!("failed to resolve launcher executable path: {error}"))?;

    resolve_install_root_from_exe_path(&launcher_exe)
}

pub fn resolve_install_root_from_exe_path(launcher_exe: &Path) -> Result<PathBuf, String> {
    let normalized = launcher_exe
        .to_string_lossy()
        .trim_end_matches(['\\', '/'])
        .to_string();

    normalized
        .rsplit_once(['\\', '/'])
        .map(|(parent, _)| PathBuf::from(parent))
        .ok_or_else(|| {
            format!(
                "failed to resolve install root from launcher executable: {}",
                launcher_exe.to_string_lossy()
            )
        })
}
