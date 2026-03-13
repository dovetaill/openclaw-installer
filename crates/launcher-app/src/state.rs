#[allow(dead_code)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LauncherState {
    Idle,
    Preflight,
    Starting,
    Ready,
    Error,
    Stopping,
}

#[allow(dead_code)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LauncherEvent {
    BeginPreflight,
    PreflightPassed,
    Ready,
    StartFailed,
    StopRequested,
    Stopped,
    Reset,
}

impl LauncherState {
    pub fn next(self, event: LauncherEvent) -> Self {
        match (self, event) {
            (Self::Idle, LauncherEvent::BeginPreflight) => Self::Preflight,
            (Self::Preflight, LauncherEvent::PreflightPassed) => Self::Starting,
            (Self::Starting, LauncherEvent::Ready) => Self::Ready,
            (Self::Preflight, LauncherEvent::StartFailed)
            | (Self::Starting, LauncherEvent::StartFailed) => Self::Error,
            (Self::Idle, LauncherEvent::StopRequested)
            | (Self::Preflight, LauncherEvent::StopRequested)
            | (Self::Starting, LauncherEvent::StopRequested)
            | (Self::Ready, LauncherEvent::StopRequested)
            | (Self::Error, LauncherEvent::StopRequested) => Self::Stopping,
            (Self::Stopping, LauncherEvent::Stopped) => Self::Idle,
            (_, LauncherEvent::Reset) => Self::Idle,
            _ => self,
        }
    }

    #[allow(dead_code)]
    pub fn label(self) -> &'static str {
        match self {
            Self::Idle => "Idle",
            Self::Preflight => "Preflight",
            Self::Starting => "Starting",
            Self::Ready => "Ready",
            Self::Error => "Error",
            Self::Stopping => "Stopping",
        }
    }
}
