use std::cell::Cell;
use std::error::Error;
use std::rc::Rc;

use async_compat::Compat;
use process_supervisor::supervisor::startup_timeout;
use runtime_config::layout::InstallLayout;
use runtime_config::manifest::PayloadManifest;
use slint::{ComponentHandle, SharedString};

use crate::browser;
use crate::diagnostics;
use crate::install_root;
use crate::launcher::LauncherController;
use crate::metadata;
use crate::state::{open_web_ui_action, LauncherEvent, LauncherState, OpenWebUiAction};

slint::include_modules!();

pub fn run() -> Result<(), Box<dyn Error>> {
    let ui = MainWindow::new()?;
    let layout = InstallLayout::new(install_root::resolve_install_root()?);
    let manifest = PayloadManifest::from_install_root(layout.root()).ok();
    let launcher = Rc::new(LauncherController::new(layout)?);
    let state = Rc::new(Cell::new(LauncherState::Idle));
    let start_in_flight = Rc::new(Cell::new(false));

    ui.set_install_root(SharedString::from(launcher.install_root()));
    ui.set_port(SharedString::from("18789"));
    ui.set_window_title_text(SharedString::from(metadata::window_title(
        manifest.as_ref(),
    )));
    ui.set_heading_text(SharedString::from(metadata::heading_text(
        manifest.as_ref(),
    )));
    ui.set_runtime_label(SharedString::from(metadata::runtime_label(
        manifest.as_ref(),
    )));
    ui.set_installer_repo_url(SharedString::from(metadata::installer_repository_url()));
    ui.set_detail_text(SharedString::from(""));
    sync_state_text(&ui, state.get());

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let start_in_flight = start_in_flight.clone();
        let ui_weak = ui.as_weak();
        ui.on_open_web_ui(move || {
            if let Some(ui) = ui_weak.upgrade() {
                if state.get() == LauncherState::Starting || start_in_flight.get() {
                    state.set(LauncherState::Starting);
                    sync_state_text(&ui, LauncherState::Starting);
                    set_waiting_detail(&ui);
                    return;
                }

                match open_web_ui_action(launcher.status()) {
                    OpenWebUiAction::OpenBrowser => {
                        let install_root = launcher.install_root();
                        let port = launcher
                            .current_port()
                            .unwrap_or_else(|| displayed_port(&ui));
                        let _ = open_dashboard_and_show_detail(
                            &ui,
                            state.as_ref(),
                            &install_root,
                            port,
                        );
                    }
                    OpenWebUiAction::WaitForExistingStart => {
                        state.set(LauncherState::Starting);
                        sync_state_text(&ui, LauncherState::Starting);
                        set_waiting_detail(&ui);
                    }
                    OpenWebUiAction::StartGateway => {
                        let preflight = state.get().next(LauncherEvent::BeginPreflight);
                        state.set(preflight);
                        sync_state_text(&ui, preflight);
                        ui.set_detail_text(SharedString::from("Checking gateway port..."));

                        match launcher.preflight() {
                            Ok(port) => {
                                ui.set_port(SharedString::from(port.to_string()));
                                let starting = state.get().next(LauncherEvent::PreflightPassed);
                                state.set(starting);
                                sync_state_text(&ui, starting);
                                set_starting_detail(&ui, port);
                                start_in_flight.set(true);

                                let async_launcher = launcher.clone();
                                let async_state = state.clone();
                                let async_start_in_flight = start_in_flight.clone();
                                let async_ui_weak = ui_weak.clone();

                                if let Err(error) = slint::spawn_local(Compat::new(async move {
                                    let result = async_launcher.start().await;
                                    async_start_in_flight.set(false);

                                    if let Some(ui) = async_ui_weak.upgrade() {
                                        match result {
                                            Ok(port) => {
                                                ui.set_port(SharedString::from(port.to_string()));
                                                let ready =
                                                    async_state.get().next(LauncherEvent::Ready);
                                                async_state.set(ready);
                                                sync_state_text(&ui, ready);

                                                let install_root = async_launcher.install_root();
                                                let _ = open_dashboard_and_show_detail(
                                                    &ui,
                                                    async_state.as_ref(),
                                                    &install_root,
                                                    port,
                                                );
                                            }
                                            Err(error) => {
                                                let failed = async_state
                                                    .get()
                                                    .next(LauncherEvent::StartFailed);
                                                async_state.set(failed);
                                                sync_state_text(&ui, failed);
                                                ui.set_detail_text(SharedString::from(error));
                                            }
                                        }
                                    }
                                })) {
                                    start_in_flight.set(false);
                                    let failed = state.get().next(LauncherEvent::StartFailed);
                                    state.set(failed);
                                    sync_state_text(&ui, failed);
                                    ui.set_detail_text(SharedString::from(format!(
                                        "failed to schedule launcher startup: {error}"
                                    )));
                                }
                            }
                            Err(error) => {
                                let failed = state.get().next(LauncherEvent::StartFailed);
                                state.set(failed);
                                sync_state_text(&ui, failed);
                                ui.set_detail_text(SharedString::from(error));
                            }
                        }
                    }
                }
            }
        });
    }

    {
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_open_installer_repo(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let _ =
                    apply_action_result(&ui, state.as_ref(), browser::open_installer_repository());
            }
        });
    }

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_open_log_dir(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let install_root = launcher.install_root();
                let _ = apply_action_result(
                    &ui,
                    state.as_ref(),
                    diagnostics::open_log_dir(&install_root),
                );
            }
        });
    }

    {
        let launcher = launcher.clone();
        let state = state.clone();
        let ui_weak = ui.as_weak();
        ui.on_open_config_dir(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let install_root = launcher.install_root();
                let _ = apply_action_result(
                    &ui,
                    state.as_ref(),
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
                let install_root = launcher.install_root();
                let _ = apply_action_result(
                    &ui,
                    state.as_ref(),
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
                let install_root = launcher.install_root();
                let _ = apply_action_result(
                    &ui,
                    state.as_ref(),
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
                ui.set_detail_text(SharedString::from("Stopping embedded gateway..."));

                let async_launcher = launcher.clone();
                let async_state = state.clone();
                let async_ui_weak = ui_weak.clone();

                if let Err(error) = slint::spawn_local(Compat::new(async move {
                    let stop_result = async_launcher.stop().await;

                    if let Some(ui) = async_ui_weak.upgrade() {
                        match stop_result {
                            Ok(()) => {
                                let idle = async_state.get().next(LauncherEvent::Stopped);
                                async_state.set(idle);
                                sync_state_text(&ui, idle);
                                ui.set_detail_text(SharedString::from(""));
                            }
                            Err(error) => {
                                async_state.set(LauncherState::Error);
                                sync_state_text(&ui, LauncherState::Error);
                                ui.set_detail_text(SharedString::from(error));
                            }
                        }

                        let _ = ui.hide();
                    }
                })) {
                    state.set(LauncherState::Error);
                    sync_state_text(&ui, LauncherState::Error);
                    ui.set_detail_text(SharedString::from(format!(
                        "failed to schedule launcher shutdown: {error}"
                    )));
                    let _ = ui.hide();
                }
            }
        });
    }

    ui.run()?;
    Ok(())
}

fn sync_state_text(ui: &MainWindow, state: LauncherState) {
    ui.set_state_text(SharedString::from(state.label()));
    ui.set_open_web_ui_enabled(!matches!(
        state,
        LauncherState::Preflight | LauncherState::Starting | LauncherState::Stopping
    ));
}

fn displayed_port(ui: &MainWindow) -> u16 {
    ui.get_port().to_string().parse().unwrap_or(18_789)
}

fn set_starting_detail(ui: &MainWindow, port: u16) {
    ui.set_detail_text(SharedString::from(format!(
        "Starting embedded gateway on port {port}. Cold start can take up to {} seconds.",
        startup_timeout().as_secs()
    )));
}

fn set_waiting_detail(ui: &MainWindow) {
    ui.set_detail_text(SharedString::from(format!(
        "Gateway is still starting on port {}. Wait up to {} seconds for the browser to open automatically.",
        displayed_port(ui),
        startup_timeout().as_secs()
    )));
}

fn open_dashboard_and_show_detail(
    ui: &MainWindow,
    state: &Cell<LauncherState>,
    install_root: &str,
    port: u16,
) -> Result<(), String> {
    let port_text = port.to_string();

    match browser::open_dashboard(install_root, &port_text) {
        Ok(()) => {
            sync_state_text(ui, state.get());
            ui.set_detail_text(SharedString::from(format!(
                "Gateway ready on port {port}. Browser reopen requested."
            )));
            Ok(())
        }
        Err(error) => {
            sync_state_text(ui, state.get());
            ui.set_detail_text(SharedString::from(error.clone()));
            Err(error)
        }
    }
}

fn apply_action_result(
    ui: &MainWindow,
    state: &Cell<LauncherState>,
    result: Result<(), String>,
) -> Result<(), String> {
    match result {
        Ok(()) => {
            sync_state_text(ui, state.get());
            ui.set_detail_text(SharedString::from(""));
            Ok(())
        }
        Err(error) => {
            sync_state_text(ui, state.get());
            ui.set_detail_text(SharedString::from(error.clone()));
            Err(error)
        }
    }
}
