//! DNS resolution: local (system) resolver first, DoH fallback.
//! Used for XMPP SRV (_xmpp-client._tcp.domain) and A/AAAA lookups.

use std::net::IpAddr;
use std::sync::OnceLock;

use crate::handshake::HandshakeError;
use trust_dns_resolver::TokioAsyncResolver;

/// One-off runtime for blocking on async DNS. Shared to avoid spawning many runtimes.
static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();

fn runtime() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| tokio::runtime::Runtime::new().expect("tokio runtime for DNS"))
}

/// Resolve XMPP connection target: try SRV (if service given) then A/AAAA.
/// Uses system resolver first, then DoH (Cloudflare) on failure.
/// Returns (host, port) for use with TCP/TLS connect.
/// If `service` is None, returns (domain, port) without SRV lookup.
pub fn resolve_xmpp(
    domain: &str,
    port: u16,
    service: Option<&str>,
    use_ipv6: bool,
) -> Result<(String, u16), HandshakeError> {
    let domain = domain.trim_end_matches('.');
    if domain.is_empty() {
        return Err(HandshakeError::Connection("empty domain".into()));
    }

    let service = service
        .map(|s| s.trim_end_matches('.'))
        .filter(|s| !s.is_empty());

    // No SRV: use domain and port as-is (connect will do getaddrinfo).
    let Some(srv_service) = service else {
        return Ok((domain.to_string(), port));
    };

    // Try system resolver first.
    if let Ok((host, p)) = try_system_resolver(domain, port, srv_service, use_ipv6) {
        return Ok((host, p));
    }

    // Fallback: DoH.
    if let Ok((host, p)) = try_doh(domain, port, srv_service, use_ipv6) {
        return Ok((host, p));
    }

    // Last resort: no SRV, use domain:port.
    Ok((domain.to_string(), port))
}

/// System resolver (e.g. /etc/resolv.conf). SRV + A/AAAA.
fn try_system_resolver(
    domain: &str,
    _default_port: u16,
    service: &str,
    _use_ipv6: bool,
) -> Result<(String, u16), HandshakeError> {
    let srv_name = format!("_{}._{}.{}", service, "tcp", domain);
    let rt = runtime();
    rt.block_on(async {
        let resolver = TokioAsyncResolver::tokio_from_system_conf()
            .map_err(|e| HandshakeError::Connection(format!("system DNS config: {}", e)))?;
        let srv_lookup = resolver
            .srv_lookup(srv_name.clone())
            .await
            .map_err(|e| HandshakeError::Connection(format!("SRV lookup {}: {}", srv_name, e)))?;
        let mut records: Vec<_> = srv_lookup.iter().collect();
        if records.is_empty() {
            return Err(HandshakeError::Connection(format!(
                "no SRV records for {}",
                srv_name
            )));
        }
        records.sort_by(|a, b| {
            a.priority()
                .cmp(&b.priority())
                .then_with(|| a.weight().cmp(&b.weight()))
        });
        for srv in &records {
            let target = srv.target().to_utf8().trim_end_matches('.').to_string();
            let port = srv.port();
            let lookup = resolver.lookup_ip(target.clone()).await;
            if let Ok(l) = lookup {
                let ips: Vec<IpAddr> = l.iter().collect();
                if !ips.is_empty() {
                    return Ok((target, port));
                }
            }
        }
        let first = records[0];
        let first_target = first.target().to_utf8().trim_end_matches('.').to_string();
        Ok((first_target, first.port()))
    })
}

/// DoH (Cloudflare) fallback. SRV type = 33, A = 1, AAAA = 28.
const DOH_URL: &str = "https://cloudflare-dns.com/dns-query";

#[derive(serde::Deserialize)]
struct DohResponse {
    #[serde(default)]
    status: u32,
    #[serde(default)]
    answer: Vec<DohAnswer>,
}

#[derive(serde::Deserialize)]
struct DohAnswer {
    #[serde(default)]
    #[serde(rename = "type")]
    typ: u32,
    #[serde(default)]
    data: String,
}

fn try_doh(
    domain: &str,
    _default_port: u16,
    service: &str,
    _use_ipv6: bool,
) -> Result<(String, u16), HandshakeError> {
    let srv_name = format!("_{}._{}.{}", service, "tcp", domain);
    let url_srv = format!("{}?name={}&type=SRV", DOH_URL, srv_name);
    let resp = ureq::get(&url_srv)
        .set("Accept", "application/dns-json")
        .call()
        .map_err(|e| HandshakeError::Connection(format!("DoH SRV request failed: {}", e)))?;
    let body: DohResponse = resp
        .into_json()
        .map_err(|e| HandshakeError::Connection(format!("DoH JSON: {}", e)))?;
    if body.status != 0 {
        return Err(HandshakeError::Connection(format!(
            "DoH SRV status {}",
            body.status
        )));
    }
    // Parse SRV: data = "priority weight port target"
    let mut srv_list: Vec<(u16, u16, u16, String)> = Vec::new();
    for a in &body.answer {
        if a.typ != 33 {
            continue;
        }
        let parts: Vec<&str> = a.data.trim().split_whitespace().collect();
        if parts.len() >= 4 {
            if let (Ok(pri), Ok(_w), Ok(port)) = (
                parts[0].parse::<u16>(),
                parts[1].parse::<u16>(),
                parts[2].parse::<u16>(),
            ) {
                let target = parts[3].trim_end_matches('.').to_string();
                srv_list.push((pri, _w, port, target));
            }
        }
    }
    if srv_list.is_empty() {
        return Err(HandshakeError::Connection(format!(
            "DoH: no SRV records for {}",
            srv_name
        )));
    }
    srv_list.sort_by_key(|(p, w, _, _)| (*p, *w));
    for (_pri, _weight, port, target) in srv_list {
        // Optional: resolve target via DoH A/AAAA to check reachability. For simplicity
        // we just return first SRV (host, port); connect will resolve the hostname.
        return Ok((target, port));
    }
    Err(HandshakeError::Connection("DoH: no valid SRV data".into()))
}
