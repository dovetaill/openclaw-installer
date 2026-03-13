use process_supervisor::port_probe::choose_openclaw_port;
use process_supervisor::supervisor::{ProcessSupervisor, SupervisorStatus};
use runtime_config::layout::InstallLayout;

pub struct LauncherController {
    layout: InstallLayout,
    runtime: tokio::runtime::Runtime,
    supervisor: ProcessSupervisor,
    preflight_port: Option<u16>,
}

impl LauncherController {
    pub fn new(layout: InstallLayout) -> Result<Self, String> {
        let runtime = tokio::runtime::Runtime::new().map_err(|error| error.to_string())?;

        Ok(Self {
            layout,
            runtime,
            supervisor: ProcessSupervisor::new(),
            preflight_port: None,
        })
    }

    pub fn install_root(&self) -> String {
        self.layout.root().to_string_lossy().into_owned()
    }

    pub fn preflight(&mut self) -> Result<u16, String> {
        let port = choose_openclaw_port().map_err(|error| error.to_string())?;
        self.preflight_port = Some(port);
        Ok(port)
    }

    pub fn start(&mut self) -> Result<u16, String> {
        let port = self
            .preflight_port
            .take()
            .or(self.supervisor.current_port())
            .unwrap_or_else(|| choose_openclaw_port().unwrap_or(18_789));

        self.runtime
            .block_on(self.supervisor.start_with_port(&self.layout, port))
            .map_err(|error| error.to_string())
    }

    pub fn stop(&mut self) -> Result<(), String> {
        self.runtime
            .block_on(self.supervisor.stop())
            .map_err(|error| error.to_string())
    }

    pub fn status(&self) -> SupervisorStatus {
        self.supervisor.status()
    }
}
