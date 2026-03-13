use std::cell::Cell;
use std::error::Error;
use std::rc::Rc;

use slint::{ComponentHandle, SharedString};

use crate::state::{LauncherEvent, LauncherState};

slint::include_modules!();

pub fn run() -> Result<(), Box<dyn Error>> {
    let ui = MainWindow::new()?;
    let state = Rc::new(Cell::new(LauncherState::Idle));

    ui.set_install_root(SharedString::from("D:\\OpenClaw"));
    ui.set_port(SharedString::from("18789"));
    sync_state_text(&ui, state.get());

    {
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_open_web_ui(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let next = state
                    .get()
                    .next(LauncherEvent::BeginPreflight)
                    .next(LauncherEvent::PreflightPassed);
                state.set(next);
                sync_state_text(&ui, next);
            }
        });
    }

    {
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_view_logs(move || {
            if let Some(ui) = ui_weak.upgrade() {
                sync_state_text(&ui, state.get());
            }
        });
    }

    {
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_exit_app(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let next = state.get().next(LauncherEvent::StopRequested);
                state.set(next);
                sync_state_text(&ui, next);
                let _ = ui.hide();
            }
        });
    }

    ui.run()?;
    Ok(())
}

fn sync_state_text(ui: &MainWindow, state: LauncherState) {
    ui.set_state_text(SharedString::from(state.label()));
}
