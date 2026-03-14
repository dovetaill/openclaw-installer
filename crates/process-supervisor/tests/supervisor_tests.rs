use std::net::TcpListener;
use std::time::{Duration, Instant};

use process_supervisor::port_probe::choose_available_port_from;
use process_supervisor::readiness::wait_for_tcp_ready;
use process_supervisor::supervisor::openclaw_gateway_args;

#[test]
fn chooses_next_available_port_when_default_is_occupied() {
    let occupied = TcpListener::bind(("127.0.0.1", 0)).unwrap();
    let occupied_port = occupied.local_addr().unwrap().port();

    let port = choose_available_port_from(occupied_port).unwrap();

    assert!(port > occupied_port);

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

#[test]
fn gateway_launch_args_run_in_foreground_with_allow_unconfigured() {
    let args = openclaw_gateway_args(18_789);

    assert_eq!(
        args,
        vec![
            "gateway".to_string(),
            "run".to_string(),
            "--allow-unconfigured".to_string(),
            "--port".to_string(),
            "18789".to_string(),
        ]
    );
}
