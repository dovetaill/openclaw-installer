use std::cell::RefCell;

pub trait LaunchSequence {
    fn preflight(&mut self) -> Result<u16, String>;
    fn start(&mut self) -> Result<u16, String>;
}

pub fn run_preflight<L>(launcher: &RefCell<L>) -> Result<u16, String>
where
    L: LaunchSequence,
{
    launcher.borrow_mut().preflight()
}

pub fn run_start<L>(launcher: &RefCell<L>) -> Result<u16, String>
where
    L: LaunchSequence,
{
    launcher.borrow_mut().start()
}
