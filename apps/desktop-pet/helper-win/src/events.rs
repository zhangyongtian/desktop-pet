use serde::{Deserialize, Serialize};

#[derive(Debug)]
pub enum AppEvent {
    Tick,
    KeyboardInput(String),
    ClipboardText(String),
    GodotInbound(GodotInbound),
    Shutdown,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OutboundEvent {
    pub id: u64,
    pub ts_ms: u64,
    pub source: String,
    pub text: String,
    #[serde(default)]
    pub metadata: serde_json::Value,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GodotInbound {
    pub kind: String,
    #[serde(default)]
    pub payload: serde_json::Value,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ControlRequest {
    pub action: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ControlResponse {
    pub ok: bool,
    pub paused: bool,
}
