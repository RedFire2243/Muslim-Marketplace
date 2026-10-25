import importlib.util
import io
import json
import plistlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[1] / "run_iphone.py"
SPEC = importlib.util.spec_from_file_location("run_iphone", MODULE_PATH)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class PublicConfigTests(unittest.TestCase):
    def test_direct_gemini_requires_explicit_command_line_opt_in(self):
        config = {"GEMINI_DIRECT_TEST": True, "GEMINI_API_KEY": "private-test-key"}
        with self.assertRaisesRegex(ValueError, "allow-direct-gemini-test"):
            runner.device_config(config)
        direct = runner.device_config(config, allow_direct=True)
        self.assertEqual(direct["GEMINI_API_KEY"], "private-test-key")
        self.assertTrue(direct["GEMINI_DIRECT_TEST"])
        self.assertEqual(direct["GEMINI_MODEL"], "gemini-3.8-flash")

    def test_direct_gemini_does_not_allow_other_provider_secrets(self):
        config = runner.device_config({
            "GEMINI_DIRECT_TEST": "true", "GEMINI_API_KEY": "private-test-key",
            "ANTHROPIC_API_KEY": "must-not-ship", "SUPABASE_SERVICE_ROLE_KEY": "must-not-ship",
        }, allow_direct=True)
        self.assertNotIn("must-not-ship", json.dumps(config))
        with self.assertRaises(ValueError):
            runner.device_config({"GEMINI_DIRECT_TEST": True}, allow_direct=True)

    def test_only_public_keys_reach_the_build(self):
        config = runner.public_config({
            "VOICE_SEARCH_URL": "  http://mac.local:8765/transcribe-search  ",
            "SUPABASE_URL": "https://project.example.test",
            "SUPABASE_PUBLISHABLE_KEY": "public-key",
            "AI_EXTRACTION": False,
            "GEMINI_API_KEY": "must-not-ship",
            "GEMINI_MODEL": "server-only",
            "ANTHROPIC_API_KEY": "also-must-not-ship",
            "SUPABASE_SERVICE_ROLE_KEY": "never-in-app",
        })
        self.assertEqual(set(config), {
            "VOICE_SEARCH_URL", "SUPABASE_URL",
            "SUPABASE_PUBLISHABLE_KEY", "AI_EXTRACTION",
        })
        self.assertEqual(config["VOICE_SEARCH_URL"],
                         "http://mac.local:8765/transcribe-search")
        self.assertNotIn("must-not-ship", json.dumps(config))

    def test_missing_or_invalid_endpoint_stops_before_building(self):
        for url in [None, "", "   ", "/transcribe-search", "https:",
                    "file:///transcribe-search", "https://", True,
                    "http://mac.local:bad/voice", "https://user:secret@host/voice"]:
            with self.subTest(url=url), self.assertRaisesRegex(ValueError, "VOICE_SEARCH_URL"):
                runner.public_config({"VOICE_SEARCH_URL": url})
        with self.assertRaises(ValueError):
            runner.public_config({})


class BundleVerificationTests(unittest.TestCase):
    def test_direct_bundle_has_both_key_and_google_endpoint(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "Runner.app"
            binary = bundle / "Frameworks/App.framework/App"
            binary.parent.mkdir(parents=True)
            config = {"GEMINI_DIRECT_TEST": True, "GEMINI_API_KEY": "private-test-key"}
            binary.write_bytes(b"private-test-key")
            with self.assertRaises(ValueError):
                runner.verify_device_bundle(bundle, config)
            binary.write_bytes(b"private-test-key generativelanguage.googleapis.com")
            runner.verify_device_bundle(bundle, config)

    def test_requires_full_endpoint_not_just_shared_hostname(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "Runner.app"
            binary = bundle / "Frameworks/App.framework/App"
            binary.parent.mkdir(parents=True)
            endpoint = "https://project.example.test/functions/v1/transcribe-search"
            binary.write_bytes(b"binary with project.example.test only")
            with self.assertRaisesRegex(ValueError, "Nothing was installed"):
                runner.verify_bundle(bundle, endpoint)
            binary.write_bytes(b"compiled data\x00" + endpoint.encode() + b"\x00")
            runner.verify_bundle(bundle, endpoint)

    def test_missing_bundle_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(ValueError):
                runner.verify_bundle(Path(temp), "https://voice.example.test/search")

    def test_invalid_config_never_invokes_flutter_or_installs(self):
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp) / "public.json"
            config.write_text("{}")
            with patch.object(runner, "run") as execute, patch("sys.stderr", io.StringIO()):
                self.assertEqual(runner.main(["--device", "test-phone",
                                              "--config", str(config)]), 1)
                execute.assert_not_called()

    def test_checks_snapshot_before_install_and_launch(self):
        endpoint = "http://mac.local:8765/transcribe-search"
        for include_endpoint in [False, True]:
            with self.subTest(valid_bundle=include_endpoint), tempfile.TemporaryDirectory() as temp:
                config = Path(temp) / "settings.json"
                config.write_text(json.dumps({"VOICE_SEARCH_URL": endpoint,
                                              "GEMINI_API_KEY": "must-not-ship"}))
                commands = []

                def execute(command, root):
                    commands.append(command)
                    if command[0] == "flutter":
                        config_flag = next(arg for arg in command
                                           if arg.startswith("--dart-define-from-file="))
                        build_config = json.loads(Path(config_flag.split("=", 1)[1]).read_text())
                        self.assertEqual(build_config, {"VOICE_SEARCH_URL": endpoint})

                def snapshot(source, destination, **kwargs):
                    binary = destination / "Frameworks/App.framework/App"
                    binary.parent.mkdir(parents=True)
                    binary.write_bytes(endpoint.encode() if include_endpoint else b"no config")
                    (destination / "Info.plist").write_bytes(
                        plistlib.dumps({"CFBundleIdentifier": "test.marketplace"}))

                with patch.object(runner, "run", execute), \
                        patch.object(runner.shutil, "copytree", snapshot), \
                        patch("sys.stdout", io.StringIO()), patch("sys.stderr", io.StringIO()):
                    result = runner.main(["--device", "test-phone", "--config", str(config),
                                          "--build-number", "7"])
                self.assertIn("--no-pub", commands[0])
                self.assertIn("--target=lib/main.dart", commands[0])
                self.assertIn("--build-number=7", commands[0])
                self.assertEqual(result, 0 if include_endpoint else 1)
                self.assertEqual(len(commands), 3 if include_endpoint else 1)
                if include_endpoint:
                    self.assertEqual(commands[1][:5],
                                     ["xcrun", "devicectl", "device", "install", "app"])
                    self.assertEqual(commands[2][-2:],
                                     ["--terminate-existing", "test.marketplace"])


if __name__ == "__main__":
    unittest.main()
