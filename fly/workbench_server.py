import base64
import hashlib
import hmac
import json
import os
import resource
import socket
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path, PurePosixPath

PORT = int(os.environ.get("PORT", "8080"))
TOKEN = os.environ.get("GGEN_WORKBENCH_TOKEN")
GGEN_DIGEST = os.environ.get(
    "GGEN_ECOSYSTEM_DIGEST",
    "sha256:917eb72a031da073f1d7e0c1295cda6023171275d79674b6303d5d817a3d4cb0",
)
MAX_REQUEST_BYTES = 6 * 1024 * 1024
MAX_FILES = 256
MAX_FILE_BYTES = 1024 * 1024
MAX_INPUT_BYTES = 5 * 1024 * 1024
MAX_ARTIFACT_BYTES = 8 * 1024 * 1024
MAX_STDIO_BYTES = 1024 * 1024
MAX_TIMEOUT_MS = 300_000
MAX_ARGS = 64
MAX_ARG_BYTES = 512
CHILD_FILE_LIMIT_BYTES = 32 * 1024 * 1024


class Refused(ValueError):
    def __init__(self, code, detail):
        super().__init__(detail)
        self.code = code
        self.detail = detail


def sha256_bytes(value):
    return hashlib.sha256(value).hexdigest()


def canonical_json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def safe_relative_path(raw):
    if not isinstance(raw, str) or not raw:
        raise Refused("INVALID_PATH", "file paths must be non-empty strings")

    path = PurePosixPath(raw)
    if path.is_absolute() or ".." in path.parts:
        raise Refused("UNSAFE_PATH", f"path escapes the ephemeral workspace: {raw}")

    normalized = str(path)
    if normalized in ("", "."):
        raise Refused("INVALID_PATH", f"invalid workspace path: {raw}")

    return normalized


def decode_file(value):
    if isinstance(value, str):
        return value.encode("utf-8")

    if isinstance(value, dict) and isinstance(value.get("content_base64"), str):
        try:
            return base64.b64decode(value["content_base64"], validate=True)
        except Exception as error:
            raise Refused("INVALID_BASE64", "content_base64 is not valid base64") from error

    raise Refused(
        "INVALID_FILE_CONTENT",
        "each file must be a UTF-8 string or {content_base64: <base64>}",
    )


def validate_request(payload):
    if not isinstance(payload, dict):
        raise Refused("INVALID_REQUEST", "request body must be a JSON object")

    args = payload.get("args", ["--version"])
    if not isinstance(args, list) or not args:
        raise Refused("INVALID_ARGS", "args must be a non-empty JSON array")
    if len(args) > MAX_ARGS:
        raise Refused("ARGS_LIMIT", f"at most {MAX_ARGS} ggen arguments are allowed")
    for arg in args:
        if not isinstance(arg, str) or not arg or len(arg.encode("utf-8")) > MAX_ARG_BYTES:
            raise Refused(
                "INVALID_ARG",
                f"each ggen argument must be 1..{MAX_ARG_BYTES} UTF-8 bytes",
            )
        if "\x00" in arg:
            raise Refused("INVALID_ARG", "NUL bytes are not allowed in arguments")

    files = payload.get("files", {})
    if not isinstance(files, dict):
        raise Refused("INVALID_FILES", "files must be a JSON object keyed by relative path")
    if len(files) > MAX_FILES:
        raise Refused("FILES_LIMIT", f"at most {MAX_FILES} input files are allowed")

    decoded = {}
    total = 0
    for raw_path, raw_value in files.items():
        path = safe_relative_path(raw_path)
        content = decode_file(raw_value)
        if len(content) > MAX_FILE_BYTES:
            raise Refused(
                "FILE_LIMIT",
                f"{path} exceeds the {MAX_FILE_BYTES}-byte per-file input limit",
            )
        total += len(content)
        if total > MAX_INPUT_BYTES:
            raise Refused(
                "INPUT_LIMIT",
                f"input bundle exceeds the {MAX_INPUT_BYTES}-byte aggregate limit",
            )
        decoded[path] = content

    timeout_ms = payload.get("timeout_ms", 120_000)
    if (
        isinstance(timeout_ms, bool)
        or not isinstance(timeout_ms, int)
        or timeout_ms < 1
        or timeout_ms > MAX_TIMEOUT_MS
    ):
        raise Refused(
            "INVALID_TIMEOUT",
            f"timeout_ms must be an integer from 1 through {MAX_TIMEOUT_MS}",
        )

    return {
        "args": args,
        "files": decoded,
        "timeout_ms": timeout_ms,
    }


def write_input_files(root, files):
    hashes = {}
    for rel_path, content in files.items():
        target = root / rel_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        hashes[rel_path] = sha256_bytes(content)
    return hashes


def collect_artifacts(root, input_hashes):
    artifacts = []
    emitted = 0

    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        rel = path.relative_to(root).as_posix()
        content = path.read_bytes()
        digest = sha256_bytes(content)

        if input_hashes.get(rel) == digest:
            continue

        artifact = {
            "path": rel,
            "sha256": digest,
            "size": len(content),
        }

        if emitted + len(content) <= MAX_ARTIFACT_BYTES:
            artifact["content_base64"] = base64.b64encode(content).decode("ascii")
            emitted += len(content)
        else:
            artifact["content_omitted"] = True

        artifacts.append(artifact)

    return artifacts


def child_limits():
    resource.setrlimit(resource.RLIMIT_FSIZE, (CHILD_FILE_LIMIT_BYTES, CHILD_FILE_LIMIT_BYTES))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def read_limited(path):
    size = path.stat().st_size
    with path.open("rb") as handle:
        content = handle.read(MAX_STDIO_BYTES)
    return content, size > MAX_STDIO_BYTES, size


def execute(payload):
    admitted = validate_request(payload)
    request_identity = {
        "args": admitted["args"],
        "files": {
            path: sha256_bytes(content) for path, content in sorted(admitted["files"].items())
        },
        "timeout_ms": admitted["timeout_ms"],
    }
    request_sha256 = sha256_bytes(canonical_json(request_identity))

    with tempfile.TemporaryDirectory(prefix="xaas-ggen-") as temp:
        root = Path(temp)
        input_hashes = write_input_files(root, admitted["files"])
        stdout_path = root / ".xaas-stdout"
        stderr_path = root / ".xaas-stderr"

        command = ["ggen", *admitted["args"]]
        try:
            with stdout_path.open("wb") as stdout_handle, stderr_path.open("wb") as stderr_handle:
                completed = subprocess.run(
                    command,
                    cwd=root,
                    stdin=subprocess.DEVNULL,
                    stdout=stdout_handle,
                    stderr=stderr_handle,
                    timeout=admitted["timeout_ms"] / 1000,
                    check=False,
                    shell=False,
                    preexec_fn=child_limits,
                )
        except subprocess.TimeoutExpired as error:
            raise Refused(
                "EXECUTION_TIMEOUT",
                f"ggen exceeded timeout_ms={admitted['timeout_ms']}",
            ) from error

        stdout, stdout_truncated, stdout_size = read_limited(stdout_path)
        stderr, stderr_truncated, stderr_size = read_limited(stderr_path)
        stdout_path.unlink(missing_ok=True)
        stderr_path.unlink(missing_ok=True)

        artifacts = collect_artifacts(root, input_hashes)
        artifact_manifest = [
            {"path": item["path"], "sha256": item["sha256"], "size": item["size"]}
            for item in artifacts
        ]

        receipt_body = {
            "protocol": "xaas.ggen-workbench.v1",
            "ggen_ecosystem_digest": GGEN_DIGEST,
            "request_sha256": request_sha256,
            "command": command,
            "exit_code": completed.returncode,
            "stdout_sha256": sha256_bytes(stdout),
            "stderr_sha256": sha256_bytes(stderr),
            "artifact_manifest": artifact_manifest,
        }
        receipt_sha256 = sha256_bytes(canonical_json(receipt_body))

        return {
            "standing": "ALIVE" if completed.returncode == 0 else "BUILD_BROKEN",
            "observed": True,
            "admitted": True,
            "executed": True,
            "changed": bool(artifact_manifest),
            "verified": completed.returncode == 0,
            "inferred": False,
            "refused": False,
            "blocked": False,
            "unsupported": False,
            "stdout": stdout.decode("utf-8", errors="replace"),
            "stdout_truncated": stdout_truncated,
            "stdout_size": stdout_size,
            "stderr": stderr.decode("utf-8", errors="replace"),
            "stderr_truncated": stderr_truncated,
            "stderr_size": stderr_size,
            "artifacts": artifacts,
            "receipt": {**receipt_body, "receipt_sha256": receipt_sha256},
        }


class IPv6ThreadingHTTPServer(ThreadingHTTPServer):
    address_family = socket.AF_INET6


class Handler(BaseHTTPRequestHandler):
    server_version = "xaas-ggen-workbench/1"

    def log_message(self, fmt, *args):
        print(
            json.dumps(
                {
                    "component": "xaas-ggen-workbench",
                    "remote": self.client_address[0],
                    "message": fmt % args,
                },
                separators=(",", ":"),
            ),
            flush=True,
        )

    def send_json(self, status, body):
        encoded = canonical_json(body)
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def authorized(self):
        if not TOKEN:
            self.send_json(
                503,
                {
                    "standing": "REFUSED[WORKBENCH_TOKEN_MISSING]",
                    "refused": True,
                    "detail": "GGEN_WORKBENCH_TOKEN is not configured on the worker",
                },
            )
            return False

        header = self.headers.get("authorization", "")
        prefix = "Bearer "
        supplied = header[len(prefix):] if header.startswith(prefix) else ""
        if not supplied or not hmac.compare_digest(supplied, TOKEN):
            self.send_json(
                401,
                {
                    "standing": "REFUSED[UNAUTHORIZED]",
                    "refused": True,
                    "detail": "missing or invalid workbench bearer token",
                },
            )
            return False
        return True

    def do_GET(self):
        if self.path != "/healthz":
            self.send_json(404, {"standing": "UNSUPPORTED", "detail": "route not found"})
            return

        try:
            completed = subprocess.run(
                ["ggen", "--version"],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                timeout=10,
                check=False,
                shell=False,
            )
        except Exception as error:
            self.send_json(
                503,
                {
                    "standing": "BUILD_BROKEN",
                    "executed": False,
                    "detail": str(error),
                    "ggen_ecosystem_digest": GGEN_DIGEST,
                },
            )
            return

        self.send_json(
            200 if completed.returncode == 0 else 503,
            {
                "standing": "ALIVE" if completed.returncode == 0 else "BUILD_BROKEN",
                "observed": True,
                "executed": True,
                "verified": completed.returncode == 0,
                "ggen_ecosystem_digest": GGEN_DIGEST,
                "ggen_version": completed.stdout.decode("utf-8", errors="replace").strip(),
                "exit_code": completed.returncode,
            },
        )

    def do_POST(self):
        if self.path != "/v1/ggen/run":
            self.send_json(404, {"standing": "UNSUPPORTED", "detail": "route not found"})
            return
        if not self.authorized():
            return

        try:
            length = int(self.headers.get("content-length", "0"))
        except ValueError:
            self.send_json(
                400,
                {
                    "standing": "REFUSED[INVALID_CONTENT_LENGTH]",
                    "refused": True,
                    "detail": "Content-Length must be an integer",
                },
            )
            return

        if length <= 0 or length > MAX_REQUEST_BYTES:
            self.send_json(
                413,
                {
                    "standing": "REFUSED[REQUEST_LIMIT]",
                    "refused": True,
                    "detail": f"request body must be 1..{MAX_REQUEST_BYTES} bytes",
                },
            )
            return

        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw)
            result = execute(payload)
            self.send_json(200, result)
        except Refused as error:
            status = 408 if error.code == "EXECUTION_TIMEOUT" else 422
            self.send_json(
                status,
                {
                    "standing": f"REFUSED[{error.code}]" if status != 408 else "BLOCKED",
                    "observed": True,
                    "admitted": error.code == "EXECUTION_TIMEOUT",
                    "executed": error.code == "EXECUTION_TIMEOUT",
                    "refused": status != 408,
                    "blocked": status == 408,
                    "detail": error.detail,
                },
            )
        except json.JSONDecodeError:
            self.send_json(
                400,
                {
                    "standing": "REFUSED[INVALID_JSON]",
                    "refused": True,
                    "detail": "request body is not valid JSON",
                },
            )
        except Exception as error:
            self.send_json(
                500,
                {
                    "standing": "BLOCKED",
                    "blocked": True,
                    "detail": f"worker failure: {type(error).__name__}: {error}",
                },
            )


if __name__ == "__main__":
    server = IPv6ThreadingHTTPServer(("::", PORT), Handler)
    print(
        json.dumps(
            {
                "component": "xaas-ggen-workbench",
                "standing": "UNKNOWN",
                "listen": f"[::]:{PORT}",
                "ggen_ecosystem_digest": GGEN_DIGEST,
            },
            separators=(",", ":"),
        ),
        flush=True,
    )
    server.serve_forever()
