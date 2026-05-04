import json
import os
import subprocess
import sys
from datetime import date, datetime, timedelta
from http.server import HTTPServer, BaseHTTPRequestHandler

NOTEBOOKLM = os.environ.get("NOTEBOOKLM_BIN", "notebooklm")
SOURCE_WAIT_TIMEOUT = 120


def run_cmd(args, input_text=None, timeout=300):
    result = subprocess.run(
        [NOTEBOOKLM] + args,
        capture_output=True, text=True,
        input=input_text, timeout=timeout
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def log(msg):
    print("[notebooklm-bridge] " + msg, file=sys.stderr)


def wait_for_sources(notebook_id, source_ids):
    """Wait until all sources are ready or timeout."""
    for sid in source_ids:
        out, err, rc = run_cmd(
            ["source", "wait", sid, "-n", notebook_id, "--timeout", str(SOURCE_WAIT_TIMEOUT)],
            timeout=SOURCE_WAIT_TIMEOUT + 30
        )
        if rc != 0:
            log(f"source {sid} wait failed: {err}")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/cleanup":
            self._handle_cleanup()
            return
        if self.path != "/digest":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))

        links = body.get("links", [])
        include_trending = body.get("include_trending", False)

        if not links:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"error": "no links"}')
            return

        today = date.today().strftime("%Y-%m-%d")
        title = "Daily Digest " + today

        # Create notebook
        out, err, rc = run_cmd(["create", title, "--json"])
        if rc != 0:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(json.dumps({"error": "create failed: " + err}).encode())
            return

        create_data = json.loads(out)
        notebook_id = create_data.get("notebook", {}).get("id", "") or create_data.get("id", "")
        log(f"created notebook {notebook_id}: {title}")

        # Add each link as a URL source — NotebookLM fetches the content itself
        source_ids = []
        sources_failed = 0
        for link in links:
            if not link.startswith("http"):
                continue
            out, err, rc = run_cmd(["source", "add", link, "--notebook", notebook_id, "--json"])
            if rc == 0:
                try:
                    src_data = json.loads(out)
                    sid = src_data.get("source", {}).get("id", "") or src_data.get("source_id", "")
                    if sid:
                        source_ids.append(sid)
                except json.JSONDecodeError:
                    pass
                log(f"added source: {link}")
            else:
                sources_failed += 1
                log(f"failed to add source: {link} — {err}")

        if not source_ids:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({
                "notebook_id": notebook_id,
                "title": title,
                "sources_added": 0,
                "sources_failed": sources_failed,
                "error": "no sources were added successfully",
            }).encode())
            return

        # Wait for all sources to be indexed before prompting
        log(f"waiting for {len(source_ids)} sources to be indexed...")
        wait_for_sources(notebook_id, source_ids)
        log("sources ready")

        # Prompt NotebookLM to create a structured summary note
        trending_section = (
            "\n\n## Trending GitHub Repositories\n"
            "List the top 20 trending repositories from the past week. "
            "For each, include the repository name with link, star count, and description."
        ) if include_trending else ""

        summary_prompt = (
            "Create a structured summary with the following format:\n\n"
            "## Daily Digest Summary\n"
            "A short combined summary of all the resources (2-3 sentences).\n\n"
            "## Links & Highlights\n"
            "A list where each item is the link to the resource followed by a one sentence summary.\n\n"
            "## Detailed Summaries\n"
            "For each link, write a paragraph-length summary of the content."
            f"{trending_section}\n\n"
            "Include every source. Use the original link URL for each item.\n\n"
            "Do not end with questions, suggestions, or offers to do more. "
            "Just provide the summary and stop."
        )
        out, err, rc = run_cmd(
            ["ask", summary_prompt, "--notebook", notebook_id, "--save-as-note",
             "--note-title", f"Daily Digest {today}"]
        )
        if rc == 0:
            log("summary note saved")
        else:
            log(f"summary prompt failed: {err}")

        # Generate podcast
        audio_prompt = (
            "Create a daily news briefing podcast. "
            "Focus on what matters for a cybersecurity and AI professional. "
            "Cover each topic in depth."
        )
        out, err, rc = run_cmd(["generate", "audio", audio_prompt, "--notebook", notebook_id, "--length", "long", "--json"])
        if rc == 0:
            log("audio generation started")
        else:
            log(f"audio generation failed: {err}")

        response = {
            "notebook_id": notebook_id,
            "title": title,
            "sources_added": len(source_ids),
            "sources_failed": sources_failed,
            "audio_generated": rc == 0,
        }

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def _handle_cleanup(self):
        """Delete Daily Digest notebooks older than 10 days."""
        out, err, rc = run_cmd(["list", "--json"])
        if rc != 0:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(json.dumps({"error": "list failed: " + err}).encode())
            return

        notebooks = json.loads(out).get("notebooks", [])
        cutoff = datetime.now() - timedelta(days=10)
        deleted = []

        for nb in notebooks:
            title = nb.get("title", "")
            if not title.startswith("Daily Digest "):
                continue
            created = nb.get("created_at", "")
            try:
                nb_date = datetime.fromisoformat(created)
            except (ValueError, TypeError):
                continue
            if nb_date < cutoff:
                nb_id = nb.get("id", "")
                _, err, rc = run_cmd(["delete", "-n", nb_id, "-y"])
                if rc == 0:
                    deleted.append(title)
                    log(f"deleted old notebook: {title}")
                else:
                    log(f"failed to delete {title}: {err}")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"deleted": deleted, "count": len(deleted)}).encode())

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        print("[notebooklm-bridge] " + str(args[0]), file=sys.stderr)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9090
    server = HTTPServer(("127.0.0.1", port), Handler)
    print("[notebooklm-bridge] listening on 127.0.0.1:" + str(port), file=sys.stderr)
    server.serve_forever()
