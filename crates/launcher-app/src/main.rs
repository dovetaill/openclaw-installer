mod app;
mod launcher;
mod state;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run()
}
