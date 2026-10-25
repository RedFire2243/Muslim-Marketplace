#!/usr/bin/env python3
"""Build with public iPhone config, verify voice settings, then install/launch."""

import argparse
import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlsplit

PUBLIC_CONFIG_KEYS = frozenset({
    "SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY",
    "AI_EXTRACTION", "VOICE_SEARCH_URL",
})


def public_config(config):
    """Discard provider secrets and require a usable public voice endpoint."""
    if not isinstance(config, dict):
        raise ValueError("The app config must be a JSON object.")
    sanitized = {key: value for key, value in config.items()
                 if key in PUBLIC_CONFIG_KEYS}
    voice_url = sanitized.get("VOICE_SEARCH_URL", "")
    if not isinstance(voice_url, str):
        raise ValueError("VOICE_SEARCH_URL must be a full http(s) endpoint.")
    voice_url = voice_url.strip()
    try:
        parsed = urlsplit(voice_url)
        valid = (parsed.scheme in {"http", "https"} and parsed.hostname
                 and not parsed.username and not parsed.password
                 and not any(char.isspace() for char in voice_url))
        parsed.port  # Reject invalid ports before starting a build.
    except ValueError:
        valid = False
    if not valid:
        raise ValueError(
            "Set VOICE_SEARCH_URL to a full http(s) transcription endpoint "
            "in the file passed to --config before installing."
        )
    if any(not isinstance(value, (str, bool)) for value in sanitized.values()):
        raise ValueError("Public config values must be strings or booleans.")
    sanitized["VOICE_SEARCH_URL"] = voice_url
    return sanitized


def verify_bundle(bundle, voice_url):
    """Fail closed if the built Dart binary lacks the configured endpoint."""
    binary = Path(bundle) / "Frameworks/App.framework/App"
    if not binary.is_file() or voice_url.encode("utf-8") not in binary.read_bytes():
        raise ValueError(
            "The built app does not contain the configured VOICE_SEARCH_URL. "
            "Nothing was installed. Stop other Flutter builds and rerun this script."
        )


def device_config(config, allow_direct=False):
    """Keep direct credentials behind both the config and command-line opt-ins."""
    if not isinstance(config, dict):
        raise ValueError("The app config must be a JSON object.")
    direct = config.get("GEMINI_DIRECT_TEST") in (True, "true")
    if not direct:
        return public_config(config)
    if not allow_direct:
        raise ValueError("A direct Gemini test requires --allow-direct-gemini-test.")
    api_key = config.get("GEMINI_API_KEY", "")
    model = config.get("GEMINI_MODEL", "gemini-3.8-flash")
    if not isinstance(api_key, str) or not api_key.strip():
        raise ValueError("The direct Gemini test needs a configured GEMINI_API_KEY.")
    if not isinstance(model, str) or not re.fullmatch(r"[A-Za-z0-9._-]+", model):
        raise ValueError("GEMINI_MODEL must be a model identifier.")
    result = {key: value for key, value in config.items() if key in PUBLIC_CONFIG_KEYS}
    result.update(GEMINI_DIRECT_TEST=True, GEMINI_API_KEY=api_key.strip(), GEMINI_MODEL=model)
    if any(not isinstance(value, (str, bool)) for value in result.values()):
        raise ValueError("App config values must be strings or booleans.")
    return result


def verify_device_bundle(bundle, config):
    if not config.get("GEMINI_DIRECT_TEST"):
        return verify_bundle(bundle, config["VOICE_SEARCH_URL"])
    binary = Path(bundle) / "Frameworks/App.framework/App"
    data = binary.read_bytes() if binary.is_file() else b""
    if (config["GEMINI_API_KEY"].encode() not in data
            or b"generativelanguage.googleapis.com" not in data):
        raise ValueError("The app lacks its direct Gemini test configuration; nothing was installed.")


def run(command, root):
    subprocess.run(command, cwd=root, check=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="iPhone device ID or name")
    parser.add_argument("--config", required=True, type=Path,
                        help="JSON file with public connection settings")
    parser.add_argument("--build-number", help="Optional iOS build number")
    parser.add_argument("--allow-direct-gemini-test", action="store_true",
                        help="Explicitly allow the provider key in this private test app")
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    config_path = args.config if args.config.is_absolute() else root / args.config
    try:
        config = device_config(json.loads(config_path.read_text()), args.allow_direct_gemini_test)
        with tempfile.TemporaryDirectory(prefix="marketplace-iphone-") as temp:
            temp_root = Path(temp)
            build_config = temp_root / "public-config.json"
            build_config.write_text(json.dumps(config))
            command = ["flutter", "build", "ios", "--release", "--no-pub", "--target=lib/main.dart",
                       f"--dart-define-from-file={build_config}"]
            if args.build_number is not None:
                command.append(f"--build-number={args.build_number}")
            print("Building private direct-Gemini test app…" if config.get("GEMINI_DIRECT_TEST")
                  else "Building iPhone app with public voice configuration…", flush=True)
            run(command, root)
            # Install a private copy so another build cannot replace a
            # verified bundle between the check and the device installation.
            bundle = temp_root / "Runner.app"
            shutil.copytree(root / "build/ios/iphoneos/Runner.app", bundle,
                            symlinks=True)
            verify_device_bundle(bundle, config)
            with (bundle / "Info.plist").open("rb") as info:
                bundle_id = plistlib.load(info).get("CFBundleIdentifier")
            if not isinstance(bundle_id, str) or not bundle_id:
                raise ValueError("The built app has no bundle identifier; nothing was installed.")
            print("Verified voice configuration. Installing and launching…", flush=True)
            run(["xcrun", "devicectl", "device", "install", "app",
                 "--device", args.device, str(bundle)], root)
            run(["xcrun", "devicectl", "device", "process", "launch",
                 "--device", args.device, "--terminate-existing", bundle_id], root)
        return 0
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f"iPhone setup stopped: {error}", file=sys.stderr)
    except subprocess.CalledProcessError as error:
        print(f"iPhone setup stopped: command exited with {error.returncode}.",
              file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
