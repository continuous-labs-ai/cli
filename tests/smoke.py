import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import threading
import unittest
from email.parser import BytesParser
from email.policy import default
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


BINARY = str(Path(sys.argv.pop(1)).resolve())
COMMANDS = {
    "list-simulations": "simulations list",
    "create-simulation": "simulations create",
    "delete-simulation": "simulations delete",
    "get-simulation": "simulations get",
    "fork-simulation": "simulations fork",
    "start-simulation": "simulations start",
    "list-simulation-steps": "simulations list-simulation-steps",
    "stop-simulation": "simulations stop",
    "mint-simulation-token": "simulations mint-simulation-token",
    "list-simulators": "simulators list",
    "build-simulator": "simulators build",
    "delete-simulator": "simulators delete",
    "get-simulator": "simulators get",
    "cancel-simulator-build": "simulators cancel-simulator-build",
    "list-worlds": "worlds list",
    "build-world": "worlds build",
    "delete-world": "worlds delete",
    "get-world": "worlds get",
    "cancel-world-build": "worlds cancel-world-build",
    "start-world": "worlds start",
    "stop-world": "worlds stop",
}
SIMULATION = {
    "id": "sim_fixture",
    "name": "fixture",
    "simulator_id": "smr_fixture",
    "parent_id": None,
    "endpoint": "https://example.invalid",
    "status": "stopped",
    "created_at": "2026-09-08T00:00:00Z",
}


class Handler(BaseHTTPRequestHandler):
    def handle_request(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self.server.requests.append((self.command, self.path, self.headers, body))
        self.send_response(self.server.status)
        self.send_header("Content-Type", self.server.content_type)
        self.end_headers()
        self.wfile.write(json.dumps(self.server.response).encode())

    do_GET = handle_request
    do_POST = handle_request
    do_DELETE = handle_request

    def log_message(self, *args):
        pass


class CLISmoke(unittest.TestCase):
    def setUp(self):
        self.config = tempfile.TemporaryDirectory()
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.requests = []
        self.server.status = 200
        self.server.content_type = "application/json"
        self.server.response = {"simulations": [SIMULATION], "next_cursor": None}
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.url = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.config.cleanup()

    def run_cli(self, *args, success=True, input=None, extra_env=None):
        result = subprocess.run(
            [BINARY, "--agent-mode=false", "--server-url", self.url, *args],
            env={
                "PATH": os.environ["PATH"],
                "XDG_CONFIG_HOME": self.config.name,
                "CONTINUOUS_API_KEY_AUTH": "Bearer fixture-secret",
                "NO_COLOR": "1",
                **(extra_env or {}),
            },
            input=input,
            capture_output=True,
            text=True,
            timeout=15,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_public_command_inventory(self):
        source = Path(".speakeasy/out.openapi.yaml").read_text()
        operations = re.findall(r"^\s+operationId: (\S+)$", source, re.MULTILINE)
        self.assertEqual(set(operations), set(COMMANDS))
        self.assertEqual(len(operations), 21)
        for command in COMMANDS.values():
            with self.subTest(command=command):
                result = self.run_cli(*command.split(), "--help")
                self.assertIn("continuous " + command, result.stdout)
        self.assertEqual(self.server.requests, [])

    def test_json_auth_base_url_query_and_nulls(self):
        result = self.run_cli(
            "simulations", "list", "--output-format", "json", "--limit", "2",
            "--cursor", "next+/=", "--status", "stopped",
        )
        self.assertEqual(json.loads(result.stdout), self.server.response)
        method, path, headers, _ = self.server.requests[0]
        self.assertEqual(method, "GET")
        from urllib.parse import parse_qs, urlsplit
        self.assertEqual(urlsplit(path).path, "/v1/simulations")
        self.assertEqual(parse_qs(urlsplit(path).query), {
            "limit": ["2"], "cursor": ["next+/="], "status": ["stopped"],
        })
        self.assertEqual(headers["Authorization"], "Bearer fixture-secret")

    def test_pretty_output_accepts_nullable_fields(self):
        result = self.run_cli("simulations", "list", "--output-format", "pretty")
        self.assertIn("sim_fixture", result.stdout)

    def test_fork_preserves_explicit_zero(self):
        self.server.status = 201
        self.server.response = {"simulation": SIMULATION}
        self.run_cli("simulations", "fork", "--id", "sim_fixture",
                     "--at-step", "0", "--output-format", "json")
        method, path, _, body = self.server.requests[0]
        self.assertEqual((method, path), ("POST", "/v1/simulations/sim_fixture/fork"))
        self.assertEqual(json.loads(body)["at_step"], 0)

    def test_json_body_from_stdin(self):
        self.server.status = 201
        self.server.response = {"simulation": SIMULATION}
        self.run_cli("simulations", "create", "--output-format", "json",
                     input='{"simulator_id":"smr_fixture","name":"from-stdin"}')
        self.assertEqual(json.loads(self.server.requests[0][3]), {
            "simulator_id": "smr_fixture", "name": "from-stdin",
        })

    def test_multipart_spec_upload(self):
        payload = b"openapi: 3.1.0\ninfo:\n  title: Fixture\n  version: v1\npaths: {}\n"
        spec = Path(self.config.name) / "fixture.yaml"
        spec.write_bytes(payload)
        self.server.status = 202
        self.server.response = {"id": "smr_fixture", "status": "building"}
        self.run_cli("simulators", "build", "--request",
                     '{"name":"fixture","builder":"claude","spec_kind":"openapi"}',
                     "--spec", str(spec), "--output-format", "json")
        method, path, headers, body = self.server.requests[0]
        self.assertEqual((method, path), ("POST", "/v1/simulators"))
        message = BytesParser(policy=default).parsebytes(
            ("Content-Type: " + headers["Content-Type"] + "\r\n\r\n").encode() + body
        )
        parts = {p.get_param("name", header="content-disposition"): p
                 for p in message.iter_parts()}
        self.assertEqual(parts["spec"].get_payload(decode=True), payload)
        self.assertEqual(parts["spec"].get_filename(), "fixture.yaml")
        request = json.loads(parts["request"].get_payload(decode=True))
        self.assertEqual(request["name"], "fixture")
        self.assertEqual(request["builder"], "claude")

    def test_api_error_has_nonzero_exit(self):
        self.server.status = 401
        self.server.content_type = "application/problem+json"
        self.server.response = {"code": "unauthorized",
                                "detail": "Invalid API key"}
        result = self.run_cli("simulations", "list", "--output-format", "json", success=False)
        self.assertIn("Invalid API key", result.stderr)
        self.assertIn("unauthorized", result.stderr)
        self.assertNotIn("fixture-secret", result.stderr)

    def test_json_error_is_one_machine_readable_document(self):
        self.server.status = 401
        self.server.content_type = "application/problem+json"
        self.server.response = {"code": "unauthorized", "detail": "Invalid API key"}
        result = self.run_cli("simulations", "list", "--output-format", "json", success=False)
        json.loads(result.stderr)

    def test_agent_mode_false_overrides_agent_environment(self):
        baseline = self.run_cli("simulations", "list")
        detected = self.run_cli("simulations", "list", extra_env={"CLAUDE_CODE": "1"})
        self.assertEqual(detected.stdout, baseline.stdout)

    def test_build_help_example_sends_its_named_request(self):
        help_text = self.run_cli("simulators", "build", "--help").stdout
        example = re.search(r"^\s*(continuous simulators build .+)$", help_text, re.MULTILINE)
        self.assertIsNotNone(example)
        self.server.status = 202
        self.server.response = {"id": "smr_fixture", "status": "building"}
        self.run_cli(*shlex.split(example[1])[1:], "--output-format", "json")
        _, _, headers, body = self.server.requests[0]
        message = BytesParser(policy=default).parsebytes(
            ("Content-Type: " + headers["Content-Type"] + "\r\n\r\n").encode() + body
        )
        request_part = next(p for p in message.iter_parts()
                            if p.get_param("name", header="content-disposition") == "request")
        request = json.loads(request_part.get_payload(decode=True))
        self.assertEqual(request.get("name"), "billing-api")


if __name__ == "__main__":
    unittest.main()
