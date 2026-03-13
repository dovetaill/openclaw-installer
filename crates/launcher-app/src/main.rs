mod app;
mod browser;
mod diagnostics;
mod launcher;
mod state;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run()
}
