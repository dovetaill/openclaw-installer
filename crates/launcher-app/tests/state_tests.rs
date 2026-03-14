#[path = "../src/state.rs"]
mod state;

use process_supervisor::supervisor::SupervisorStatus;
use state::{LauncherEvent, LauncherState};

#[test]
fn state_machine_transitions_idle_to_preflight_to_starting() {
    let mut state = LauncherState::Idle;

    state = state.next(LauncherEvent::BeginPreflight);
    assert_eq!(state, LauncherState::Preflight);

    state = state.next(LauncherEvent::PreflightPassed);
    assert_eq!(state, LauncherState::Starting);
}

#[test]
fn open_web_ui_action_starts_gateway_when_idle_or_failed() {
    assert_eq!(
        state::open_web_ui_action(SupervisorStatus::Idle),
        state::OpenWebUiAction::StartGateway
    );
    assert_eq!(
        state::open_web_ui_action(SupervisorStatus::Failed),
        state::OpenWebUiAction::StartGateway
    );
}

#[test]
fn open_web_ui_action_ignores_repeat_clicks_while_starting() {
    assert_eq!(
        state::open_web_ui_action(SupervisorStatus::Starting),
        state::OpenWebUiAction::WaitForExistingStart
    );
}

#[test]
fn open_web_ui_action_reopens_browser_when_gateway_is_ready() {
    assert_eq!(
        state::open_web_ui_action(SupervisorStatus::Ready),
        state::OpenWebUiAction::OpenBrowser
    );
}
