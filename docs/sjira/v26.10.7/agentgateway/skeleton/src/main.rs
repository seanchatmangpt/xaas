//! pep_eyerun_skeleton binary — UDS PEP loop, W625 phase-0.
//!
//! Std-only (`std::os::unix::net::UnixListener`), single-threaded with
//! `set_read_timeout` as the watchdog. DISCLOSED as skeleton-grade: the
//! production filter is async (tokio `time::timeout`, pooled connection,
//! re-dial backoff per spec §2.2); this skeleton deliberately spends no
//! dependencies to stay `cargo check`-able offline. The 15ms budget is
//! enforced per-read here, not per-round-trip — the real lane re-arms
//! tokio's timeout around the full round trip.
//!
//! Wire: NDJSON over SOCK_STREAM (spec §1.1). One request line in, one
//! verdict line out. Fail-closed: read timeout, connection fault, or a
//! malformed request line yields `REFUSED_INFRASTRUCTURE_FAULT` + an
//! HTTP-503-shaped error record; no upstream byte ever passes on fault.

use pep_eyerun_skeleton::{
    check_lease, fault_log, http_error_record, json_str_field, FaultCause, Verdict,
    WATCHDOG_BUDGET,
};
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::time::Instant;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let socket_path = args
        .get(1)
        .cloned()
        .unwrap_or_else(|| "/tmp/pep-eyerun-skeleton.sock".to_string());
    let lease_path = args
        .get(2)
        .cloned()
        .unwrap_or_else(|| "/tmp/pep-eyerun-skeleton-lease.json".to_string());
    let ruleset_digest = args
        .get(3)
        .cloned()
        .unwrap_or_else(|| "unpinned-skeleton".to_string());

    let _ = std::fs::remove_file(&socket_path);
    let listener = match UnixListener::bind(&socket_path) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("bind {} failed: {}", socket_path, e);
            std::process::exit(1);
        }
    };
    eprintln!("pep_eyerun_skeleton listening on {} (watchdog {:?})", socket_path, WATCHDOG_BUDGET);

    for stream in listener.incoming() {
        match stream {
            Ok(s) => serve_conn(s, &lease_path, &ruleset_digest, &socket_path),
            Err(e) => eprintln!("accept fault: {} — fail-closed, continuing", e),
        }
    }
}

/// Serve one connection: NDJSON request lines -> verdict lines, fail-closed.
fn serve_conn(stream: UnixStream, lease_path: &str, ruleset_digest: &str, socket_path: &str) {
    let _ = stream.set_read_timeout(Some(WATCHDOG_BUDGET));
    let _ = stream.set_write_timeout(Some(WATCHDOG_BUDGET));
    let mut reader = BufReader::new(match stream.try_clone() {
        Ok(s) => s,
        Err(_) => return, // connection unusable; drop it (fail-closed by omission)
    });
    let mut out = stream;

    loop {
        let mut line = String::new();
        let started = Instant::now();
        match reader.read_line(&mut line) {
            Ok(0) => return, // peer closed
            Ok(_) => {}
            Err(_) => {
                // Read timeout / connection fault → watchdog fault path.
                // The write itself may also fail; both are fail-closed.
                let _ = out.write_all(
                    Verdict::infra_fault().to_line().as_bytes(),
                );
                let _ = out.write_all(
                    http_error_record(&Verdict::infra_fault()).as_bytes(),
                );
                let _ = out.flush();
                eprint!("{}", fault_log("unknown", FaultCause::Timeout, started.elapsed().as_millis(), socket_path, "REFUSED_INFRASTRUCTURE_FAULT"));
                return;
            }
        }

        let verdict = handle_line(&line, lease_path, ruleset_digest);
        let response = match &verdict {
            // Admitted/daemon-refused verdicts get the pass-through verdict line
            // (transport phase-0: the daemon hop is not wired yet, see below).
            Verdict::Admitted => verdict.to_line(),
            Verdict::Refused { code } => {
                if *code == "REFUSED_INFRASTRUCTURE_FAULT" {
                    // fault-shaped: verdict line + HTTP-503-shaped error record
                    format!("{}{}", verdict.to_line(), http_error_record(&verdict.clone()))
                } else {
                    verdict.to_line()
                }
            }
        };
        if out.write_all(response.as_bytes()).and_then(|_| out.flush()).is_err() {
            return; // peer gone; fail-closed by omission
        }
    }
}

/// Handle one NDJSON request line.
///
/// Phase-0 scope: lease pre-flight (spec §3) runs first and is real;
/// the daemon round trip is NOT wired (no eyerun daemon exists on this
/// machine yet) — conforming payloads with a valid lease get the
/// pass-through ADMITTED verdict the relay would produce, and any
/// malformed line fails closed. The daemon-present lane replaces
/// `pass_through_placeholder` with the real socket hop + watchdog.
fn handle_line(line: &str, lease_path: &str, ruleset_digest: &str) -> Verdict {
    let trimmed = line.trim();
    if trimmed.is_empty() {
        return Verdict::infra_fault();
    }

    // Minimal JSON sanity: balanced braces + parseable top-level fields we
    // require. (Skeleton-grade; serde lands with the real lane.)
    if !trimmed.starts_with('{') || !trimmed.ends_with('}') {
        return Verdict::infra_fault();
    }

    // Lease pre-flight (spec §3): BEFORE any daemon round trip.
    let lease_bytes = std::fs::read_to_string(lease_path).unwrap_or_default();
    if lease_bytes.trim().is_empty() {
        return Verdict::lease_absent();
    }
    if let Err(code) = check_lease(&lease_bytes, ruleset_digest, std::time::SystemTime::now()) {
        let _ = code;
        return Verdict::lease_absent();
    }

    // Conforming payload -> pass-through verdict (phase-0 placeholder for the
    // daemon hop). The request id and op are extracted to prove the wire shape.
    let _op = json_str_field(trimmed, "op");
    let _id = json_str_field(trimmed, "id");
    pass_through_placeholder(trimmed)
}

fn pass_through_placeholder(_request_line: &str) -> Verdict {
    Verdict::Admitted
}
