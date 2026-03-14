mod app;
mod browser;
mod diagnostics;
mod install_root;
mod launch_flow;
mod launcher;
mod state;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run()
}
