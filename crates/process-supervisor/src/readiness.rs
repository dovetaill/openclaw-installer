use std::io;
use std::time::Duration;

pub async fn wait_for_tcp_ready(
    port: u16,
    max_attempts: usize,
    interval: Duration,
) -> io::Result<()> {
    for _ in 0..max_attempts {
        if tokio::net::TcpStream::connect(("127.0.0.1", port)).await.is_ok() {
            return Ok(());
        }

        tokio::time::sleep(interval).await;
    }

    Err(io::Error::new(
        io::ErrorKind::TimedOut,
        format!("timed out waiting for localhost:{port}"),
    ))
}
