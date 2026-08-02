use crate::events::OutboundEvent;
use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

pub struct SharedState {
    paused: AtomicBool,
    next_id: AtomicU64,
    events: Mutex<VecDeque<OutboundEvent>>,
    max_events: usize,
}

impl SharedState {
    pub fn new(max_events: usize) -> Self {
        Self {
            paused: AtomicBool::new(false),
            next_id: AtomicU64::new(1),
            events: Mutex::new(VecDeque::new()),
            max_events,
        }
    }

    pub fn is_paused(&self) -> bool {
        self.paused.load(Ordering::Relaxed)
    }

    pub fn set_paused(&self, v: bool) {
        self.paused.store(v, Ordering::Relaxed);
    }

    pub fn push_text_event(&self, source: &str, text: String, metadata: serde_json::Value) {
        if self.is_paused() {
            return;
        }

        let ts_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;

        let id = self.next_id.fetch_add(1, Ordering::Relaxed);
        let ev = OutboundEvent {
            id,
            ts_ms,
            source: source.to_string(),
            text,
            metadata,
        };

        let mut q = self.events.lock().unwrap();
        q.push_back(ev);
        while q.len() > self.max_events {
            q.pop_front();
        }
    }

    pub fn drain_events(&self) -> Vec<OutboundEvent> {
        let mut q = self.events.lock().unwrap();
        q.drain(..).collect()
    }
}

