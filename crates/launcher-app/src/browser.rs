use std::process::Command;

pub fn open_local_url(url: &str) -> Result<(), String> {
    open_target(url)
}

pub fn open_target(target: &str) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    let status = {
        let mut command = Command::new("cmd");
        command.args(["/C", "start", ""]);
        command.arg(target);
        command.status()
    };

    #[cfg(target_os = "macos")]
    let status = Command::new("open").arg(target).status();

    #[cfg(all(unix, not(target_os = "macos")))]
    let status = Command::new("xdg-open").arg(target).status();

    status
        .map_err(|error| format!("failed to open target: {error}"))
        .and_then(|status| {
            status
                .success()
                .then_some(())
                .ok_or_else(|| format!("open command exited with status {status}"))
        })
}
