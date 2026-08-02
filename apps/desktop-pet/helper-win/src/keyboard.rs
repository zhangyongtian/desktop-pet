use crate::events::AppEvent;
use crate::state::SharedState;
use std::sync::mpsc::Sender;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread::JoinHandle;
use std::time::Duration;

pub trait KeyboardHook: Send {
    fn start(&mut self, _event_tx: Sender<AppEvent>) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}

pub fn default_keyboard_hook(state: Arc<SharedState>) -> Box<dyn KeyboardHook> {
    #[cfg(windows)]
    {
        Box::new(WindowsKeyboardHook::new(state))
    }
    #[cfg(not(windows))]
    {
        Box::new(NoopKeyboardHook::default())
    }
}

pub struct NoopKeyboardHook {
    stop: Arc<AtomicBool>,
    join: Option<JoinHandle<()>>,
}

impl Default for NoopKeyboardHook {
    fn default() -> Self {
        Self {
            stop: Arc::new(AtomicBool::new(false)),
            join: None,
        }
    }
}

impl KeyboardHook for NoopKeyboardHook {
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

impl Drop for NoopKeyboardHook {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(join) = self.join.take() {
            let _ = join.join();
        }
    }
}

#[cfg(windows)]
use crate::clipboard::read_clipboard_text_best_effort;
#[cfg(windows)]
use std::sync::OnceLock;
#[cfg(windows)]
use std::sync::Mutex;
#[cfg(windows)]
use std::time::Instant;
#[cfg(windows)]
use windows::core::PWSTR;
#[cfg(windows)]
use windows::Win32::Foundation::{HINSTANCE, LPARAM, LRESULT, WPARAM};
#[cfg(windows)]
use windows::Win32::UI::Input::KeyboardAndMouse::{
    CallNextHookEx, GetAsyncKeyState, GetKeyboardLayout, GetKeyboardState, MapVirtualKeyW,
    ToUnicodeEx, KBDLLHOOKSTRUCT, VK_BACK, VK_CONTROL, VK_LCONTROL, VK_LWIN, VK_MENU, VK_RCONTROL,
    VK_RETURN, VK_RWIN, VK_SPACE, VK_TAB, WH_KEYBOARD_LL,
};
#[cfg(windows)]
use windows::Win32::UI::WindowsAndMessaging::{
    DispatchMessageW, GetMessageW, PostThreadMessageW, SetWindowsHookExW, TranslateMessage,
    HHOOK, UnhookWindowsHookEx, HC_ACTION, MSG, WM_KEYDOWN, WM_QUIT, WM_SYSKEYDOWN,
};
#[cfg(windows)]
use windows::Win32::System::Threading::GetCurrentThreadId;

#[cfg(windows)]
struct HookCtx {
    event_tx: Sender<AppEvent>,
    stop: Arc<AtomicBool>,
    buf: Mutex<String>,
    last_activity: Mutex<Instant>,
    state: Arc<SharedState>,
}

#[cfg(windows)]
static HOOK_CTX: OnceLock<Arc<HookCtx>> = OnceLock::new();
#[cfg(windows)]
static HOOK_THREAD_ID: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
#[cfg(windows)]
static HOOK_HANDLE: std::sync::atomic::AtomicPtr<std::ffi::c_void> = std::sync::atomic::AtomicPtr::new(std::ptr::null_mut());

#[cfg(windows)]
fn flush_buffer(ctx: &HookCtx) {
    let mut buf = ctx.buf.lock().unwrap();
    if buf.is_empty() {
        return;
    }
    let s = buf.clone();
    buf.clear();
    drop(buf);
    let _ = ctx.event_tx.send(AppEvent::KeyboardInput(s));
}

#[cfg(windows)]
fn is_ctrl_down() -> bool {
    unsafe {
        (GetAsyncKeyState(VK_CONTROL.0 as i32) & 0x8000) != 0
            || (GetAsyncKeyState(VK_LCONTROL.0 as i32) & 0x8000) != 0
            || (GetAsyncKeyState(VK_RCONTROL.0 as i32) & 0x8000) != 0
    }
}

#[cfg(windows)]
fn is_alt_down() -> bool {
    unsafe { (GetAsyncKeyState(VK_MENU.0 as i32) & 0x8000) != 0 }
}

#[cfg(windows)]
fn is_win_down() -> bool {
    unsafe {
        (GetAsyncKeyState(VK_LWIN.0 as i32) & 0x8000) != 0
            || (GetAsyncKeyState(VK_RWIN.0 as i32) & 0x8000) != 0
    }
}

#[cfg(windows)]
fn should_ignore_for_text() -> bool {
    is_alt_down() || is_win_down()
}

#[cfg(windows)]
fn vk_to_char(vk: u32, scan_code: u32) -> Option<char> {
    unsafe {
        let mut state = [0u8; 256];
        if !GetKeyboardState(state.as_mut_ptr()).as_bool() {
            return None;
        }
        let layout = GetKeyboardLayout(0);
        let mut buff = [0u16; 8];
        let rc = ToUnicodeEx(
            vk,
            scan_code,
            state.as_ptr(),
            PWSTR(buff.as_mut_ptr()),
            buff.len() as i32,
            0,
            layout,
        );
        if rc <= 0 {
            return None;
        }
        let s = String::from_utf16_lossy(&buff[..rc as usize]);
        s.chars().next()
    }
}

#[cfg(windows)]
extern "system" fn low_level_keyboard_proc(code: i32, w_param: WPARAM, l_param: LPARAM) -> LRESULT {
    unsafe {
        if code != HC_ACTION {
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        let ctx = match HOOK_CTX.get() {
            Some(c) => c.clone(),
            None => return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param),
        };
        if ctx.stop.load(Ordering::Relaxed) {
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        if ctx.state.is_paused() {
            ctx.buf.lock().unwrap().clear();
            *ctx.last_activity.lock().unwrap() = Instant::now();
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        let msg = w_param.0 as u32;
        if msg != WM_KEYDOWN.0 && msg != WM_SYSKEYDOWN.0 {
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        let kb: &KBDLLHOOKSTRUCT = &*(l_param.0 as *const KBDLLHOOKSTRUCT);
        let vk = kb.vkCode;
        let scan = if kb.scanCode != 0 {
            kb.scanCode
        } else {
            MapVirtualKeyW(vk, 0)
        };

        if is_ctrl_down() && (vk == 0x56 /* 'V' */) {
            flush_buffer(&ctx);
            if let Some(text) = read_clipboard_text_best_effort() {
                let normalized = text.replace("\r\n", "\n");
                if !normalized.trim().is_empty() {
                    let _ = ctx.event_tx.send(AppEvent::KeyboardInput(normalized));
                }
            }
            *ctx.last_activity.lock().unwrap() = Instant::now();
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        if vk == VK_BACK.0 as u32 {
            let mut buf = ctx.buf.lock().unwrap();
            buf.pop();
            *ctx.last_activity.lock().unwrap() = Instant::now();
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        if vk == VK_RETURN.0 as u32 || vk == VK_TAB.0 as u32 {
            flush_buffer(&ctx);
            *ctx.last_activity.lock().unwrap() = Instant::now();
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        if vk == VK_SPACE.0 as u32 {
            flush_buffer(&ctx);
            *ctx.last_activity.lock().unwrap() = Instant::now();
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        if should_ignore_for_text() {
            *ctx.last_activity.lock().unwrap() = Instant::now();
            return CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param);
        }

        if let Some(ch) = vk_to_char(vk, scan) {
            if !ch.is_control() {
                let mut buf = ctx.buf.lock().unwrap();
                buf.push(ch);
                if buf.len() >= 120 || matches!(ch, '.' | ',' | ';' | ':' | '!' | '?' | ')' | ']' | '}' | '>' | '\"' | '\'') {
                    let s = buf.clone();
                    buf.clear();
                    drop(buf);
                    let _ = ctx.event_tx.send(AppEvent::KeyboardInput(s));
                }
            }
        }

        *ctx.last_activity.lock().unwrap() = Instant::now();
        CallNextHookEx(HHOOK(std::ptr::null_mut()), code, w_param, l_param)
    }
}

#[cfg(windows)]
#[derive(Default)]
pub struct WindowsKeyboardHook {
    stop: Arc<AtomicBool>,
    join: Option<JoinHandle<()>>,
    flusher: Option<JoinHandle<()>>,
    state: Option<Arc<SharedState>>,
}

#[cfg(windows)]
impl KeyboardHook for WindowsKeyboardHook {
    fn start(&mut self, event_tx: Sender<AppEvent>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if self.join.is_some() {
            return Ok(());
        }

        let stop = Arc::clone(&self.stop);
        let state = self
            .state
            .as_ref()
            .map(Arc::clone)
            .expect("WindowsKeyboardHook state not set");
        let ctx = Arc::new(HookCtx {
            event_tx: event_tx.clone(),
            stop: Arc::clone(&stop),
            buf: Mutex::new(String::new()),
            last_activity: Mutex::new(Instant::now()),
            state: Arc::clone(&state),
        });
        let _ = HOOK_CTX.set(Arc::clone(&ctx));

        let flusher_stop = Arc::clone(&stop);
        let flusher_ctx = Arc::clone(&ctx);
        self.flusher = Some(std::thread::spawn(move || {
            while !flusher_stop.load(Ordering::Relaxed) {
                std::thread::sleep(Duration::from_millis(200));

                if flusher_ctx.state.is_paused() {
                    flusher_ctx.buf.lock().unwrap().clear();
                    *flusher_ctx.last_activity.lock().unwrap() = Instant::now();
                    continue;
                }

                let idle = {
                    let last = *flusher_ctx.last_activity.lock().unwrap();
                    last.elapsed() >= Duration::from_millis(1200)
                };
                if idle {
                    flush_buffer(&flusher_ctx);
                }
            }
            flush_buffer(&flusher_ctx);
        }));

        self.join = Some(std::thread::spawn(move || unsafe {
            HOOK_THREAD_ID.store(GetCurrentThreadId(), Ordering::Relaxed);

            let hook = match SetWindowsHookExW(WH_KEYBOARD_LL, Some(low_level_keyboard_proc), HINSTANCE(std::ptr::null_mut()), 0) {
                Ok(h) => h,
                Err(_) => {
                    eprintln!("SetWindowsHookExW(WH_KEYBOARD_LL) failed");
                    return;
                }
            };
            if hook.0.is_null() {
                eprintln!("SetWindowsHookExW(WH_KEYBOARD_LL) returned null");
                return;
            }
            HOOK_HANDLE.store(hook.0, Ordering::Relaxed);

            let mut msg = MSG::default();
            while GetMessageW(&mut msg, None, 0, 0).as_bool() {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }

            let _ = UnhookWindowsHookEx(hook);
            HOOK_HANDLE.store(std::ptr::null_mut(), Ordering::Relaxed);
        }));

        Ok(())
    }
}

#[cfg(windows)]
impl Drop for WindowsKeyboardHook {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);

        let tid = HOOK_THREAD_ID.load(Ordering::Relaxed);
        if tid != 0 {
            unsafe {
                let _ = PostThreadMessageW(tid, WM_QUIT, WPARAM(0), LPARAM(0));
            }
        }

        if let Some(join) = self.join.take() {
            let _ = join.join();
        }
        if let Some(join) = self.flusher.take() {
            let _ = join.join();
        }
    }
}

#[cfg(windows)]
impl WindowsKeyboardHook {
    pub fn new(state: Arc<SharedState>) -> Self {
        Self {
            stop: Arc::new(AtomicBool::new(false)),
            join: None,
            flusher: None,
            state: Some(state),
        }
    }
}
