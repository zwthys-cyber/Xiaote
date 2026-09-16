#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROTO_DIR="$SCRIPT_DIR/../Sources/TeslaBLEKeyKitCore/Protos"
OUT_DIR="$SCRIPT_DIR/../Sources/TeslaBLEKeyKitCore/Generated"

command -v protoc >/dev/null 2>&1 || { echo "protoc not found. Install with: brew install protobuf"; exit 1; }
command -v protoc-gen-swift >/dev/null 2>&1 || { echo "protoc-gen-swift not found. Install with: brew install swift-protobuf"; exit 1; }

mkdir -p "$OUT_DIR"

protoc \
  --proto_path="$PROTO_DIR" \
  --swift_out="$OUT_DIR" \
  --swift_opt=Visibility=Public \
  "$PROTO_DIR/car_server.proto" \
  "$PROTO_DIR/common.proto" \
  "$PROTO_DIR/errors.proto" \
  "$PROTO_DIR/keys.proto" \
  "$PROTO_DIR/managed_charging.proto" \
  "$PROTO_DIR/signatures.proto" \
  "$PROTO_DIR/universal_message.proto" \
  "$PROTO_DIR/vcsec.proto" \
  "$PROTO_DIR/vehicle.proto"

echo "Generated Swift protobuf files in $OUT_DIR"
