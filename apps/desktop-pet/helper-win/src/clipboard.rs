use crate::events::AppEvent;
use crate::state::SharedState;
use std::sync::mpsc::Sender;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread::JoinHandle;
use std::time::Duration;

pub trait ClipboardWatcher: Send {
    fn start(&mut self, _event_tx: Sender<AppEvent>) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}

pub fn default_clipboard_watcher(state: Arc<SharedState>) -> Box<dyn ClipboardWatcher> {
    #[cfg(windows)]
    {
        Box::new(WindowsClipboardWatcher::new(state))
    }
    #[cfg(not(windows))]
    {
        Box::new(NoopClipboardWatcher::default())
    }
}

pub struct NoopClipboardWatcher {
    stop: Arc<AtomicBool>,
    join: Option<JoinHandle<()>>,
}

impl Default for NoopClipboardWatcher {
    fn default() -> Self {
        Self {
            stop: Arc::new(AtomicBool::new(false)),
            join: None,
        }
    }
}

impl ClipboardWatcher for NoopClipboardWatcher {
    fn start(&mut self, _event_tx: Sender<AppEvent>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if self.join.is_some() {
            return Ok(());
        }

        let stop = Arc::clone(&self.stop);
        self.join = Some(std::thread::spawn(move || {
            while !stop.load(Ordering::Relaxed) {
                std::thread::sleep(Duration::from_millis(200));
            }
        }));

        Ok(())
    }
}

impl Drop for NoopClipboardWatcher {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(join) = self.join.take() {
            let _ = join.join();
        }
    }
}

#[cfg(windows)]
use windows::Win32::Foundation::{HANDLE, HGLOBAL, HWND};
#[cfg(windows)]
use windows::Win32::System::Memory::{GlobalLock, GlobalUnlock};
#[cfg(windows)]
use windows::Win32::UI::WindowsAndMessaging::{
    CloseClipboard, GetClipboardData, GetClipboardSequenceNumber, IsClipboardFormatAvailable,
    OpenClipboard, CF_UNICODETEXT,
};

#[cfg(windows)]
#[derive(Default)]
pub struct WindowsClipboardWatcher {
    stop: Arc<AtomicBool>,
    join: Option<JoinHandle<()>>,
    state: Option<Arc<SharedState>>,
}

#[cfg(windows)]
impl ClipboardWatcher for WindowsClipboardWatcher {
    fn start(&mut self, event_tx: Sender<AppEvent>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if self.join.is_some() {
            return Ok(());
        }

        let stop = Arc::clone(&self.stop);
        let state = self
            .state
            .as_ref()
            .map(Arc::clone)
            .expect("WindowsClipboardWatcher state not set");
        self.join = Some(std::thread::spawn(move || {
            let mut last_seq = unsafe { GetClipboardSequenceNumber() };
            let mut last_text: Option<String> = None;

            while !stop.load(Ordering::Relaxed) {
                std::thread::sleep(Duration::from_millis(120));

                let seq = unsafe { GetClipboardSequenceNumber() };
                if seq == 0 || seq == last_seq {
                    continue;
                }
                last_seq = seq;

                if state.is_paused() {
                    continue;
                }

                if let Some(text) = read_clipboard_text_best_effort() {
                    let normalized = text.replace("\r\n", "\n");
                    if last_text.as_deref() == Some(normalized.as_str()) {
                        continue;
                    }
                    last_text = Some(normalized.clone());
                    let _ = event_tx.send(AppEvent::ClipboardText(normalized));
                }
            }
        }));

        Ok(())
    }
}

#[cfg(windows)]
impl Drop for WindowsClipboardWatcher {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(join) = self.join.take() {
            let _ = join.join();
        }
    }
}

#[cfg(windows)]
pub fn read_clipboard_text_best_effort() -> Option<String> {
    unsafe {
        if !IsClipboardFormatAvailable(CF_UNICODETEXT).as_bool() {
            return None;
        }
        if !OpenClipboard(HWND(0)).as_bool() {
            return None;
        }

        let result = (|| {
            let h: HANDLE = GetClipboardData(CF_UNICODETEXT);
            if h.0 == 0 {
                return None;
            }

            let hg = HGLOBAL(h.0);
            let ptr = GlobalLock(hg);
            if ptr.is_null() {
                return None;
            }

            let mut len: usize = 0;
            let u16_ptr = ptr as *const u16;
            while *u16_ptr.add(len) != 0 {
                len += 1;
                if len > 10_000_000 {
                    break;
                }
            }
            let slice = std::slice::from_raw_parts(u16_ptr, len);
            let s = String::from_utf16_lossy(slice);

            let _ = GlobalUnlock(hg);
            Some(s)
        })();

        let _ = CloseClipboard();
        result
    }
}

#[cfg(windows)]
impl WindowsClipboardWatcher {
    pub fn new(state: Arc<SharedState>) -> Self {
        Self {
            stop: Arc::new(AtomicBool::new(false)),
            join: None,
            state: Some(state),
        }
    }
}
