# Hermes Agent — Web Dashboard Basic Auth (env vars & behavior)

Research date: 2026-05-10. Verified against **primary sources only**: the installed
package source (authoritative for the deployed v2026.7.1) and the upstream GitHub
`main` source + docs.

## Sources

- **Deployed plugin (authoritative):**
  `/nix/store/wasmhz6h8gg0yv8s4jfah7kx6xy0fxvy-hermes-agent-2026.7.1/share/hermes-agent/plugins/dashboard_auth/basic/__init__.py`
- **Deployed CLI/web-server logic:** the 2026.7.1 wrapper (`bin/hermes-agent`) resolves to
  `hermes-agent-env` (`/nix/store/80827vlrwgzjadglsy4ssfvrk4whipa0-hermes-agent-env`), whose
  `hermes_cli` is a symlink to **hermes-agent-0.18.0**. So these are the *live* files behind the
  running dashboard, not a mismatched copy:
  - `/nix/store/nvrxzz41mjw8g4wk58mp137h9pac7fsd-hermes-agent-0.18.0/lib/python3.12/site-packages/hermes_cli/web_server.py`
  - `.../hermes_cli/subcommands/dashboard.py`
- **Upstream GitHub `main`:**
  `NousResearch/hermes-agent` — `plugins/dashboard_auth/basic/__init__.py`,
  `hermes_cli/subcommands/dashboard.py`, `website/docs/user-guide/features/web-dashboard.md`.

Cross-check result: the `main` **source** (plugin + dashboard subcommand) is byte-identical in the
relevant lines to the installed v2026.7.1/0.18.0 — same env var names, same `hash_password`, same
`--insecure` NO-OP help. Only the `main` **doc prose** lags (see Discrepancies).

---

## Authoritative env var names (v2026.7.1)

| Env var | Purpose | Preferred? | Citation |
|---|---|---|---|
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | Login username; required to activate the provider. | required | plugin `__init__.py:35`, `:408`; `plugin.yaml:7` |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` | Precomputed scrypt hash — no plaintext at rest. | **preferred** | plugin `__init__.py:36` (`# preferred`), `:411` |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | Plaintext password, hashed in-memory at load. Env password **overrides** any config `password_hash` (rotate via env). | plaintext fallback | plugin `__init__.py:37` (`# plaintext fallback`), `:414`, `:441-458` |
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | HMAC token-signing key (base64/hex/raw, ≥16 bytes). If unset, a random per-process key is generated → sessions die on restart / don't span workers. | optional | plugin `__init__.py:38`, `:372`, `:364-391` |
| `HERMES_DASHBOARD_BASIC_AUTH_TTL_SECONDS` | Access-token lifetime (default 12h). Config key is `session_ttl_seconds`. | optional | plugin `__init__.py:39`, `:417`; default `_DEFAULT_TTL_SECONDS = 12*60*60` at `:89` |

**Precedence:** env wins over `config.yaml` when set non-empty (`_resolve()` at
`__init__.py:356-361`, docstring `:17-18`). Provider activates only when `username` **plus** either
`password_hash` or `password` are present, else it's a silent no-op (`:420-439`).

---

## config.yaml equivalent

Canonical surface, nesting confirmed from the plugin docstring (`__init__.py:20-31`):

```yaml
dashboard:
  basic_auth:
    username: admin               # required
    password_hash: "scrypt$..."   # preferred — no plaintext at rest; see hash_password()
    password: "s3cret"            # OR plaintext (hashed in-memory at load)
    secret: "<32+ random bytes, base64 or hex>"  # optional; token-signing key
    session_ttl_seconds: 43200    # optional; access-token lifetime (default 12h)
```

Env→config key map (from `_resolve()` calls, `__init__.py:407-418`):
`USERNAME→username`, `PASSWORD_HASH→password_hash`, `PASSWORD→password`, `SECRET→secret`,
`TTL_SECONDS→session_ttl_seconds`.

---

## Password hash generation

`hash_password()` lives at `plugins.dashboard_auth.basic` (plugin `__init__.py:115-136`). Exact
one-liner from its own docstring (`:120-121`):

```sh
python -c "from plugins.dashboard_auth.basic import hash_password; print(hash_password('pw'))"
```

Hash format prefix: `scrypt$n$r$p$<salt_b64>$<dk_b64>` — concretely
`scrypt$16384$8$1$<salt>$<dk>` (params `_SCRYPT_N=2**14`, `r=8`, `p=1`; `__init__.py:95-97`,
format string `:133-136`). Verify path `_verify_password()` requires the `scrypt` scheme prefix
(`:142-143`).

---

## `--insecure` status — deprecated NO-OP

Deployed CLI help text, verbatim (`subcommands/dashboard.py:31-40`):

> `"--insecure"` … `"DEPRECATED / NO-OP. Formerly bypassed auth on a non-loopback bind. As of the June 2026 hardening it no longer disables authentication — a public bind always requires an auth provider (password or OAuth). Bind 127.0.0.1 + tunnel to keep it local."`

Web-server confirmation (`web_server.py:395-401`, in `should_require_auth` docstring):

> "``allow_public`` (the legacy ``--insecure`` escape hatch) NO LONGER disables the gate. It is
> accepted for backward-compat with old launch scripts and desktop shells but is ignored: a
> non-loopback bind ALWAYS requires an auth provider …"

If still passed on a non-loopback bind, it only logs a warning (`web_server.py:14195-14206`):
`"--insecure no longer bypasses dashboard authentication. A non-loopback bind (%s) now ALWAYS
requires an auth provider (OAuth or the bundled password provider)…"`. The gate then fails closed
if no provider is registered (`:14209-14216`).

Identical NO-OP help on upstream `main` (`hermes_cli/subcommands/dashboard.py:33-39`).

---

## Non-loopback / Tailscale CGNAT auth requirement

Loopback is **only** `127.0.0.1`, `localhost`, `::1`. Everything else — including Tailscale CGNAT
(`100.64.0.0/10`) and RFC1918 LAN — is treated as PUBLIC and **gated**.

`web_server.py:379-403` (`_LOOPBACK_HOST_VALUES` + `should_require_auth`), verbatim:

```python
_LOOPBACK_HOST_VALUES: frozenset = frozenset({
    "localhost", "127.0.0.1", "::1",
})

def should_require_auth(host: str, allow_public: bool = False) -> bool:
    """Return True iff the dashboard auth gate must be active.

    Truth table:
      host == loopback        → False (no auth — local-only, trusted operator)
      host != loopback        → True  (gate engages — OAuth or password required)

    "Loopback" is 127.0.0.1, localhost, ::1. RFC1918 / CGNAT / link-local are
    deliberately treated as PUBLIC — a hostile device on the same LAN is exactly
    the threat model the gate is designed for.
    ...
    """
    return host not in _LOOPBACK_HOST_VALUES
```

Consequence for this setup: binding the dashboard to a **Tailscale IP (100.64.0.0/10)** or any LAN
address makes `should_require_auth` return `True`, so the basic-auth (or OAuth) provider **must** be
configured or the server fails closed at startup (`web_server.py:14209-14216`).

---

## Docs vs. source discrepancies

Env var names, config keys, and `hash_password` usage: the `main` doc
(`website/docs/user-guide/features/web-dashboard.md:712-716`, `:697-701`, `:732`) **match the
installed v2026.7.1 source exactly** — no drift.

The drift is entirely in the doc's `--insecure` prose (stale relative to BOTH the installed source
and the `main` source):

- `web-dashboard.md:30` — options table still says `--insecure` = "Allow binding to non-localhost
  hosts (**DANGEROUS** …)". Source: it no longer affects binding-vs-auth at all (NO-OP).
- `web-dashboard.md:580-583` — a `:::danger` block titled **"`--insecure` disables auth entirely"**:
  "`--insecure` skips the gate and serves an unauthenticated dashboard…". **Directly contradicts**
  `should_require_auth` (`web_server.py:395-403`) and the CLI help (`dashboard.py:36-39`), where
  `--insecure` is an ignored no-op.
- `web-dashboard.md:573`, `:663`, `:683`, `:691`, `:742` — repeatedly phrase the gate as engaging
  "on a non-loopback bind **without `--insecure`**", implying `--insecure` still bypasses. Stale.

So: **`main` source == installed source** (newer hardening already in both); **`main` doc is
staler than both** on `--insecure`. The env-var reference table in the doc is correct.

---

## Bottom line — sops env blob

For a Tailscale/LAN-bound dashboard, put these in the sops env (username + preferred hash + a
stable signing secret):

```
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=<user>
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH=<output of hash_password('...')>   # scrypt$16384$8$1$...
HERMES_DASHBOARD_BASIC_AUTH_SECRET=<openssl rand -base64 32>                 # stable sessions across restart
# optional:
# HERMES_DASHBOARD_BASIC_AUTH_TTL_SECONDS=43200
```

Generate the hash with:

```sh
python -c "from plugins.dashboard_auth.basic import hash_password; print(hash_password('choose-a-strong-password'))"
```

Prefer `_PASSWORD_HASH` over `_PASSWORD` (no plaintext at rest). If you use `_PASSWORD` instead, note
it overrides any config `password_hash`. Set `_SECRET` so sessions survive restarts. Do **not** rely
on `--insecure` — it is a no-op; a non-loopback (Tailscale/LAN) bind always requires these.
