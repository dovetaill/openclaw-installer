#[path = "../src/state.rs"]
mod state;

use state::{LauncherEvent, LauncherState};

#[test]
fn state_machine_transitions_idle_to_preflight_to_starting() {
    let mut state = LauncherState::Idle;

    state = state.next(LauncherEvent::BeginPreflight);
    assert_eq!(state, LauncherState::Preflight);

    state = state.next(LauncherEvent::PreflightPassed);
    assert_eq!(state, LauncherState::Starting);
}
