#!/usr/bin/env bash
set -Eeuo pipefail

: "${ELECTRUM_VERSION:?ELECTRUM_VERSION is required}"
: "${OUTPUT_DIR:?OUTPUT_DIR is required}"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

source_dir="$work_dir/electrum"
venv_dir="$work_dir/venv"
stage_dir="$work_dir/stage"

git clone --depth 1 --branch "$ELECTRUM_VERSION" \
  https://github.com/spesmilo/electrum.git "$source_dir"

source_commit="$(git -C "$source_dir" rev-parse HEAD)"
python3 -m venv --copies "$venv_dir"

"$venv_dir/bin/python" -m pip install --upgrade pip setuptools wheel
"$venv_dir/bin/python" -m pip install --no-cache-dir "$source_dir[full]"

QT_QPA_PLATFORM=offscreen \
  "$venv_dir/bin/python" "$venv_dir/bin/electrum" --offline --version

mkdir -p "$stage_dir/opt/electrum" "$OUTPUT_DIR"
cp -a "$venv_dir" "$stage_dir/opt/electrum/venv"

cat > "$stage_dir/opt/electrum/electrum" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

export VIRTUAL_ENV=/opt/electrum/venv
export PATH=/opt/electrum/venv/bin:${PATH:-}
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"

exec /opt/electrum/venv/bin/python /opt/electrum/venv/bin/electrum "$@"
EOF
chmod 0755 "$stage_dir/opt/electrum/electrum"

printf '%s\n' "$source_commit" > "$stage_dir/opt/electrum/source-commit"
printf '%s\n' "$ELECTRUM_VERSION" > "$stage_dir/opt/electrum/version"

tar -C "$stage_dir" -czf \
  "$OUTPUT_DIR/electrum-${ELECTRUM_VERSION}-linux-arm64.tar.gz" opt/electrum
sha256sum "$OUTPUT_DIR/electrum-${ELECTRUM_VERSION}-linux-arm64.tar.gz" \
  > "$OUTPUT_DIR/electrum-${ELECTRUM_VERSION}-linux-arm64.tar.gz.sha256"

