#![allow(dead_code)]

#[path = "../src/launch_flow.rs"]
mod launch_flow;

use std::cell::RefCell;

use launch_flow::{run_preflight, run_start, LaunchSequence};

struct FakeLauncher {
    calls: Vec<&'static str>,
}

impl LaunchSequence for FakeLauncher {
    fn preflight(&mut self) -> Result<u16, String> {
        self.calls.push("preflight");
        Ok(18_789)
    }

    fn start(&mut self) -> Result<u16, String> {
        self.calls.push("start");
        Ok(18_789)
    }
}

#[test]
fn preflight_then_start_reuses_refcell_without_double_borrow_panic() {
    let launcher = RefCell::new(FakeLauncher { calls: Vec::new() });

    let preflight_port = run_preflight(&launcher).unwrap();
    let started_port = run_start(&launcher).unwrap();

    assert_eq!(preflight_port, 18_789);
    assert_eq!(started_port, 18_789);
    assert_eq!(launcher.borrow().calls, vec!["preflight", "start"]);
}
