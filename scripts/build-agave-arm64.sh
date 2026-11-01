#!/usr/bin/env bash
set -Eeuo pipefail

: "${AGAVE_VERSION:?AGAVE_VERSION is required}"
: "${OUTPUT_DIR:?OUTPUT_DIR is required}"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

source_dir="$work_dir/agave"
stage_dir="$work_dir/stage"

git clone --depth 1 --branch "$AGAVE_VERSION" \
  https://github.com/anza-xyz/agave.git "$source_dir"

source_commit="$(git -C "$source_dir" rev-parse HEAD)"
cd "$source_dir"

cargo build --locked --release \
  --package solana-cli \
  --package solana-keygen \
  --package agave-validator \
  --package solana-gossip-cli \
  --package solana-faucet-cli

# The ledger tool is maintained in Agave's separate dev-bins workspace.
cargo build --locked --release \
  --manifest-path dev-bins/Cargo.toml \
  --package agave-ledger-tool

mkdir -p "$stage_dir/solana-release/bin" "$OUTPUT_DIR"

for binary in \
  solana \
  solana-keygen \
  agave-validator \
  agave-ledger-tool \
  solana-gossip \
  solana-faucet; do
  test -x "target/release/$binary"
  install -m 0755 "target/release/$binary" \
    "$stage_dir/solana-release/bin/$binary"
done

# Keep the names used by older image tooling available while exposing Agave's
# current validator name as the canonical executable.
ln -s agave-validator "$stage_dir/solana-release/bin/solana-validator"
ln -s agave-ledger-tool "$stage_dir/solana-release/bin/solana-ledger-tool"

printf '%s\n' "$source_commit" > "$stage_dir/solana-release/source-commit"
printf '%s\n' "$AGAVE_VERSION" > "$stage_dir/solana-release/version"

tar -C "$stage_dir" -czf \
  "$OUTPUT_DIR/agave-${AGAVE_VERSION#v}-linux-arm64.tar.gz" solana-release
sha256sum "$OUTPUT_DIR/agave-${AGAVE_VERSION#v}-linux-arm64.tar.gz" \
  > "$OUTPUT_DIR/agave-${AGAVE_VERSION#v}-linux-arm64.tar.gz.sha256"

