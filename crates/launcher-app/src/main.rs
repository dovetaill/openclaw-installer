mod app;
mod browser;
mod diagnostics;
mod install_root;
mod launcher;
mod metadata;
mod state;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run()
}
