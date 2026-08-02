mod app;
mod clipboard;
mod config;
mod events;
mod http_bridge;
mod keyboard;
mod state;

use crate::app::App;
use crate::config::Config;

fn main() {
    let config = match Config::from_args(std::env::args().skip(1)) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("{e}");
            std::process::exit(2);
        }
    };

    if let Err(e) = App::new(config).run() {
        eprintln!("{e}");
        std::process::exit(1);
    }
}
