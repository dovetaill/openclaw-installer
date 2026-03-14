use runtime_config::manifest::PayloadManifest;

const LAUNCHER_NAME: &str = "OpenClaw Launcher";
const INSTALLER_REPOSITORY_URL: &str = "https://github.com/kitlabs-app/openclaw-installer";

pub fn installer_repository_url() -> &'static str {
    INSTALLER_REPOSITORY_URL
}

pub fn runtime_label(manifest: Option<&PayloadManifest>) -> String {
    match manifest {
        Some(manifest) => format!("Runtime: {}", manifest.runtime_display()),
        None => "Runtime: unknown".into(),
    }
}

pub fn window_title(manifest: Option<&PayloadManifest>) -> String {
    match manifest {
        Some(manifest) => format!("{LAUNCHER_NAME} · {}", manifest.runtime_display()),
        None => LAUNCHER_NAME.into(),
    }
}

pub fn heading_text(manifest: Option<&PayloadManifest>) -> String {
    window_title(manifest)
}
