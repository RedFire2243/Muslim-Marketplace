#!/usr/bin/env python3
"""Private-network development relay; provider credentials stay on this Mac.

Run with --host <this Mac's private IPv4 address> to test on a phone on the
same network. This is deliberately not a public hosting service. Production
uses the authenticated transcribe-search Supabase Edge Function.
"""

import argparse
import base64
import binascii
from collections import deque
import io
import ipaddress
import json
import os
from pathlib import Path
import socket
import struct
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import wave


MAX_AUDIO_BYTES = 512044
MAX_BODY_BYTES = ((MAX_AUDIO_BYTES + 2) // 3) * 4 + 1024
MAX_PROVIDER_BYTES = 65536
DEFAULT_MODEL = "gemini-3.8-flash"
LOCAL_NETWORKS = tuple(
    ipaddress.ip_network(value)
    for value in ("127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
)
INSTRUCTIONS = """You transcribe short voice searches for a community marketplace in Central Jersey, where Muslims look for services, jobs, internships, mentors, collaborators, volunteering and local businesses.
Write down what the speaker asks for, in the language they speak, exactly as they say it. Leave out filler words (um, uh) and false starts. Do not answer, summarise, correct or add to the request.
Town names that may come up: New Brunswick, Piscataway, Edison, Highland Park, East Brunswick, North Brunswick, South Brunswick, Somerset, Princeton, Plainsboro, West Windsor, Hamilton, Trenton, Lawrenceville, Metuchen, Woodbridge, Sayreville, Old Bridge, Monroe, Bridgewater.
If the recording is silent, only noise, or you cannot make out the words, return an empty transcript. Never guess."""
SAFE_OUTCOMES = frozenset({
    "ok", "not_found", "request_not_allowed", "invalid_content_type",
    "content_length_required", "payload_too_large", "invalid_json", "invalid_audio",
    "audio_too_long", "voice_not_configured", "rate_limited", "upstream_error", "timeout",
})


def diagnostic(event, **details):
    """Emit operational metadata only; never stringify exceptions or payloads."""
    metadata = {"event": event}
    for name in ("bytes", "status"):
        value = details.get(name)
        if isinstance(value, int):
            metadata[name] = value
    if "outcome" in details:
        value = details["outcome"]
        metadata["outcome"] = value if value in SAFE_OUTCOMES else "error"
    if "kind" in details:
        # Exception class names contain no message, URL, key, or response body.
        metadata["kind"] = details["kind"]
    print(json.dumps(metadata, sort_keys=True), flush=True)


class RelayError(Exception):
    def __init__(self, code, status):
        super().__init__(code)
        self.code = code
        self.status = status


def is_local_address(host):
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return False
    return isinstance(address, ipaddress.IPv4Address) and any(
        address in network for network in LOCAL_NETWORKS
    )


def decode_audio(body):
    if not isinstance(body, dict) or not isinstance(body.get("audio"), str):
        raise RelayError("invalid_audio", 400)
    encoded = body["audio"]
    if len(encoded) > ((MAX_AUDIO_BYTES + 2) // 3) * 4:
        raise RelayError("audio_too_long", 413)
    try:
        audio = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError):
        raise RelayError("invalid_audio", 400) from None
    if len(audio) > MAX_AUDIO_BYTES:
        raise RelayError("audio_too_long", 413)
    if (
        len(audio) < 44
        or audio[:4] != b"RIFF"
        or audio[8:12] != b"WAVE"
        or struct.unpack_from("<I", audio, 4)[0] + 8 != len(audio)
    ):
        raise RelayError("invalid_audio", 400)
    try:
        with wave.open(io.BytesIO(audio), "rb") as recording:
            if (
                recording.getnchannels() != 1
                or recording.getsampwidth() != 2
                or recording.getframerate() != 16000
                or recording.getcomptype() != "NONE"
                or not 0 < recording.getnframes() <= 16 * 16000
            ):
                raise RelayError("invalid_audio", 400)
            if len(recording.readframes(recording.getnframes())) != recording.getnframes() * 2:
                raise RelayError("invalid_audio", 400)
    except (wave.Error, EOFError, struct.error):
        raise RelayError("invalid_audio", 400) from None
    return audio


class RateLimiter:
    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.requests = deque()
        self.lock = threading.Lock()

    def consume(self):
        now = self.clock()
        with self.lock:
            while self.requests and self.requests[0] <= now - 3600:
                self.requests.popleft()
            if len(self.requests) >= 100 or sum(t > now - 60 for t in self.requests) >= 6:
                return False
            self.requests.append(now)
            return True


class VoiceRelay:
    def __init__(self, api_key, model=DEFAULT_MODEL, opener=urlopen):
        self.api_key = api_key
        self.model = model
        self.opener = opener
        self.limiter = RateLimiter()
        self.inflight = threading.BoundedSemaphore(2)

    def transcribe(self, audio):
        if not self.api_key:
            raise RelayError("voice_not_configured", 503)
        if not self.inflight.acquire(blocking=False):
            raise RelayError("rate_limited", 429)
        try:
            if not self.limiter.consume():
                raise RelayError("rate_limited", 429)
            return self._request(audio)
        finally:
            self.inflight.release()

    def _request(self, audio):
        body = {
            "systemInstruction": {"parts": [{"text": INSTRUCTIONS}]},
            "contents": [{"role": "user", "parts": [{"inlineData": {
                "mimeType": "audio/wav", "data": base64.b64encode(audio).decode("ascii"),
            }}]}],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": {
                    "type": "OBJECT", "properties": {"transcript": {"type": "STRING"}},
                    "required": ["transcript"],
                },
            },
        }
        request = Request(
            "https://generativelanguage.googleapis.com/v1beta/models/"
            + self.model + ":generateContent",
            data=json.dumps(body).encode("utf-8"),
            headers={"Content-Type": "application/json", "x-goog-api-key": self.api_key},
            method="POST",
        )
        try:
            with self.opener(request, timeout=15) as response:
                raw = response.read(MAX_PROVIDER_BYTES + 1)
                if len(raw) > MAX_PROVIDER_BYTES:
                    diagnostic("provider_malformed_output", kind="oversized_body")
                    raise RelayError("upstream_error", 502)
            data = json.loads(raw)
            candidates = data.get("candidates", [])
            if not candidates:
                return ""
            parts = candidates[0].get("content", {}).get("parts", [])
            text = "".join(
                part["text"] for part in parts
                if isinstance(part, dict) and isinstance(part.get("text"), str)
                and part.get("thought") is not True
            ).strip()
            transcript = json.loads(text)
            if not isinstance(transcript, dict) or not isinstance(transcript.get("transcript"), str):
                diagnostic("provider_malformed_output", kind="invalid_transcript")
                raise RelayError("upstream_error", 502)
            return " ".join(transcript["transcript"].split())[:300].strip()
        except HTTPError as error:
            diagnostic("provider_http_error", status=error.code)
            if error.code == 429:
                raise RelayError("rate_limited", 429) from None
            raise RelayError("upstream_error", 502) from None
        except (TimeoutError, socket.timeout):
            diagnostic("provider_timeout")
            raise RelayError("timeout", 504) from None
        except URLError as error:
            reason = error.reason
            kind = type(reason).__name__ if isinstance(reason, BaseException) else type(error).__name__
            if isinstance(reason, (TimeoutError, socket.timeout)):
                diagnostic("provider_timeout", kind=kind)
                raise RelayError("timeout", 504) from None
            diagnostic("provider_network_error", kind=kind)
            raise RelayError("upstream_error", 502) from None
        except OSError as error:
            diagnostic("provider_network_error", kind=type(error).__name__)
            raise RelayError("upstream_error", 502) from None
        except (ValueError, KeyError, IndexError, TypeError, AttributeError, RecursionError) as error:
            diagnostic("provider_malformed_output", kind=type(error).__name__)
            raise RelayError("upstream_error", 502) from None


class VoiceServer(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 8

    def __init__(self, address, relay):
        if not is_local_address(address[0]):
            raise ValueError("Bind only to an exact loopback or private LAN IPv4 address.")
        self.relay = relay
        super().__init__(address, VoiceHandler)

    def verify_request(self, request, client_address):
        return is_local_address(client_address[0])


class VoiceHandler(BaseHTTPRequestHandler):
    server_version = "VoiceDevelopmentRelay"
    sys_version = ""

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, *_):
        # Requests can contain audio, credentials, or a transcript. Log none.
        pass

    def _json(self, body, status=200):
        if self.path != "/health":
            diagnostic("request_outcome", status=status, outcome=body.get("error", "ok"))
        encoded = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        if self.path != "/health":
            return self._json({"error": "not_found"}, 404)
        self._json({"ready": bool(self.server.relay.api_key)})

    def do_POST(self):
        if self.path != "/transcribe-search":
            return self._json({"error": "not_found"}, 404)
        # Browsers do not need this development endpoint; don't expose a
        # simple cross-origin form or fetch path to paid transcription.
        if self.headers.get("Origin") or self.headers.get("Transfer-Encoding"):
            return self._json({"error": "request_not_allowed"}, 403)
        if self.headers.get_content_type() != "application/json":
            return self._json({"error": "invalid_content_type"}, 415)
        lengths = self.headers.get_all("Content-Length", [])
        if len(lengths) != 1 or not lengths[0].isdigit():
            return self._json({"error": "content_length_required"}, 411)
        length = int(lengths[0])
        if length > MAX_BODY_BYTES:
            return self._json({"error": "payload_too_large"}, 413)
        try:
            raw = self.rfile.read(length)
            if len(raw) != length:
                raise RelayError("invalid_json", 400)
            try:
                body = json.loads(raw)
            except (ValueError, UnicodeError, RecursionError):
                raise RelayError("invalid_json", 400) from None
            audio = decode_audio(body)
            diagnostic("accepted_audio", bytes=len(audio))
            transcript = self.server.relay.transcribe(audio)
            self._json({"transcript": transcript})
        except RelayError as error:
            self._json({"error": error.code}, error.status)
        except (TimeoutError, OSError) as error:
            # A disconnected or stalled caller must not trigger a provider call.
            diagnostic("request_connection_error", kind=type(error).__name__)
            self.close_connection = True


def load_settings(config):
    data = {}
    if config:
        data = json.loads(Path(config).read_text())
        if not isinstance(data, dict):
            raise ValueError("Configuration must contain a JSON object.")
    api_key = os.environ.get("GEMINI_API_KEY", data.get("GEMINI_API_KEY", ""))
    model = os.environ.get("GEMINI_MODEL", data.get("GEMINI_MODEL", DEFAULT_MODEL))
    if not isinstance(api_key, str) or not api_key.strip():
        raise ValueError("Set GEMINI_API_KEY on the server or in its local config.")
    # Model is a path segment, never an arbitrary URL or query string.
    if not isinstance(model, str) or not model or any(
        char not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._" for char in model
    ):
        raise ValueError("GEMINI_MODEL must be a model identifier.")
    return api_key.strip(), model


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--config", help="Server-only JSON configuration; never bundled into the app")
    args = parser.parse_args()
    try:
        api_key, model = load_settings(args.config)
        server = VoiceServer((args.host, args.port), VoiceRelay(api_key, model))
    except (OSError, ValueError):
        parser.error("Unable to start: check the private bind address, port, and server configuration.")
    print(f"Local voice relay ready at http://{args.host}:{args.port}/transcribe-search", flush=True)
    print("Development only; keep this Mac and phone on the same trusted network.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
