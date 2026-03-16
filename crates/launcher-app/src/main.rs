mod app;
mod browser;
mod diagnostics;
mod install_root;
mod launcher;
mod logging;
mod metadata;
mod state;

fn main() {
    let logger = logging::init_global_logging().ok();

    if let Some(logger) = logger {
        logging::install_panic_hook(logger);
        let _ = logging::log_info(&format!(
            "launcher starting from {}; logs={}",
            logger.install_root.to_string_lossy(),
            logger.log_dir.to_string_lossy()
        ));
    }

    if let Err(error) = app::run() {
        let _ = logging::record_top_level_error(error.as_ref());
        std::process::exit(1);
    }
}
