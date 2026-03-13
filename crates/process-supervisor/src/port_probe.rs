use std::io;
use std::net::TcpListener;

pub const DEFAULT_OPENCLAW_PORT: u16 = 18_789;

pub fn choose_available_port_from(default_port: u16) -> io::Result<u16> {
    for port in default_port..=u16::MAX {
        if TcpListener::bind(("127.0.0.1", port)).is_ok() {
            return Ok(port);
        }
    }

    Err(io::Error::new(
        io::ErrorKind::AddrNotAvailable,
        "no available localhost port found",
    ))
}

pub fn choose_openclaw_port() -> io::Result<u16> {
    choose_available_port_from(DEFAULT_OPENCLAW_PORT)
}
