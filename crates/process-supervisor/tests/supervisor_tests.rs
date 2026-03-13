use std::net::TcpListener;
use std::time::{Duration, Instant};

use process_supervisor::port_probe::{choose_available_port_from, DEFAULT_OPENCLAW_PORT};
use process_supervisor::readiness::wait_for_tcp_ready;

#[test]
fn chooses_next_available_port_when_default_is_occupied() {
    let occupied = TcpListener::bind(("127.0.0.1", DEFAULT_OPENCLAW_PORT)).unwrap();

    let port = choose_available_port_from(DEFAULT_OPENCLAW_PORT).unwrap();

    assert!(port > DEFAULT_OPENCLAW_PORT);

    drop(occupied);
}

#[tokio::test]
async fn does_not_report_ready_before_probe_succeeds() {
    let probe = TcpListener::bind(("127.0.0.1", 0)).unwrap();
    let port = probe.local_addr().unwrap().port();
    drop(probe);

    let started_at = Instant::now();
    let listener = tokio::spawn(async move {
        tokio::time::sleep(Duration::from_millis(150)).await;
        let listener = tokio::net::TcpListener::bind(("127.0.0.1", port))
            .await
            .unwrap();
        tokio::time::sleep(Duration::from_millis(200)).await;
        drop(listener);
    });

    wait_for_tcp_ready(port, 12, Duration::from_millis(25))
        .await
        .unwrap();

    assert!(started_at.elapsed() >= Duration::from_millis(125));
    listener.await.unwrap();
}
