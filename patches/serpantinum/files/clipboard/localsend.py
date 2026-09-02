#!/usr/bin/env python3
"""LocalSend v2 protocol client/server for the serpantinum clipboard panel.

Written from the spec at github.com/localsend/protocol (v2.2) using only the
standard library. The alternatives were all dead ends: the official localsend
app is a Flutter GUI with no headless mode, and nixpkgs' `jocalsend` is a
ratatui TUI that cannot be driven from QML.

Subcommands, each printing JSON to stdout so Quickshell's Process/StdioCollector
can parse it directly:

  info                     our own alias / address / port, for the receive card
  discover                 announce, collect replies for a few seconds, list peers
  send --to H:P --text S   send a text payload to one peer
  send --to H:P --file F   send a file to one peer
  receive                  serve until killed, auto-accepting incoming transfers,
                           emitting one JSON event per line as things happen

`receive` is a long-running process the panel starts when the card opens and
kills when it closes, which is what makes "auto-accepted while this is open" a
safe default: nothing can be pushed to this machine while the card is shut.
"""

import argparse
import json
import mimetypes
import os
import socket
import ssl
import struct
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

MULTICAST_GROUP = "224.0.0.167"
PORT = 53317
PROTOCOL_VERSION = "2.0"

# Our HTTP server is plaintext. The spec makes `protocol` an explicit field for
# exactly this reason, so a peer knows which scheme to dial back on. Running TLS
# would mean generating and persisting a self-signed cert; peers we *send* to
# are still reached over https when they announce it (see _opener).
OUR_PROTOCOL = "http"

DOWNLOAD_DIR = os.path.join(
    os.environ.get("XDG_DOWNLOAD_DIR") or os.path.expanduser("~/Downloads"),
    "LocalSend",
)


def emit(obj):
    """One JSON object per line, flushed, so the QML side sees events live."""
    json.dump(obj, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")
    sys.stdout.flush()


def local_ip():
    """Address the default route would use. Connecting a UDP socket assigns a
    source address without sending anything, which beats gethostbyname — that
    returns 127.0.0.1 on hosts whose hostname is only in /etc/hosts."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def alias():
    return os.environ.get("LOCALSEND_ALIAS") or socket.gethostname()


# In plaintext mode the fingerprint is only used so we can recognise and drop
# our own multicast announcements, so a random value per run is all it needs to
# be. It is stashed on disk so `discover` and `receive` running as separate
# processes present the same identity to a phone.
def fingerprint():
    path = os.path.join(
        os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "serpantinum-localsend-id"
    )
    try:
        with open(path) as f:
            val = f.read().strip()
        if val:
            return val
    except OSError:
        pass
    val = uuid.uuid4().hex
    try:
        with open(path, "w") as f:
            f.write(val)
    except OSError:
        pass
    return val


def self_info(announce=None):
    info = {
        "alias": alias(),
        "version": PROTOCOL_VERSION,
        "deviceModel": "Linux",
        "deviceType": "desktop",
        "fingerprint": fingerprint(),
        "port": PORT,
        "protocol": OUR_PROTOCOL,
        "download": False,
    }
    if announce is not None:
        info["announce"] = announce
    return info


def _opener():
    """urllib opener that tolerates the self-signed certificates every LocalSend
    peer uses. The protocol pins trust to the certificate fingerprint rather
    than a CA, so chain verification would reject every real peer."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))


def post(url, body=None, raw=None, timeout=10):
    """POST JSON (body) or bytes (raw). Returns (status, decoded-or-bytes)."""
    if raw is not None:
        data = raw
        headers = {"Content-Type": "application/octet-stream"}
    else:
        data = json.dumps(body).encode()
        headers = {"Content-Type": "application/json"}
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with _opener().open(req, timeout=timeout) as resp:
            payload = resp.read()
            if payload:
                try:
                    return resp.status, json.loads(payload)
                except ValueError:
                    return resp.status, payload
            return resp.status, None
    except urllib.error.HTTPError as e:
        return e.code, None
    except (urllib.error.URLError, OSError, ssl.SSLError) as e:
        return 0, str(e)


def multicast_socket(bind=True):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if hasattr(socket, "SO_REUSEPORT"):
        try:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except OSError:
            pass
    if bind:
        s.bind(("", PORT))
        mreq = struct.pack("4sl", socket.inet_aton(MULTICAST_GROUP), socket.INADDR_ANY)
        s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    return s


def announce(sock, want_reply=True):
    payload = json.dumps(self_info(announce=want_reply)).encode()
    try:
        sock.sendto(payload, (MULTICAST_GROUP, PORT))
    except OSError:
        pass


# --------------------------------------------------------------------------
# discover
# --------------------------------------------------------------------------

def peer_record(msg, host):
    """Normalise an announcement or a /register body into one peer row."""
    return {
        "alias": msg.get("alias") or host,
        "host": host,
        "port": msg.get("port") or PORT,
        "protocol": msg.get("protocol") or "http",
        "deviceModel": msg.get("deviceModel") or "",
        "deviceType": msg.get("deviceType") or "",
        "fingerprint": msg.get("fingerprint") or "",
    }


def sweep_subnet(peers, lock, timeout=0.6):
    """Section 3.2: when multicast gets no answer, POST /register to every host
    on the local /24 and treat a JSON reply as a peer. Phones on Wi-Fi networks
    with multicast filtering (most consumer APs with client isolation, and a lot
    of mesh systems) only ever turn up this way."""
    ip = local_ip()
    if ip.startswith("127."):
        return
    prefix = ip.rsplit(".", 1)[0]
    body = self_info()

    def probe(n):
        target = f"{prefix}.{n}"
        if target == ip:
            return
        for scheme in ("http", "https"):
            status, resp = post(
                f"{scheme}://{target}:{PORT}/api/localsend/v2/register",
                body, timeout=timeout,
            )
            if status == 200 and isinstance(resp, dict):
                # The /register *response* carries no port or protocol field —
                # the spec omits both — so the reply alone would be recorded as
                # plaintext and a later send would hit a TLS port with cleartext.
                # We just proved which scheme answers, so keep it.
                row = peer_record(resp, target)
                row["protocol"] = scheme
                with lock:
                    peers[resp.get("fingerprint") or target] = row
                return

    threads = []
    for n in range(1, 255):
        th = threading.Thread(target=probe, args=(n,), daemon=True)
        th.start()
        threads.append(th)
    for th in threads:
        th.join(timeout=timeout * 2 + 1)


def cmd_discover(args):
    """Announce ourselves and collect whoever answers.

    The spec is explicit that a peer's *first* reply to an announcement is an
    HTTP POST to /register on the announcing device, and that the multicast
    datagram is only a fallback. So this listens on both: an HTTP server on the
    LocalSend port for the primary path, and the multicast socket for the
    fallback. Listening on multicast alone finds nothing at all against the
    official mobile app, which takes the documented HTTP route.

    If the HTTP port is already held — a `receive` card is open in the panel —
    that half is skipped rather than failing, and multicast still applies.
    """
    me = fingerprint()
    peers = {}
    lock = threading.Lock()

    # Primary reply path: peers POST /register to us.
    state = ReceiveState()
    state.peers = peers
    state.peer_lock = lock
    handler = type("DiscoverHandler", (Handler,), {"state": state})
    server = None
    try:
        server = ThreadingHTTPServer(("0.0.0.0", PORT), handler)
        server.daemon_threads = True
        threading.Thread(target=server.serve_forever, daemon=True).start()
    except OSError:
        server = None  # a receive session already owns the port

    sock = multicast_socket()
    sock.settimeout(0.5)

    deadline = time.time() + args.timeout
    last_announce = 0.0
    while time.time() < deadline:
        # Re-announce periodically; a phone that opens LocalSend midway through
        # our window still gets prompted to reply.
        if time.time() - last_announce > 1.0:
            announce(sock)
            last_announce = time.time()
        try:
            data, addr = sock.recvfrom(65535)
        except socket.timeout:
            continue
        except OSError:
            break
        try:
            msg = json.loads(data.decode())
        except (ValueError, UnicodeDecodeError):
            continue
        if not isinstance(msg, dict):
            continue
        if msg.get("fingerprint") == me:
            continue  # our own announcement echoed back
        with lock:
            peers[msg.get("fingerprint") or addr[0]] = peer_record(msg, addr[0])
        # A peer that announced with announce:true is waiting for our reply.
        if msg.get("announce"):
            try:
                sock.sendto(
                    json.dumps(self_info(announce=False)).encode(),
                    (MULTICAST_GROUP, PORT),
                )
            except OSError:
                pass

    sock.close()

    with lock:
        found = len(peers)
    if found == 0 and not args.no_sweep:
        sweep_subnet(peers, lock)

    if server is not None:
        server.shutdown()

    with lock:
        rows = list(peers.values())
    emit({"event": "peers", "peers": rows})
    return 0


# --------------------------------------------------------------------------
# send
# --------------------------------------------------------------------------

def cmd_send(args):
    if not args.text and not args.file:
        emit({"event": "error", "message": "nothing to send"})
        return 1

    host, _, port_s = args.to.partition(":")
    port = int(port_s) if port_s else PORT
    scheme = args.scheme
    base = f"{scheme}://{host}:{port}/api/localsend/v2"

    file_id = uuid.uuid4().hex
    if args.file:
        try:
            size = os.path.getsize(args.file)
            with open(args.file, "rb") as f:
                payload = f.read()
        except OSError as e:
            emit({"event": "error", "message": f"cannot read file: {e}"})
            return 1
        name = os.path.basename(args.file)
        mime = mimetypes.guess_type(name)[0] or "application/octet-stream"
    else:
        payload = args.text.encode()
        size = len(payload)
        # The official app renders a file whose type is text/plain as a text
        # message rather than a download, which is what "send clipboard" should
        # look like on the phone.
        name = "clipboard.txt"
        mime = "text/plain"

    meta = {
        "id": file_id,
        "fileName": name,
        "size": size,
        "fileType": mime,
    }
    body = {"info": self_info(), "files": {file_id: meta}}
    status, resp = post(f"{base}/prepare-upload", body)

    # A peer discovered through the /24 sweep, or through any stale cache, can
    # carry the wrong scheme: the /register response has no `protocol` field to
    # read it from. Sending cleartext at a TLS listener gets the connection torn
    # down (ECONNRESET), and TLS at a cleartext one fails just as opaquely, so a
    # transport-level failure is retried once on the other scheme rather than
    # reported. Status 0 is `post`'s marker for "never got an HTTP reply".
    if status == 0:
        other = "https" if scheme == "http" else "http"
        alt = f"{other}://{host}:{port}/api/localsend/v2"
        alt_status, alt_resp = post(f"{alt}/prepare-upload", body)
        if alt_status != 0:
            scheme, base, status, resp = other, alt, alt_status, alt_resp

    if status == 204:
        emit({"event": "done", "message": "nothing to transfer"})
        return 0
    if status == 403:
        emit({"event": "error", "message": "declined on the other device"})
        return 1
    if status == 401:
        emit({"event": "error", "message": "PIN required — not supported"})
        return 1
    if status != 200 or not isinstance(resp, dict):
        detail = resp if isinstance(resp, str) else f"HTTP {status}"
        emit({"event": "error", "message": f"prepare-upload failed: {detail}"})
        return 1

    session = resp.get("sessionId")
    token = (resp.get("files") or {}).get(file_id)
    if not session or not token:
        emit({"event": "error", "message": "peer returned no upload token"})
        return 1

    emit({"event": "sending", "file": name, "size": size})
    url = f"{base}/upload?sessionId={session}&fileId={file_id}&token={token}"
    status, resp = post(url, raw=payload, timeout=300)
    if status not in (200, 204):
        detail = resp if isinstance(resp, str) else f"HTTP {status}"
        emit({"event": "error", "message": f"upload failed: {detail}"})
        return 1

    emit({"event": "done", "file": name, "size": size})
    return 0


# --------------------------------------------------------------------------
# receive
# --------------------------------------------------------------------------

class ReceiveState:
    def __init__(self):
        self.lock = threading.Lock()
        self.sessions = {}  # sessionId -> {fileId: {"token","name","size"}}
        # Set by cmd_discover so /register can record who answered. Left empty
        # during a receive session, where the peer list is not needed.
        self.peers = None
        self.peer_lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    state = None  # set on the server class

    def log_message(self, *a):
        pass  # stdout is the JSON event channel; keep access logs off it

    def _json(self, code, obj=None):
        body = json.dumps(obj).encode() if obj is not None else b""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0:
            return b""
        chunks = []
        remaining = length
        while remaining > 0:
            chunk = self.rfile.read(min(remaining, 1 << 20))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        return b"".join(chunks)

    def do_POST(self):
        parsed = urlparse(self.path)
        route = parsed.path
        query = parse_qs(parsed.query)

        if route.endswith("/register"):
            # Answering is only half the job: the body identifies the peer, and
            # during discovery this is how the official mobile app tells us it
            # exists at all.
            if self.state.peers is not None:
                try:
                    req = json.loads(self._read_body().decode())
                except (ValueError, UnicodeDecodeError):
                    req = None
                if isinstance(req, dict) and req.get("fingerprint") != fingerprint():
                    host = self.client_address[0]
                    with self.state.peer_lock:
                        self.state.peers[req.get("fingerprint") or host] = \
                            peer_record(req, host)
            self._json(200, self_info())
            return

        if route.endswith("/prepare-upload"):
            try:
                req = json.loads(self._read_body().decode())
            except (ValueError, UnicodeDecodeError):
                self._json(400)
                return
            files = req.get("files") or {}
            if not files:
                self._json(204)
                return
            session = uuid.uuid4().hex
            tokens = {}
            record = {}
            for fid, meta in files.items():
                tok = uuid.uuid4().hex
                tokens[fid] = tok
                record[fid] = {
                    "token": tok,
                    "name": os.path.basename(meta.get("fileName") or fid),
                    "size": meta.get("size") or 0,
                }
            with self.state.lock:
                self.state.sessions[session] = record
            sender = (req.get("info") or {}).get("alias") or self.client_address[0]
            emit({
                "event": "incoming",
                "from": sender,
                "files": [v["name"] for v in record.values()],
            })
            self._json(200, {"sessionId": session, "files": tokens})
            return

        if route.endswith("/upload"):
            session = (query.get("sessionId") or [""])[0]
            fid = (query.get("fileId") or [""])[0]
            token = (query.get("token") or [""])[0]
            with self.state.lock:
                record = self.state.sessions.get(session)
                entry = record.get(fid) if record else None
            if not entry or entry["token"] != token:
                self._json(403)
                return
            data = self._read_body()
            try:
                os.makedirs(DOWNLOAD_DIR, exist_ok=True)
                path = unique_path(os.path.join(DOWNLOAD_DIR, entry["name"]))
                with open(path, "wb") as f:
                    f.write(data)
            except OSError as e:
                emit({"event": "error", "message": f"cannot save: {e}"})
                self._json(500)
                return
            emit({"event": "received", "file": os.path.basename(path),
                  "path": path, "size": len(data)})
            self._json(200)
            return

        if route.endswith("/cancel"):
            session = (query.get("sessionId") or [""])[0]
            with self.state.lock:
                self.state.sessions.pop(session, None)
            emit({"event": "cancelled"})
            self._json(200)
            return

        self._json(404)

    def do_GET(self):
        if urlparse(self.path).path.endswith("/info"):
            self._json(200, self_info())
            return
        self._json(404)


def unique_path(path):
    """Never overwrite: file.txt, file (1).txt, file (2).txt ..."""
    if not os.path.exists(path):
        return path
    stem, ext = os.path.splitext(path)
    n = 1
    while os.path.exists(f"{stem} ({n}){ext}"):
        n += 1
    return f"{stem} ({n}){ext}"


def cmd_receive(args):
    state = ReceiveState()
    handler = type("BoundHandler", (Handler,), {"state": state})

    try:
        server = ThreadingHTTPServer(("0.0.0.0", PORT), handler)
    except OSError as e:
        emit({"event": "error", "message": f"cannot listen on {PORT}: {e}"})
        return 1
    server.daemon_threads = True

    threading.Thread(target=server.serve_forever, daemon=True).start()

    ip = local_ip()
    emit({
        "event": "ready",
        "alias": alias(),
        "host": ip,
        "port": PORT,
        "saveDir": DOWNLOAD_DIR,
    })

    # Keep announcing so a phone that opens LocalSend after us still sees this
    # machine in its device list.
    sock = multicast_socket(bind=False)
    try:
        while True:
            announce(sock, want_reply=False)
            time.sleep(2.0)
    except KeyboardInterrupt:
        pass
    finally:
        sock.close()
        server.shutdown()
    return 0


def cmd_info(args):
    info = self_info()
    info["host"] = local_ip()
    info["saveDir"] = DOWNLOAD_DIR
    emit(info)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("info")

    d = sub.add_parser("discover")
    d.add_argument("--timeout", type=float, default=4.0)
    d.add_argument("--no-sweep", action="store_true",
                   help="skip the /24 unicast fallback when multicast finds nobody")

    s = sub.add_parser("send")
    s.add_argument("--to", required=True, help="host or host:port")
    s.add_argument("--scheme", default="http", choices=["http", "https"])
    s.add_argument("--text")
    s.add_argument("--file")

    sub.add_parser("receive")

    args = ap.parse_args()
    return {
        "info": cmd_info,
        "discover": cmd_discover,
        "send": cmd_send,
        "receive": cmd_receive,
    }[args.cmd](args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
