use std::io;
use std::time::Duration;

use process_supervisor::supervisor::{format_start_failure, startup_timeout};

#[test]
fn startup_timeout_budget_allows_slow_cold_starts() {
    assert!(startup_timeout() >= Duration::from_secs(30));
}

#[test]
fn start_failure_message_includes_recent_stderr_output() {
    let error = io::Error::new(
        io::ErrorKind::TimedOut,
        "timed out waiting for localhost:18789",
    );
    let stderr_lines = vec![
        "booting embedded gateway".to_string(),
        "warming extension registry".to_string(),
        "fatal: failed to load config".to_string(),
    ];

    let detail = format_start_failure(&error, &stderr_lines);

    assert!(detail.contains("timed out waiting for localhost:18789"));
    assert!(detail.contains("fatal: failed to load config"));
}

#[test]
fn start_failure_message_falls_back_to_plain_error_without_stderr() {
    let error = io::Error::new(io::ErrorKind::NotFound, "missing embedded runtime");
    let detail = format_start_failure(&error, &[]);

    assert_eq!(detail, "missing embedded runtime");
}
