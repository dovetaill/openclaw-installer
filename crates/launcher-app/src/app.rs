use std::cell::{Cell, RefCell};
use std::error::Error;
use std::rc::Rc;

use runtime_config::layout::InstallLayout;
use slint::{ComponentHandle, SharedString};

use crate::launcher::LauncherController;
use crate::state::{LauncherEvent, LauncherState};

slint::include_modules!();

pub fn run() -> Result<(), Box<dyn Error>> {
    let ui = MainWindow::new()?;
    let layout = InstallLayout::new("D:\\OpenClaw".into());
    let launcher = Rc::new(RefCell::new(LauncherController::new(layout)?));
    let state = Rc::new(Cell::new(LauncherState::Idle));

    ui.set_install_root(SharedString::from(launcher.borrow().install_root()));
    ui.set_port(SharedString::from("18789"));
    sync_state_text(&ui, state.get());

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_open_web_ui(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let preflight = state.get().next(LauncherEvent::BeginPreflight);
                state.set(preflight);
                sync_state_text(&ui, preflight);

                match launcher.borrow_mut().preflight() {
                    Ok(port) => {
                        ui.set_port(SharedString::from(port.to_string()));
                        let starting = state.get().next(LauncherEvent::PreflightPassed);
                        state.set(starting);
                        sync_state_text(&ui, starting);

                        match launcher.borrow_mut().start() {
                            Ok(port) => {
                                ui.set_port(SharedString::from(port.to_string()));
                                let ready = state.get().next(LauncherEvent::Ready);
                                state.set(ready);
                                sync_state_text(&ui, ready);
                            }
                            Err(_) => {
                                let error = state.get().next(LauncherEvent::StartFailed);
                                state.set(error);
                                sync_state_text(&ui, error);
                            }
                        }
                    }
                    Err(_) => {
                        let error = state.get().next(LauncherEvent::StartFailed);
                        state.set(error);
                        sync_state_text(&ui, error);
                    }
                }
            }
        });
    }

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_view_logs(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let mapped = map_supervisor_status(launcher.borrow().status());
                state.set(mapped);
                sync_state_text(&ui, mapped);
            }
        });
    }

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_exit_app(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let stopping = state.get().next(LauncherEvent::StopRequested);
                state.set(stopping);
                sync_state_text(&ui, stopping);
                let _ = launcher.borrow_mut().stop();
                let idle = state.get().next(LauncherEvent::Stopped);
                state.set(idle);
                sync_state_text(&ui, idle);
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

fn map_supervisor_status(status: process_supervisor::supervisor::SupervisorStatus) -> LauncherState {
    match status {
        process_supervisor::supervisor::SupervisorStatus::Idle => LauncherState::Idle,
        process_supervisor::supervisor::SupervisorStatus::Starting => LauncherState::Starting,
        process_supervisor::supervisor::SupervisorStatus::Ready => LauncherState::Ready,
        process_supervisor::supervisor::SupervisorStatus::Failed => LauncherState::Error,
        process_supervisor::supervisor::SupervisorStatus::Stopped => LauncherState::Idle,
    }
}
