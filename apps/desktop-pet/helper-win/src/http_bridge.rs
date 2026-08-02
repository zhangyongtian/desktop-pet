use crate::events::{AppEvent, ControlRequest, ControlResponse, GodotInbound};
use crate::state::SharedState;
use std::sync::mpsc::Sender;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread::JoinHandle;
use std::time::Duration;

pub struct HttpBridge {
    stop: Arc<AtomicBool>,
    join: Option<JoinHandle<()>>,
}

impl HttpBridge {
    pub fn start(
        bind_addr: String,
        bind_port: u16,
        event_tx: Sender<AppEvent>,
        state: Arc<SharedState>,
    ) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let stop = Arc::new(AtomicBool::new(false));
        let stop_for_thread = Arc::clone(&stop);
        let state_for_thread = Arc::clone(&state);
        let join = std::thread::spawn(move || {
            let addr = format!("{bind_addr}:{bind_port}");
            let server = match tiny_http::Server::http(&addr) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("http server bind failed: {e}");
                    return;
                }
            };

            while !stop_for_thread.load(Ordering::Relaxed) {
                let mut req = match server.recv_timeout(Duration::from_millis(200)) {
                    Ok(Some(r)) => r,
                    Ok(None) => continue,
                    Err(e) => {
                        eprintln!("http server recv failed: {e}");
                        break;
                    }
                };

                let method = req.method().as_str().to_string();
                let url = req.url().to_string();

                match (method.as_str(), url.as_str()) {
                    ("GET", "/health") => {
                        let _ = req.respond(tiny_http::Response::from_string("ok"));
                    }
                    ("GET", "/events") => {
                        let events = state_for_thread.drain_events();
                        let body = match serde_json::to_string(&events) {
                            Ok(s) => s,
                            Err(e) => {
                                let resp = tiny_http::Response::from_string(format!("json error: {e}"))
                                    .with_status_code(500);
                                let _ = req.respond(resp);
                                continue;
                            }
                        };

                        let resp = tiny_http::Response::from_string(body).with_header(
                            tiny_http::Header::from_bytes("Content-Type", "application/json")
                                .unwrap(),
                        );
                        let _ = req.respond(resp);
                    }
                    ("POST", "/control") => {
                        let mut body = String::new();
                        let _ = req.as_reader().read_to_string(&mut body);

                        let req_obj = serde_json::from_str::<ControlRequest>(&body);
                        match req_obj {
                            Ok(cmd) => {
                                match cmd.action.as_str() {
                                    "pause" => state_for_thread.set_paused(true),
                                    "resume" => state_for_thread.set_paused(false),
                                    "shutdown" => {
                                        let _ = event_tx.send(AppEvent::Shutdown);
                                    }
                                    _ => {
                                        let resp = tiny_http::Response::from_string("bad request")
                                            .with_status_code(400);
                                        let _ = req.respond(resp);
                                        continue;
                                    }
                                }

                                let resp_body = serde_json::to_string(&ControlResponse {
                                    ok: true,
                                    paused: state_for_thread.is_paused(),
                                })
                                .unwrap_or_else(|_| "{\"ok\":true}".to_string());
                                let resp = tiny_http::Response::from_string(resp_body).with_header(
                                    tiny_http::Header::from_bytes("Content-Type", "application/json")
                                        .unwrap(),
                                );
                                let _ = req.respond(resp);
                            }
                            Err(_) => {
                                let resp =
                                    tiny_http::Response::from_string("bad request").with_status_code(400);
                                let _ = req.respond(resp);
                            }
                        }
                    }
                    ("POST", "/event") => {
                        let mut body = String::new();
                        let _ = req.as_reader().read_to_string(&mut body);

                        match serde_json::from_str::<GodotInbound>(&body) {
                            Ok(msg) => {
                                let _ = event_tx.send(AppEvent::GodotInbound(msg));
                                let _ = req.respond(tiny_http::Response::from_string("ok"));
                            }
                            Err(_) => {
                                let resp = tiny_http::Response::from_string("bad request")
                                    .with_status_code(400);
                                let _ = req.respond(resp);
                            }
                        }
                    }
                    _ => {
                        let resp = tiny_http::Response::from_string("not found").with_status_code(404);
                        let _ = req.respond(resp);
                    }
                }
            }
        });

        Ok(Self {
            stop,
            join: Some(join),
        })
    }
}

impl Drop for HttpBridge {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(join) = self.join.take() {
            let _ = join.join();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::SharedState;
    use std::io::{Read, Write};
    use std::net::{TcpListener, TcpStream};
    use std::sync::mpsc::channel;
    use std::time::Duration;

    fn get_free_port() -> u16 {
        TcpListener::bind("127.0.0.1:0")
            .expect("bind to ephemeral port")
            .local_addr()
            .expect("local_addr")
            .port()
    }

    fn wait_port_ready(port: u16) {
        let addr = format!("127.0.0.1:{port}");
        for _ in 0..50 {
            if TcpStream::connect(&addr).is_ok() {
                return;
            }
            std::thread::sleep(Duration::from_millis(20));
        }
        panic!("http server not ready: {addr}");
    }

    fn http_request(port: u16, method: &str, path: &str, body: Option<&str>) -> (u16, String) {
        let mut stream = TcpStream::connect(format!("127.0.0.1:{port}")).expect("connect");
        stream
            .set_read_timeout(Some(Duration::from_secs(2)))
            .expect("set read timeout");

        let body = body.unwrap_or("");
        let mut req = String::new();
        req.push_str(&format!("{method} {path} HTTP/1.1\r\n"));
        req.push_str(&format!("Host: 127.0.0.1:{port}\r\n"));
        req.push_str("Connection: close\r\n");
        if !body.is_empty() {
            req.push_str("Content-Type: application/json\r\n");
            req.push_str(&format!("Content-Length: {}\r\n", body.as_bytes().len()));
        } else {
            req.push_str("Content-Length: 0\r\n");
        }
        req.push_str("\r\n");
        req.push_str(body);

        stream.write_all(req.as_bytes()).expect("write request");

        let mut resp = String::new();
        stream.read_to_string(&mut resp).expect("read response");

        let (head, body) = if let Some((h, b)) = resp.split_once("\r\n\r\n") {
            (h, b)
        } else if let Some((h, b)) = resp.split_once("\n\n") {
            (h, b)
        } else {
            (resp.as_str(), "")
        };

        let status_line = head.lines().next().unwrap_or("");
        let code = status_line
            .split_whitespace()
            .nth(1)
            .and_then(|s| s.parse::<u16>().ok())
            .unwrap_or(0);

        (code, body.to_string())
    }

    #[test]
    fn http_endpoints_smoke() {
        let port = get_free_port();
        let (tx, _rx) = channel::<AppEvent>();
        let state = Arc::new(SharedState::new(32));

        let _bridge = HttpBridge::start("127.0.0.1".to_string(), port, tx, Arc::clone(&state))
            .expect("start http bridge");

        wait_port_ready(port);

        // /health => ok
        let (code, body) = http_request(port, "GET", "/health", None);
        assert_eq!(code, 200);
        assert_eq!(body.trim(), "ok");

        // /events => json array
        let (code, body) = http_request(port, "GET", "/events", None);
        assert_eq!(code, 200);
        let v: serde_json::Value = serde_json::from_str(&body).expect("events json");
        assert!(v.is_array(), "/events should return json array, got: {v:?}");

        // /control => 200
        let (code, body) =
            http_request(port, "POST", "/control", Some(r#"{"action":"pause"}"#));
        assert_eq!(code, 200);
        let v: serde_json::Value = serde_json::from_str(&body).expect("control json");
        assert_eq!(v.get("ok").and_then(|x| x.as_bool()), Some(true));
        assert_eq!(v.get("paused").and_then(|x| x.as_bool()), Some(true));
    }
}
