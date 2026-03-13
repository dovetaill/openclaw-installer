#![allow(dead_code)]

#[path = "../src/browser.rs"]
mod browser;

#[path = "../src/diagnostics.rs"]
mod diagnostics;

use diagnostics::diagnostics_commands;

#[test]
fn diagnostics_commands_target_local_embedded_runtime() {
    let cmds = diagnostics_commands("D:\\OpenClaw");

    assert!(cmds.iter().any(|c| c.contains("openclaw config validate")));
    assert!(cmds.iter().any(|c| c.contains("openclaw skills check")));
}
