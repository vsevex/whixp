//! Stanza processing: stream framing (split bytes into XML stanzas) and optional parsing.
//! Emits one stanza at a time to Dart via callback (UTF-8 XML string or structured).
//!
//! Covers RFC 6120/6121 (core, stream, SASL), XEP-0198 (stream management), TLS, and
//! common XEPs so we don't add stanza types one-by-one.

use thiserror::Error;

#[derive(Error, Debug)]
pub enum StanzaError {
    #[error("incomplete stanza")]
    Incomplete,
    #[error("parse error: {0}")]
    Parse(String),
}

/// Buffers incoming bytes and splits on stanza boundaries (closing tags and self-closing root elements).
/// Handles stream header in Rust for stream:error and see-other-host.
pub struct StreamFramer {
    buffer: Vec<u8>,
    depth: i32,
    in_stream_header: bool,
}

/// All known top-level closing tags (RFC 6120, 6121, SASL, TLS, XEP-0198, stream errors, etc.).
/// Order doesn't matter for correctness; we take the leftmost match.
const CLOSE_TAGS: &[&str] = &[
    // Core stanzas (RFC 6120, 6121)
    "</iq>",
    "</message>",
    "</presence>",
    // Stream (RFC 6120)
    "</stream:features>",
    "</stream:stream>",
    "</stream>",
    "</stream:error>",
    "</error>",
    // SASL (RFC 6120)
    "</challenge>",
    "</success>",
    "</failure>",
    "</auth>",
    "</response>",
    "</abort>",
    // TLS (XEP-0035 / RFC 6120)
    "</starttls>",
    "</proceed>",
    // Stream management (XEP-0198)
    "</failed>",
    "</enabled>",
    "</resumed>",
    "</enable>",
    "</resume>",
    // Bind / session (RFC 6120)
    "</bind>",
    "</session>",
    // Common XEPs
    "</handshake>", // component protocol
    "</body>",      // BOSH
    "</open>",      // BOSH
    "</close>",     // BOSH
];

/// Root-level elements that are typically self-closing: <r/> <a/> <enabled/> <proceed/> etc.
/// We look for "<NAME " or "<NAME>" then the matching "/>".
const SELF_CLOSING_ROOT: &[&str] = &[
    "r", "a", // XEP-0198 ack request/response
    "enabled", "failed", "resumed", "enable", "resume",  // XEP-0198
    "proceed", // TLS
];

impl Default for StreamFramer {
    fn default() -> Self {
        Self {
            buffer: Vec::new(),
            depth: 0,
            in_stream_header: true,
        }
    }
}

impl StreamFramer {
    pub fn new() -> Self {
        Self::default()
    }

    /// Push bytes; returns completed stanza XML strings (UTF-8).
    pub fn push(&mut self, data: &[u8]) -> Result<Vec<String>, StanzaError> {
        self.buffer.extend(data);
        let mut out = Vec::new();
        loop {
            match self.take_next_stanza()? {
                Some(s) => out.push(s),
                None => break,
            }
        }
        Ok(out)
    }

    /// Try to extract one full stanza from buffer. Returns None if incomplete.
    fn take_next_stanza(&mut self) -> Result<Option<String>, StanzaError> {
        let s = match std::str::from_utf8(&self.buffer) {
            Ok(x) => x,
            Err(_) => return Ok(None),
        };

        // 1) Leftmost closing tag
        let mut best_end: Option<usize> = None;
        for tag in CLOSE_TAGS {
            if let Some(idx) = s.find(tag) {
                let end = idx + tag.len();
                if best_end.map(|e| end < e).unwrap_or(true) {
                    best_end = Some(end);
                }
            }
        }

        // 2) Leftmost self-closing root element
        for name in SELF_CLOSING_ROOT {
            let open1 = format!("<{} ", name);
            let open2 = format!("<{}>", name);
            let start = s.find(&open1).or_else(|| s.find(&open2));
            if let Some(start) = start {
                let after_open = start + open1.len().max(open2.len());
                if let Some(rel) = s[after_open..].find("/>") {
                    let end = after_open + rel + 2;
                    if best_end.map(|e| end < e).unwrap_or(true) {
                        best_end = Some(end);
                    }
                }
            }
        }

        if let Some(end) = best_end {
            let chunk = s[..end].to_string();
            self.buffer.drain(..end);
            return Ok(Some(chunk));
        }

        // 3) Stream header: optional <?xml ...?> then <stream:stream ...> or <stream ...>
        if self.in_stream_header {
            let rest = s.trim_start();
            let rest = if rest.starts_with("<?xml") {
                rest.find('>')
                    .map(|i| rest[i + 1..].trim_start())
                    .unwrap_or(rest)
            } else {
                rest
            };
            if rest.starts_with("<stream:stream") || rest.starts_with("<stream ") {
                if let Some(open_brace) = rest.find('<') {
                    let from = s.len() - rest.len() + open_brace;
                    if let Some(end) = s[from..].find('>') {
                        let end = from + end;
                        let chunk = s[..=end].to_string();
                        self.buffer.drain(..=end);
                        self.in_stream_header = false;
                        return Ok(Some(chunk));
                    }
                }
            }
        }
        Ok(None)
    }

    pub fn reset(&mut self) {
        self.buffer.clear();
        self.depth = 0;
        self.in_stream_header = true;
    }
}
