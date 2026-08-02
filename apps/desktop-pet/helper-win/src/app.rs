use crate::clipboard::{ClipboardWatcher, default_clipboard_watcher};
use crate::config::Config;
use crate::events::AppEvent;
use crate::http_bridge::HttpBridge;
use crate::keyboard::{KeyboardHook, default_keyboard_hook};
use crate::state::SharedState;
use std::sync::mpsc::{Receiver, Sender};
use std::sync::Arc;
use std::time::{Duration, Instant};

pub struct App {
    config: Config,
    event_tx: Sender<AppEvent>,
    event_rx: Receiver<AppEvent>,
    keyboard: Box<dyn KeyboardHook>,
    clipboard: Box<dyn ClipboardWatcher>,
    state: Arc<SharedState>,
}

impl App {
    pub fn new(config: Config) -> Self {
        let (event_tx, event_rx) = std::sync::mpsc::channel();
        let state = Arc::new(SharedState::new(2000));
        Self {
            config,
            event_tx,
            event_rx,
            keyboard: default_keyboard_hook(Arc::clone(&state)),
            clipboard: default_clipboard_watcher(Arc::clone(&state)),
            state,
        }
    }

    pub fn run(mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _http = HttpBridge::start(
            self.config.bind_addr.clone(),
            self.config.bind_port,
            self.event_tx.clone(),
            Arc::clone(&self.state),
        )?;
        self.keyboard.start(self.event_tx.clone())?;
        self.clipboard.start(self.event_tx.clone())?;

        let start = Instant::now();
        let mut last_tick = Instant::now();

        loop {
            if let Some(secs) = self.config.run_seconds {
                if start.elapsed() >= Duration::from_secs(secs) {
                    break;
                }
            }

            match self.event_rx.recv_timeout(Duration::from_millis(200)) {
                Ok(ev) => {
                    let should_stop = self.handle_event(ev);
                    if should_stop {
                        break;
                    }
                }
                Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {}
                Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
            }

            if last_tick.elapsed() >= Duration::from_secs(1) {
                last_tick = Instant::now();
                let _ = self.handle_event(AppEvent::Tick);
            }
        }

        Ok(())
    }

    fn handle_event(&mut self, ev: AppEvent) -> bool {
        match ev {
            AppEvent::Tick => {}
            AppEvent::KeyboardInput(s) => {
                if !s.trim().is_empty() {
                    self.state
                        .push_text_event("typing", s, serde_json::Value::Null);
                }
            }
            AppEvent::ClipboardText(s) => {
                if !s.trim().is_empty() {
                    self.state
                        .push_text_event("clipboard", s, serde_json::Value::Null);
                }
            }
            AppEvent::GodotInbound(msg) => {
                println!(
                    "godot inbound: kind={}, payload={}",
                    msg.kind, msg.payload
                );
            }
            AppEvent::Shutdown => return true,
        }
        false
    }
}
