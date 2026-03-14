use std::cell::{Cell, RefCell};
use std::error::Error;
use std::rc::Rc;

use runtime_config::layout::InstallLayout;
use slint::{ComponentHandle, SharedString};

use crate::browser;
use crate::diagnostics;
use crate::install_root;
use crate::launch_flow;
use crate::launcher::LauncherController;
use crate::state::{LauncherEvent, LauncherState};

slint::include_modules!();

impl launch_flow::LaunchSequence for LauncherController {
    fn preflight(&mut self) -> Result<u16, String> {
        LauncherController::preflight(self)
    }

    fn start(&mut self) -> Result<u16, String> {
        LauncherController::start(self)
    }
}

pub fn run() -> Result<(), Box<dyn Error>> {
    let ui = MainWindow::new()?;
    let layout = InstallLayout::new(install_root::resolve_install_root()?);
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
                let current_port = ui.get_port().to_string();

                if matches!(
                    launcher.borrow().status(),
                    process_supervisor::supervisor::SupervisorStatus::Ready
                ) {
                    let install_root = launcher.borrow().install_root();
                    let _ = apply_result_to_state(
                        &ui,
                        &state,
                        browser::open_dashboard(&install_root, &current_port),
                    );
                    return;
                }

                let preflight = state.get().next(LauncherEvent::BeginPreflight);
                state.set(preflight);
                sync_state_text(&ui, preflight);

                match launch_flow::run_preflight(&launcher) {
                    Ok(port) => {
                        ui.set_port(SharedString::from(port.to_string()));
                        let starting = state.get().next(LauncherEvent::PreflightPassed);
                        state.set(starting);
                        sync_state_text(&ui, starting);

                        match launch_flow::run_start(&launcher) {
                            Ok(port) => {
                                ui.set_port(SharedString::from(port.to_string()));
                                let ready = state.get().next(LauncherEvent::Ready);
                                state.set(ready);
                                sync_state_text(&ui, ready);
                                let install_root = launcher.borrow().install_root();
                                let _ = apply_result_to_state(
                                    &ui,
                                    &state,
                                    browser::open_dashboard(&install_root, &port.to_string()),
                                );
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
        ui.on_open_log_dir(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let install_root = launcher.borrow().install_root();
                let _ = apply_result_to_state(&ui, &state, diagnostics::open_log_dir(&install_root));
            }
        });
    }

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_open_config_dir(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let install_root = launcher.borrow().install_root();
                let _ = apply_result_to_state(
                    &ui,
                    &state,
                    diagnostics::open_config_dir(&install_root),
                );
            }
        });
    }

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_validate_config(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let install_root = launcher.borrow().install_root();
                let _ = apply_result_to_state(
                    &ui,
                    &state,
                    diagnostics::validate_config(&install_root),
                );
            }
        });
    }

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_check_skills(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let install_root = launcher.borrow().install_root();
                let _ = apply_result_to_state(
                    &ui,
                    &state,
                    diagnostics::check_skills(&install_root),
                );
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

fn apply_result_to_state(
    ui: &MainWindow,
    state: &Cell<LauncherState>,
    result: Result<(), String>,
) -> Result<(), String> {
    match result {
        Ok(()) => {
            sync_state_text(ui, state.get());
            Ok(())
        }
        Err(error) => {
            state.set(LauncherState::Error);
            sync_state_text(ui, LauncherState::Error);
            Err(error)
        }
    }
}
