//! pep_eyerun_skeleton — W625 phase-0 skeleton of the W613 pep-eyerun filter spec.
//!
//! Scope (disclosed): this is skeleton-grade code, not the production filter.
//! It materializes the wire shape and the fail-closed control flow so the
//! daemon-present lane starts from compiling code, not prose:
//!
//! * Verdict vocabulary is exactly eyerun_wasi's (grounded in
//!   `/Users/sac/wasm4pm/crates/eu_gate/src/lib.rs` lines 39–43):
//!   `ADMITTED` | `REFUSED` + code in {`REFUSED_REQUIRED_FIELD_MISSING`,
//!   `REFUSED_ENUM_VIOLATION`, `REFUSED_RANGE_VIOLATION`,
//!   `REFUSED_FORBIDDEN_FIELD`, `REFUSED_INFRASTRUCTURE_FAULT`}.
//! * Filter-local lease code `REFUSED_LEASE_ABSENT` (spec §3) — never emitted
//!   by the daemon, checked pre-flight before any socket round trip.
//! * Fail-closed mapping: timeout / crash / malformed →
//!   `REFUSED_INFRASTRUCTURE_FAULT` verdict line + HTTP-503-shaped error
//!   record. Mapping is one-way (spec §2.1).
//! * Lease check requires `lease_id`, `ruleset_digest`, `not_after` — any
//!   absent field is `REFUSED_LEASE_ABSENT`.
//!
//! JSON handling is a minimal flat-object field extractor (std-only, no
//! serde) — sufficient for the skeleton's three lease fields and
//! pass-through relay; NOT a general JSON parser. The real lane replaces
//! this with serde + the daemon's `evaluate_checked` core.

use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Watchdog hard deadline, spec §2.1: 15 ms total round trip.
pub const WATCHDOG_BUDGET: Duration = Duration::from_millis(15);

/// Typed refusal codes (eyerun_wasi vocabulary + the filter-local lease code).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RefusalCode {
    RequiredFieldMissing,
    EnumViolation,
    RangeViolation,
    ForbiddenField,
    InfrastructureFault,
    /// Filter-local (spec §3): lease absent / expired / digest mismatch.
    /// Never emitted by the daemon.
    LeaseAbsent,
}

impl RefusalCode {
    pub fn as_str(self) -> &'static str {
        match self {
            RefusalCode::RequiredFieldMissing => "REFUSED_REQUIRED_FIELD_MISSING",
            RefusalCode::EnumViolation => "REFUSED_ENUM_VIOLATION",
            RefusalCode::RangeViolation => "REFUSED_RANGE_VIOLATION",
            RefusalCode::ForbiddenField => "REFUSED_FORBIDDEN_FIELD",
            RefusalCode::InfrastructureFault => "REFUSED_INFRASTRUCTURE_FAULT",
            RefusalCode::LeaseAbsent => "REFUSED_LEASE_ABSENT",
        }
    }
}

/// Verdict, mirroring eyerun_wasi's serde tag shape:
/// `{"verdict":"ADMITTED"}` | `{"verdict":"REFUSED","code":"..."}`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Verdict {
    Admitted,
    Refused { code: &'static str },
}

impl Verdict {
    pub fn infra_fault() -> Self {
        Verdict::Refused {
            code: RefusalCode::InfrastructureFault.as_str(),
        }
    }

    pub fn lease_absent() -> Self {
        Verdict::Refused {
            code: RefusalCode::LeaseAbsent.as_str(),
        }
    }

    /// Wire line (NDJSON, one document + `\n`).
    pub fn to_line(&self) -> String {
        match self {
            Verdict::Admitted => "{\"verdict\":\"ADMITTED\"}\n".to_string(),
            Verdict::Refused { code } => format!(
                "{{\"verdict\":\"REFUSED\",\"code\":\"{}\"}}\n",
                code
            ),
        }
    }
}

/// HTTP-503-shaped error record, spec §2.1 protocol mapping row 1.
pub fn http_error_record(verdict: &Verdict) -> String {
    let code = match verdict {
        Verdict::Admitted => "INTERNAL", // unreachable on admitted; one-way mapping guard
        Verdict::Refused { code } => code,
    };
    format!(
        "HTTP/1.1 503 Service Unavailable\r\nContent-Type: application/json\r\n\
         Content-Length: 0\r\nX-Pep-Refusal: {}\r\nConnection: close\r\n\r\n",
        code
    )
}

/// Minimal flat-JSON string-field extractor. Skeleton-grade: reads
/// `"key":"value"` / `"key":<bare token>` at the top level. Sufficient for
/// the lease triple and `op` discrimination; not a general parser.
pub fn json_str_field<'a>(line: &'a str, key: &str) -> Option<&'a str> {
    // First-match on the quoted key. Skeleton-grade: keys appearing inside
    // string values could alias; the real lane uses serde.
    let needle = format!("\"{}\"", key);
    let idx = line.find(&needle)?;
    let after = line[idx + needle.len()..].trim_start();
    let after = after.strip_prefix(':')?.trim_start();
    if let Some(rest) = after.strip_prefix('"') {
        let end = rest.find('"')?;
        return Some(&rest[..end]);
    }
    // bare token (number / true / null): consume until , } or whitespace
    let end = after
        .find(|c: char| c == ',' || c == '}' || c.is_whitespace())
        .unwrap_or(after.len());
    let token = &after[..end];
    if token == "null" {
        return None; // null counts as absent, mirroring eu_gate Required semantics
    }
    Some(token)
}

/// Lease state required by spec §3: `{lease_id, ruleset_digest, not_after}`.
#[derive(Debug, Clone, PartialEq)]
pub struct Lease {
    pub lease_id: String,
    pub ruleset_digest: String,
    /// Unix epoch seconds.
    pub not_after: u64,
}

/// Pre-flight lease check (spec §3). Runs BEFORE any daemon round trip.
/// Absent field, unparseable lease, expired `not_after`, or (given the
/// loaded ruleset's digest) a digest mismatch all yield
/// `REFUSED_LEASE_ABSENT` — fail-closed, non-configurable; no
/// `allow_lease_absent` knob exists.
pub fn check_lease(lease_bytes: &str, loaded_ruleset_digest: &str, now: SystemTime) -> Result<Lease, RefusalCode> {
    let lease_id = json_str_field(lease_bytes, "lease_id");
    let digest = json_str_field(lease_bytes, "ruleset_digest");
    let not_after = json_str_field(lease_bytes, "not_after");

    let lease_id = lease_id.ok_or(RefusalCode::LeaseAbsent)?;
    let digest = digest.ok_or(RefusalCode::LeaseAbsent)?;
    let not_after: u64 = not_after
        .ok_or(RefusalCode::LeaseAbsent)?
        .parse()
        .map_err(|_| RefusalCode::LeaseAbsent)?;

    let now_secs = now
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .map_err(|_| RefusalCode::LeaseAbsent)?;
    if now_secs >= not_after {
        return Err(RefusalCode::LeaseAbsent);
    }
    if digest != loaded_ruleset_digest {
        return Err(RefusalCode::LeaseAbsent);
    }
    Ok(Lease {
        lease_id: lease_id.to_string(),
        ruleset_digest: digest.to_string(),
        not_after,
    })
}

/// Classify a watchdog fault for the structured log `cause` field (spec §2.1).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FaultCause {
    Timeout,
    Crash,
    MalformedResponse,
}

impl FaultCause {
    pub fn as_str(self) -> &'static str {
        match self {
            FaultCause::Timeout => "timeout",
            FaultCause::Crash => "crash",
            FaultCause::MalformedResponse => "malformed_response",
        }
    }
}

/// Structured log line for a fail-closed drop.
pub fn fault_log(request_id: &str, cause: FaultCause, elapsed_ms: u128, socket_path: &str, code: &str) -> String {
    format!(
        "{{\"event\":\"pep_fail_closed\",\"request_id\":\"{}\",\"cause\":\"{}\",\
          \"elapsed_ms\":{},\"socket_path\":\"{}\",\"code\":\"{}\"}}\n",
        request_id,
        cause.as_str(),
        elapsed_ms,
        socket_path,
        code
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verdict_lines_match_eyerun_shape() {
        assert_eq!(Verdict::Admitted.to_line(), "{\"verdict\":\"ADMITTED\"}\n");
        assert_eq!(
            Verdict::infra_fault().to_line(),
            "{\"verdict\":\"REFUSED\",\"code\":\"REFUSED_INFRASTRUCTURE_FAULT\"}\n"
        );
    }

    #[test]
    fn lease_missing_field_refused() {
        let now = SystemTime::now();
        let r = check_lease("{\"lease_id\":\"l1\",\"ruleset_digest\":\"d\"}", "d", now);
        assert_eq!(r, Err(RefusalCode::LeaseAbsent));
    }

    #[test]
    fn lease_expired_refused() {
        let r = check_lease(
            "{\"lease_id\":\"l1\",\"ruleset_digest\":\"d\",\"not_after\":1}",
            "d",
            SystemTime::now(),
        );
        assert_eq!(r, Err(RefusalCode::LeaseAbsent));
    }

    #[test]
    fn lease_digest_mismatch_refused() {
        let far = SystemTime::now() + Duration::from_secs(3600);
        let r = check_lease(
            "{\"lease_id\":\"l1\",\"ruleset_digest\":\"other\",\"not_after\":9999999999}",
            "expected",
            far,
        );
        assert_eq!(r, Err(RefusalCode::LeaseAbsent));
    }

    #[test]
    fn conforming_lease_admits() {
        let far = SystemTime::now() + Duration::from_secs(3600);
        let secs = far.duration_since(UNIX_EPOCH).unwrap().as_secs();
        let r = check_lease(
            &format!(
                "{{\"lease_id\":\"l1\",\"ruleset_digest\":\"d\",\"not_after\":{}}}",
                secs + 1
            ),
            "d",
            SystemTime::now(),
        );
        assert!(r.is_ok());
    }

    #[test]
    fn http_mapping_is_503() {
        let rec = http_error_record(&Verdict::infra_fault());
        assert!(rec.starts_with("HTTP/1.1 503"));
        assert!(rec.contains("REFUSED_INFRASTRUCTURE_FAULT"));
    }
}
