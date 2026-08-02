#[derive(Clone, Debug)]
pub struct Config {
    pub bind_addr: String,
    pub bind_port: u16,
    pub run_seconds: Option<u64>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            bind_addr: "127.0.0.1".to_string(),
            bind_port: 28999,
            run_seconds: None,
        }
    }
}

impl Config {
    pub fn from_args<I>(args: I) -> Result<Self, String>
    where
        I: IntoIterator<Item = String>,
    {
        let mut cfg = Self::default();
        let mut it = args.into_iter();
        while let Some(arg) = it.next() {
            match arg.as_str() {
                "--bind" => {
                    let v = it.next().ok_or_else(|| "--bind requires value".to_string())?;
                    let (addr, port) = parse_bind(&v)?;
                    cfg.bind_addr = addr;
                    cfg.bind_port = port;
                }
                "--run-seconds" => {
                    let v = it
                        .next()
                        .ok_or_else(|| "--run-seconds requires value".to_string())?;
                    cfg.run_seconds = Some(
                        v.parse::<u64>()
                            .map_err(|_| "--run-seconds must be u64".to_string())?,
                    );
                }
                "--help" | "-h" => return Err(help_text()),
                _ => return Err(format!("unknown arg: {arg}\n\n{}", help_text())),
            }
        }

        Ok(cfg)
    }
}

fn parse_bind(v: &str) -> Result<(String, u16), String> {
    let (addr, port) = v
        .rsplit_once(':')
        .ok_or_else(|| "--bind must be like 127.0.0.1:28999".to_string())?;
    let port = port
        .parse::<u16>()
        .map_err(|_| "--bind port must be u16".to_string())?;
    Ok((addr.to_string(), port))
}

fn help_text() -> String {
    let exe = std::env::args().next().unwrap_or_else(|| "helper-win".to_string());
    format!(
        "Usage:\n  {exe} [--bind 127.0.0.1:28999] [--run-seconds N]\n\nOptions:\n  --bind <addr:port>\n  --run-seconds <N>\n  -h, --help\n"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn config_from_args_uses_default_values() {
        let cfg = Config::from_args(Vec::<String>::new()).expect("from_args should succeed");
        let def = Config::default();

        assert_eq!(cfg.bind_addr, def.bind_addr);
        assert_eq!(cfg.bind_port, def.bind_port);
        assert_eq!(cfg.run_seconds, def.run_seconds);
    }
}
