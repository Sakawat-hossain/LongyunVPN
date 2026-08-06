use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::fs::File;
use std::io::{BufRead, Error, Read};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::{io, thread};
use warp::http::StatusCode;
use warp::{Filter, Rejection, Reply};

const LISTEN_PORT: u16 = 47890;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct StartParams {
    pub path: String,
    pub arg: String,
}

fn sha256_file(path: &str) -> Result<String, Error> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0; 4096];

    loop {
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

static LOGS: Lazy<Arc<Mutex<VecDeque<String>>>> =
    Lazy::new(|| Arc::new(Mutex::new(VecDeque::with_capacity(100))));
static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

fn start(start_params: StartParams) -> impl Reply {
    if !cfg!(debug_assertions) {
        let sha256 = sha256_file(start_params.path.as_str()).unwrap_or("".to_string());
        if sha256 != env!("TOKEN") {
            return format!("The SHA256 hash of the program requesting execution is: {}. The helper program only allows execution of applications with the SHA256 hash: {}.", sha256,  env!("TOKEN"),);
        }
        // The only legitimate argument the app passes is the IPC pipe address it
        // just created (\\.\pipe\LongyunCore_<n>). Refuse anything else so the
        // elevated helper can't be coaxed into launching the core with an
        // attacker-chosen argument (e.g. a hostile working dir / config path).
        if !start_params.arg.starts_with(r"\\.\pipe\") {
            return "The core may only be started with its IPC pipe address.".to_string();
        }
    }
    stop();
    let mut process = PROCESS.lock().unwrap_or_else(|e| e.into_inner());
    match Command::new(&start_params.path)
        .stderr(Stdio::piped())
        .arg(&start_params.arg)
        .spawn()
    {
        Ok(child) => {
            *process = Some(child);
            if let Some(ref mut child) = *process {
                let stderr = child.stderr.take().unwrap();
                let reader = io::BufReader::new(stderr);
                thread::spawn(move || {
                    for line in reader.lines() {
                        match line {
                            Ok(output) => {
                                log_message(output);
                            }
                            Err(_) => {
                                break;
                            }
                        }
                    }
                });
            }
            "".to_string()
        }
        Err(e) => {
            log_message(e.to_string());
            e.to_string()
        }
    }
}

fn stop() -> impl Reply {
    let mut process = PROCESS.lock().unwrap_or_else(|e| e.into_inner());
    if let Some(mut child) = process.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
    *process = None;
    "".to_string()
}

fn log_message(message: String) {
    let mut log_buffer = LOGS.lock().unwrap_or_else(|e| e.into_inner());
    if log_buffer.len() == 100 {
        log_buffer.pop_front();
    }
    log_buffer.push_back(format!("{}\n", message));
}

fn get_logs() -> impl Reply {
    let log_buffer = LOGS.lock().unwrap_or_else(|e| e.into_inner());
    let value = log_buffer
        .iter()
        .cloned()
        .collect::<Vec<String>>()
        .join("\n");
    warp::reply::with_header(value, "Content-Type", "text/plain")
}

/// Rejection raised when a request fails the authorization / anti-CSRF gate.
#[derive(Debug)]
struct Unauthorized;
impl warp::reject::Reject for Unauthorized {}

/// True when `host` (which may include a port) is the loopback interface.
fn is_local_host(host: &str) -> bool {
    let name = host.rsplit_once(':').map(|(h, _)| h).unwrap_or(host);
    name == "127.0.0.1" || name == "localhost"
}

/// A filter applied to every endpoint that extracts nothing but rejects any
/// request that isn't a trusted local caller.
///
/// Release builds require `Authorization: <TOKEN>` (the core SHA256 baked into
/// both the app and this helper). A cross-origin browser cannot set a custom
/// `Authorization` header on a request without triggering a CORS preflight this
/// server never approves — so this closes the "a website you're visiting silently
/// POSTs /stop and drops your VPN" vector that the old unauthenticated /stop
/// allowed, and stops the /ping endpoint from handing the token to any caller.
/// As defense in depth it also rejects requests carrying a browser `Origin`
/// header or a non-loopback `Host` (DNS-rebinding). Debug builds skip the gate so
/// `flutter run` against a dev helper keeps working.
fn auth_guard() -> impl Filter<Extract = (), Error = Rejection> + Clone {
    warp::header::optional::<String>("authorization")
        .and(warp::header::optional::<String>("origin"))
        .and(warp::header::optional::<String>("host"))
        .and_then(
            |auth: Option<String>, origin: Option<String>, host: Option<String>| async move {
                if cfg!(debug_assertions) {
                    return Ok(());
                }
                // No legitimate local caller is a browser.
                if origin.is_some() {
                    return Err(warp::reject::custom(Unauthorized));
                }
                match host.as_deref() {
                    Some(h) if is_local_host(h) => {}
                    _ => return Err(warp::reject::custom(Unauthorized)),
                }
                match auth {
                    Some(token) if token == env!("TOKEN") => Ok(()),
                    _ => Err(warp::reject::custom(Unauthorized)),
                }
            },
        )
        .untuple_one()
}

async fn handle_rejection(err: Rejection) -> Result<impl Reply, std::convert::Infallible> {
    if err.find::<Unauthorized>().is_some() {
        Ok(warp::reply::with_status(
            "unauthorized".to_string(),
            StatusCode::UNAUTHORIZED,
        ))
    } else if err.is_not_found() {
        Ok(warp::reply::with_status(
            "not found".to_string(),
            StatusCode::NOT_FOUND,
        ))
    } else {
        Ok(warp::reply::with_status(
            "bad request".to_string(),
            StatusCode::BAD_REQUEST,
        ))
    }
}

pub async fn run_service() -> anyhow::Result<()> {
    // `/ping` now only confirms the helper accepted our token (returns "ok")
    // instead of echoing the token back to whoever asked.
    let api_ping = warp::get()
        .and(warp::path("ping"))
        .and(auth_guard())
        .map(|| "ok");

    let api_start = warp::post()
        .and(warp::path("start"))
        .and(auth_guard())
        .and(warp::body::json())
        .map(|start_params: StartParams| start(start_params));

    let api_stop = warp::post()
        .and(warp::path("stop"))
        .and(auth_guard())
        .map(|| stop());

    let api_logs = warp::get()
        .and(warp::path("logs"))
        .and(auth_guard())
        .map(|| get_logs());

    let routes = api_ping
        .or(api_start)
        .or(api_stop)
        .or(api_logs)
        .recover(handle_rejection);

    warp::serve(routes).run(([127, 0, 0, 1], LISTEN_PORT)).await;

    Ok(())
}
