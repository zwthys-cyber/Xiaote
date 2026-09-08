#!/usr/bin/env python3
"""Create explicit CI devices; never assume a hosted image precreated them."""
import json
import os
import subprocess


def output(*arguments):
    return subprocess.check_output(arguments, text=True).strip()


def runtime():
    runtimes = json.loads(output("xcrun", "simctl", "list", "runtimes", "--json"))["runtimes"]
    return next((item for item in runtimes if item.get("isAvailable")
                 and item["identifier"].endswith("iOS-26-2")), None)


if runtime() is None:
    # The macos-26 hosted runner uses Apple Silicon; fetch its native runtime.
    subprocess.run(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", "26.2",
                    "-architectureVariant", "arm64"], check=True)

selected = runtime()
if selected is None:
    raise SystemExit("The required iOS 26.2 simulator runtime is not available.")

devices = [
    ("UI_PHONE_ID", "Xiaote UI", "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"),
    ("UI_SMALL_PHONE_ID", "Xiaote Compact UI", "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation"),
]
with open(os.environ["GITHUB_ENV"], "a") as environment:
    for key, name, device_type in devices:
        identifier = output("xcrun", "simctl", "create", name, device_type, selected["identifier"])
        print(f"{key}={identifier}", file=environment)
        print(f"Prepared {name}: {identifier} ({selected['name']})")
