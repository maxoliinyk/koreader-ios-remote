# KORemote protocol v1

## Transport

The Apple client sends one short HTTP request to the KOReader device for each action. KOReader listens only while active.

- Default port: `9090`, configurable in the plugin.
- `POST /v1/action`: page and sleep actions.
- `POST /v1/ping`: readiness check.
- Content type: `application/json`.
- Request body limit: 4096 bytes.
- Header limit: 8192 bytes total, 2048 bytes per line, 64 lines including the request line.
- One 250 ms deadline covers receipt of headers and body.
- A single Content-Length header is required; chunked transfer encoding is unsupported.
- Connection closes after each response.

## Pairing

KOReader generates 32 cryptographically random bytes from `/dev/urandom` and stores the unpadded base64url value locally. The pairing QR contains:

```text
koreaderturner://pair?v=1&host=192.168.1.20&port=9090&name=KOReader&secret=<base64url>
```

The iOS app validates every field before saving. Endpoint metadata goes into `UserDefaults` (shared in the full build, app-local in sideload builds); the secret goes into Keychain. Generating a new secret invalidates every existing phone and watch pairing.

## Authenticated request

```json
{
  "version": 1,
  "action": "next",
  "nonce": "<random base64url>",
  "mac": "<lowercase HMAC-SHA256 hex>"
}
```

Allowed actions: `next`, `previous`, and `sleep` on `/v1/action`; `ping` on `/v1/ping`.

Canonical authentication input, with literal line feeds and no final newline:

```text
version=1
action=next
nonce=<nonce>
```

`mac = HMAC-SHA256(pairing_secret_bytes, canonical_utf8)`

KOReader compares the MAC without early exit, then inserts the nonce into a 128-entry bounded cache. Reusing an accepted nonce returns `409`. The cache survives listener stop/start while the plugin instance remains alive, but is cleared on plugin restart or secret regeneration.

## Responses

Success: `{"ok":true,"message":"accepted"}`

Error: `{"ok":false,"message":"Authentication failed"}`

- `400`: malformed JSON, fields, route/action mismatch, or unsupported protocol.
- `401`: HMAC mismatch.
- `404`: unknown route.
- `405`: method other than POST.
- `409`: replayed nonce.
- `413`: request too large.

## KOReader actions

- `next` → `GotoViewRel(1)`
- `previous` → `GotoViewRel(-1)`
- `sleep` → `RequestSuspend`

The plugin sends the success response before scheduling the KOReader event. A timeout or lost response does not prove the action failed; do not automatically retry a page action with a new nonce. The Watch relays through iPhone only when the direct connection is unreachable.

## Security boundary

This protocol authenticates local requests; it does not encrypt them. Use it only on a trusted local Wi-Fi network. Secrets, nonces, and request bodies are intentionally excluded from logs.
