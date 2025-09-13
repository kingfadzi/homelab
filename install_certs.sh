#!/usr/bin/env bash
set -Eeuo pipefail

# ---------------------------------------------
# Install TLS certs from Namecheap zip (overridable)
# Warns if using defaults
# ---------------------------------------------

# --- defaults
ZIP_PATH="./butterflycluster_com.zip"
KEY_PATH="./butterflycluster_com.key"
HOSTNAME="charon.butterflycluster.com"

die() { echo "❌ $*" >&2; exit 1; }
ok()  { echo "✅ $*"; }
info(){ echo "— $*"; }

# --- parse CLI overrides
while [[ $# -gt 0 ]]; do
  case "$1" in
    --zip)      ZIP_PATH="${2:-}"; shift 2;;
    --key)      KEY_PATH="${2:-}"; shift 2;;
    --hostname) HOSTNAME="${2:-}"; shift 2;;
    -h|--help)
      echo "Usage: $0 [--zip path] [--key path] [--hostname fqdn]"
      echo "Defaults:"
      echo "  --zip      $ZIP_PATH"
      echo "  --key      $KEY_PATH"
      echo "  --hostname $HOSTNAME"
      exit 0;;
    *) die "Unknown argument: $1";;
  esac
done

# Warn if using defaults
[[ "$ZIP_PATH" == "./butterflycluster_com.zip" ]] && echo "⚠️  Using default ZIP_PATH=$ZIP_PATH (override with --zip)"
[[ "$KEY_PATH" == "./butterflycluster_com.key" ]] && echo "⚠️  Using default KEY_PATH=$KEY_PATH (override with --key)"
[[ "$HOSTNAME" == "charon.butterflycluster.com" ]] && echo "⚠️  Using default HOSTNAME=$HOSTNAME (override with --hostname)"

[[ -f "$ZIP_PATH" ]] || die "Zip not found: $ZIP_PATH"
[[ -f "$KEY_PATH" ]] || die "Key not found: $KEY_PATH"

command -v unzip >/dev/null || die "unzip is required"
command -v openssl >/dev/null || die "openssl is required"

WORKDIR="$(mktemp -d -t namecheap-XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

info "Unzipping $ZIP_PATH"
unzip -o "$ZIP_PATH" -d "$WORKDIR" >/dev/null

CRT_SRC="$(ls "$WORKDIR"/__*butterflycluster_com.crt 2>/dev/null || true)"
CAB_SRC="$(ls "$WORKDIR"/__*butterflycluster_com.ca-bundle 2>/dev/null || true)"
P7B_SRC="$(ls "$WORKDIR"/__*butterflycluster_com.p7b 2>/dev/null || true)"

[[ -n "$CRT_SRC" ]] || die "Server cert not found in zip"
[[ -n "$CAB_SRC" || -n "$P7B_SRC" ]] || die "CA bundle not found in zip"

SSL_DIR="/etc/ssl"
CRT_OUT="$SSL_DIR/butterflycluster_com.crt.pem"
CAB_OUT="$SSL_DIR/butterflycluster_com.ca-bundle"
KEY_OUT="$SSL_DIR/butterflycluster_com.key.pem"

sudo mkdir -p "$SSL_DIR"

info "Converting server certificate to PEM → $CRT_OUT"
sudo openssl x509 -in "$CRT_SRC" -out "$CRT_OUT"

if [[ -n "$CAB_SRC" ]]; then
  info "Copying CA bundle → $CAB_OUT"
  sudo cp "$CAB_SRC" "$CAB_OUT"
else
  info "Extracting CA bundle from PKCS#7 → $CAB_OUT"
  sudo bash -c "openssl pkcs7 -print_certs -in '$P7B_SRC' -out '$CAB_OUT'"
fi

info "Normalizing private key → $KEY_OUT"
sudo bash -c "openssl pkey -in '$KEY_PATH' -out '$KEY_OUT'"

sudo chown root:root "$CRT_OUT" "$CAB_OUT" "$KEY_OUT"
sudo chmod 644 "$CRT_OUT" "$CAB_OUT"
sudo chmod 600 "$KEY_OUT"

# ---- Validations ----
info "Checking cert validity dates"
openssl x509 -in "$CRT_OUT" -noout -dates -issuer -subject

info "Checking SANs include $HOSTNAME"
if ! openssl x509 -in "$CRT_OUT" -noout -text | grep -A1 "Subject Alternative Name" | grep -q "$HOSTNAME"; then
  die "Hostname $HOSTNAME not found in SANs"
fi
ok "SANs look good"

info "Checking key ↔ cert match"
HASH_CERT=$(openssl x509 -noout -modulus -in "$CRT_OUT" | openssl md5 | awk '{print $2}')
HASH_KEY=$(openssl pkey -noout -modulus -in "$KEY_OUT" | openssl md5 | awk '{print $2}')
[[ "$HASH_CERT" == "$HASH_KEY" ]] || die "Key and certificate DO NOT match"
ok "Key and cert match"

info "Verifying chain"
TMP_CHAIN="$(mktemp)"
cat "$CRT_OUT" "$CAB_OUT" > "$TMP_CHAIN"
if openssl verify -CAfile "$CAB_OUT" "$TMP_CHAIN" >/dev/null 2>&1; then
  ok "Chain verifies successfully"
else
  openssl verify -CAfile "$CAB_OUT" "$TMP_CHAIN"
  die "Full chain verification failed"
fi
rm -f "$TMP_CHAIN"

ok "All certificate files installed and validated successfully"
