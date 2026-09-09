#!/usr/bin/env python3
"""Create explicit CI devices; never assume a hosted image precreated them."""
import json
import os
import subprocess


def output(*arguments):
    return subprocess.check_output(arguments, text=True).strip()


def runtime():
    runtimes = json.loads(output("xcrun", "simctl", "list", "runtimes", "--json"))["runtimes"]
    available = [item for item in runtimes if item.get("isAvailable")
                 and item["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]
    return max(available, key=lambda item: tuple(map(int, item["version"].split("."))),
               default=None)


if runtime() is None:
    subprocess.run(["xcodebuild", "-downloadPlatform", "iOS"], check=True)

selected = runtime()
if selected is None:
    raise SystemExit("No available iOS simulator runtime was found.")

devices = [
    ("UI_PHONE_ID", "Xiaote UI", "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"),
    ("UI_SMALL_PHONE_ID", "Xiaote Compact UI", "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation"),
]
existing_devices = json.loads(output("xcrun", "simctl", "list", "devices", "--json"))["devices"]
runtime_devices = existing_devices.get(selected["identifier"], [])
with open(os.environ["GITHUB_ENV"], "a") as environment:
    for key, name, device_type in devices:
        existing = next((item for item in runtime_devices
                         if item.get("isAvailable") and item["name"] == name), None)
        identifier = (existing["udid"] if existing else
                      output("xcrun", "simctl", "create", name, device_type,
                             selected["identifier"]))
        print(f"{key}={identifier}", file=environment)
        print(f"Prepared {name}: {identifier} ({selected['name']})")
