import base64
from contextlib import redirect_stdout
from email.message import Message
import importlib.util
import io
import json
from pathlib import Path
import socket
import ssl
from types import SimpleNamespace
import unittest
from unittest.mock import Mock
from urllib.error import HTTPError, URLError
import wave


MODULE_PATH = Path(__file__).resolve().parents[1] / "voice_search_server.py"
SPEC = importlib.util.spec_from_file_location("voice_search_server", MODULE_PATH)
relay = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(relay)


def wav(*, rate=16000, channels=1, width=2, frames=1600):
    output = io.BytesIO()
    with wave.open(output, "wb") as recording:
        recording.setnchannels(channels)
        recording.setsampwidth(width)
        recording.setframerate(rate)
        recording.writeframes(b"\x00" * frames * channels * width)
    return output.getvalue()


def body(audio=None):
    return {"audio": base64.b64encode(audio if audio is not None else wav()).decode("ascii")}


def provider_response(transcript="a robotics mentor"):
    return {
        "candidates": [{"content": {"parts": [
            {"text": "private reasoning", "thought": True},
            {"text": json.dumps({"transcript": transcript})},
        ]}}],
    }


class AudioValidationTests(unittest.TestCase):
    def test_accepts_native_wav_and_full_16_second_buffer(self):
        for audio in (wav(), wav(frames=16 * 16000)):
            self.assertEqual(relay.decode_audio(body(audio)), audio)

    def test_rejects_wrong_format_or_truncated_wav(self):
        malformed = [
            wav(rate=44100), wav(channels=2), wav(width=1), wav(frames=0),
            wav()[:-2], b"not audio", wav() + b"trailing",
        ]
        for audio in malformed:
            with self.subTest(length=len(audio)):
                with self.assertRaises(relay.RelayError) as error:
                    relay.decode_audio(body(audio))
                self.assertEqual(error.exception.status, 400)

    def test_rejects_non_base64_and_wrong_payload_shapes(self):
        for value in [None, [], {}, {"audio": 42}, {"audio": "%%%"}, {"audio": "é"}]:
            with self.subTest(value=value):
                with self.assertRaises(relay.RelayError):
                    relay.decode_audio(value)

    def test_rejects_long_audio_before_provider(self):
        with self.assertRaises(relay.RelayError) as error:
            relay.decode_audio(body(wav(frames=16 * 16000 + 1)))
        self.assertEqual(error.exception.status, 413)


class PolicyTests(unittest.TestCase):
    def test_only_exact_private_and_loopback_addresses(self):
        for address in ("127.0.0.1", "10.1.2.3", "172.16.1.2", "192.168.4.53"):
            self.assertTrue(relay.is_local_address(address))
        for address in ("0.0.0.0", "8.8.8.8", "192.0.2.1", "localhost", "::"):
            self.assertFalse(relay.is_local_address(address))

    def test_public_bind_is_rejected_without_opening_socket(self):
        for address in ("0.0.0.0", "8.8.8.8"):
            with self.assertRaises(ValueError):
                relay.VoiceServer((address, 8765), relay.VoiceRelay("test"))

    def test_minute_and_hour_limits_share_one_global_budget(self):
        now = [0.0]
        limiter = relay.RateLimiter(clock=lambda: now[0])
        self.assertTrue(all(limiter.consume() for _ in range(6)))
        self.assertFalse(limiter.consume())
        now[0] = 60.0
        self.assertTrue(limiter.consume())
        # Spread requests across minutes, reaching the hourly budget.
        accepted = 7
        while accepted < 100:
            now[0] += 60
            for _ in range(min(6, 100 - accepted)):
                self.assertTrue(limiter.consume())
                accepted += 1
        now[0] += 60
        self.assertFalse(limiter.consume())
        now[0] = 3600
        self.assertTrue(limiter.consume())


class ProviderTests(unittest.TestCase):
    def opener(self, payload):
        response = Mock()
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=None)
        response.read.return_value = json.dumps(payload).encode()
        return Mock(return_value=response)

    def test_sends_key_in_header_only_and_returns_clean_transcript(self):
        opener = self.opener(provider_response("  a\n robotics   mentor  "))
        service = relay.VoiceRelay("server-only-key", opener=opener)
        self.assertEqual(service.transcribe(wav()), "a robotics mentor")
        request = opener.call_args.args[0]
        self.assertEqual(opener.call_args.kwargs["timeout"], 15)
        self.assertEqual(request.get_header("X-goog-api-key"), "server-only-key")
        self.assertNotIn("server-only-key", request.full_url)
        self.assertNotIn("server-only-key", request.data.decode())
        request_body = json.loads(request.data)
        self.assertEqual(request_body["contents"][0]["parts"][0]["inlineData"]["mimeType"], "audio/wav")

    def test_empty_candidate_and_length_limit(self):
        self.assertEqual(relay.VoiceRelay("key", opener=self.opener({"candidates": []})).transcribe(wav()), "")
        service = relay.VoiceRelay("key", opener=self.opener(provider_response("x" * 400)))
        self.assertEqual(len(service.transcribe(wav())), 300)

    def test_malformed_provider_output_fails_closed(self):
        for value in ([], {"candidates": [{}]}, {"candidates": [{"content": {"parts": [{"text": "plain garbage"}]}}]}):
            service = relay.VoiceRelay("key", opener=self.opener(value))
            with self.assertRaises(relay.RelayError) as error:
                service.transcribe(wav())
            self.assertEqual(error.exception.code, "upstream_error")

    def test_errors_do_not_echo_provider_details_or_key(self):
        for exception, code, status in (
            (HTTPError("https://example.test", 403, "server-only-key", {}, None), "upstream_error", 502),
            (HTTPError("https://example.test", 429, "rate limit details", {}, None), "rate_limited", 429),
            (socket.timeout("private details"), "timeout", 504),
            (URLError("private details"), "upstream_error", 502),
        ):
            with self.subTest(code=code):
                service = relay.VoiceRelay("server-only-key", opener=Mock(side_effect=exception))
                with self.assertRaises(relay.RelayError) as error:
                    service.transcribe(wav())
                self.assertEqual((str(error.exception), error.exception.status), (code, status))

    def test_http_diagnostics_include_only_status_and_no_provider_body(self):
        output = io.StringIO()
        error_body = b"private-provider-error-with-server-only-key"
        provider_error = HTTPError(
            "https://provider.invalid?key=server-only-key", 403,
            "private-provider-reason", {}, io.BytesIO(error_body),
        )
        service = relay.VoiceRelay("server-only-key", opener=Mock(side_effect=provider_error))
        with redirect_stdout(output), self.assertRaises(relay.RelayError):
            service.transcribe(wav())
        self.assertEqual(json.loads(output.getvalue()), {"event": "provider_http_error", "status": 403})
        for secret in ("server-only-key", "private-provider", "provider.invalid"):
            self.assertNotIn(secret, output.getvalue())

    def test_network_diagnostics_show_error_class_without_message(self):
        output = io.StringIO()
        service = relay.VoiceRelay("key", opener=Mock(side_effect=URLError(
            ssl.SSLCertVerificationError("sensitive certificate or URL details"),
        )))
        with redirect_stdout(output), self.assertRaises(relay.RelayError):
            service.transcribe(wav())
        self.assertEqual(json.loads(output.getvalue()), {
            "event": "provider_network_error", "kind": "SSLCertVerificationError",
        })
        self.assertNotIn("sensitive", output.getvalue())

    def test_wrapped_network_timeout_is_reported_as_timeout(self):
        output = io.StringIO()
        service = relay.VoiceRelay("key", opener=Mock(side_effect=URLError(
            socket.timeout("private connection details"),
        )))
        with redirect_stdout(output), self.assertRaises(relay.RelayError) as error:
            service.transcribe(wav())
        self.assertEqual(error.exception.status, 504)
        self.assertEqual(json.loads(output.getvalue())["event"], "provider_timeout")
        self.assertNotIn("private connection", output.getvalue())

    def test_provider_connection_reset_is_not_mistaken_for_phone_disconnect(self):
        output = io.StringIO()
        service = relay.VoiceRelay("key", opener=Mock(side_effect=ConnectionResetError(
            "private connection details",
        )))
        with redirect_stdout(output), self.assertRaises(relay.RelayError) as error:
            service.transcribe(wav())
        self.assertEqual(error.exception.status, 502)
        self.assertEqual(json.loads(output.getvalue()), {
            "event": "provider_network_error", "kind": "ConnectionResetError",
        })
        self.assertNotIn("private connection", output.getvalue())

    def test_malformed_output_diagnostics_do_not_log_text(self):
        output = io.StringIO()
        service = relay.VoiceRelay("key", opener=self.opener({"candidates": [{"content": {
            "parts": [{"text": "private-malformed-transcript"}],
        }}]}))
        with redirect_stdout(output), self.assertRaises(relay.RelayError):
            service.transcribe(wav())
        self.assertEqual(json.loads(output.getvalue())["event"], "provider_malformed_output")
        self.assertNotIn("private-malformed", output.getvalue())

    def test_global_rate_limit_prevents_provider_calls(self):
        opener = self.opener(provider_response())
        service = relay.VoiceRelay("key", opener=opener)
        for _ in range(6):
            service.transcribe(wav())
        with self.assertRaises(relay.RelayError) as error:
            service.transcribe(wav())
        self.assertEqual(error.exception.status, 429)
        self.assertEqual(opener.call_count, 6)

    def test_two_request_concurrency_limit(self):
        opener = self.opener(provider_response())
        service = relay.VoiceRelay("key", opener=opener)
        service.inflight.acquire()
        service.inflight.acquire()
        with self.assertRaises(relay.RelayError) as error:
            service.transcribe(wav())
        self.assertEqual(error.exception.status, 429)
        opener.assert_not_called()


class HandlerTests(unittest.TestCase):
    def handler(self, raw=None, extra_headers=None, path="/transcribe-search"):
        raw = json.dumps(body()).encode() if raw is None else raw
        handler = object.__new__(relay.VoiceHandler)
        handler.path = path
        handler.headers = Message()
        handler.headers["Content-Type"] = "application/json"
        handler.headers["Content-Length"] = str(len(raw))
        for name, value in (extra_headers or {}).items():
            if name in handler.headers:
                del handler.headers[name]
            handler.headers[name] = value
        handler.rfile = io.BytesIO(raw)
        handler.server = SimpleNamespace(relay=Mock(api_key="hidden", transcribe=Mock(return_value="a mentor")))
        handler._json = Mock()
        return handler

    def test_valid_native_request(self):
        handler = self.handler()
        handler.do_POST()
        handler._json.assert_called_once_with({"transcript": "a mentor"})

    def test_accepted_audio_diagnostic_contains_only_byte_count(self):
        output = io.StringIO()
        handler = self.handler()
        with redirect_stdout(output):
            handler.do_POST()
        self.assertEqual(json.loads(output.getvalue()), {
            "event": "accepted_audio", "bytes": len(wav()),
        })
        self.assertNotIn("a mentor", output.getvalue())

    def test_final_outcome_diagnostic_excludes_transcript(self):
        output = io.StringIO()
        handler = self.handler()
        handler.wfile = io.BytesIO()
        handler.send_response = Mock()
        handler.send_header = Mock()
        handler.end_headers = Mock()
        with redirect_stdout(output):
            relay.VoiceHandler._json(handler, {"transcript": "private-search-words"})
        self.assertEqual(json.loads(output.getvalue()), {
            "event": "request_outcome", "status": 200, "outcome": "ok",
        })
        self.assertNotIn("private-search-words", output.getvalue())

    def test_final_outcome_diagnostic_logs_only_known_codes(self):
        output = io.StringIO()
        handler = self.handler()
        handler.wfile = io.BytesIO()
        handler.send_response = Mock()
        handler.send_header = Mock()
        handler.end_headers = Mock()
        with redirect_stdout(output):
            relay.VoiceHandler._json(handler, {"error": "upstream_error"}, 502)
            relay.VoiceHandler._json(handler, {"error": "unknown-private-provider-body"}, 502)
        events = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual([event["outcome"] for event in events], ["upstream_error", "error"])
        self.assertNotIn("private-provider", output.getvalue())

    def test_request_guards_never_call_provider(self):
        for kwargs, status in (
            ({"path": "/wrong"}, 404),
            ({"extra_headers": {"Origin": "https://untrusted.example"}}, 403),
            ({"extra_headers": {"Transfer-Encoding": "chunked"}}, 403),
            ({"extra_headers": {"Content-Type": "text/plain"}}, 415),
            ({"extra_headers": {"Content-Length": str(relay.MAX_BODY_BYTES + 1)}}, 413),
            ({"extra_headers": {"Content-Length": "nope"}}, 411),
            ({"raw": b"{"}, 400),
            ({"raw": b'{}'}, 400),
        ):
            with self.subTest(kwargs=kwargs):
                handler = self.handler(**kwargs)
                handler.do_POST()
                self.assertEqual(handler._json.call_args.args[1], status)
                handler.server.relay.transcribe.assert_not_called()

    def test_health_contains_no_credentials(self):
        handler = self.handler(path="/health")
        handler.do_GET()
        handler._json.assert_called_once_with({"ready": True})


if __name__ == "__main__":
    unittest.main()
