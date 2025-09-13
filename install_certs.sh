#!/usr/bin/env bash
set -Eeuo pipefail

# ---------------------------------------------
# Install TLS certs from Namecheap zip (sudo + wildcard SAN aware)
# ---------------------------------------------
# Usage examples:
#   sudo ./install_certs.sh
#   sudo ./install_certs.sh --zip ./butterflycluster_com.zip --key ./butterflycluster_com.key.pem --hostname charon.butterflycluster.com
# ---------------------------------------------

# --- Self-elevate to root (prompts for password if needed)
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -p "[sudo] Password for %u: " bash "$0" "$@"
fi

# --- defaults (overridable by CLI)
ZIP_PATH="./butterflycluster_com.zip"
KEY_PATH="./butterflycluster_com.key"
HOSTNAME="charon.butterflycluster.com"

die() { echo "❌ $*" >&2; exit 1; }
ok()  { echo "✅ $*"; }
info(){ echo "— $*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

# --- parse CLI overrides
while [[ $# -gt 0 ]]; do
  case "$1" in
    --zip)      ZIP_PATH="${2:-}"; shift 2;;
    --key)      KEY_PATH="${2:-}"; shift 2;;
    --hostname) HOSTNAME="${2:-}"; shift 2;;
    -h|--help)
      cat <<USAGE
Usage: $0 [--zip path] [--key path] [--hostname fqdn]
Defaults:
  --zip      $ZIP_PATH
  --key      $KEY_PATH
  --hostname $HOSTNAME
USAGE
      exit 0;;
    *) die "Unknown argument: $1";;
  esac
done

# Warn if using defaults
[[ "$ZIP_PATH" == "./butterflycluster_com.zip" ]] && echo "⚠️  Using default ZIP_PATH=$ZIP_PATH (override with --zip)"
[[ "$KEY_PATH" == "./butterflycluster_com.key" ]] && echo "⚠️  Using default KEY_PATH=$KEY_PATH (override with --key)"
[[ "$HOSTNAME" == "charon.butterflycluster.com" ]] && echo "⚠️  Using default HOSTNAME=$HOSTNAME (override with --hostname)"

# Fallback: if default KEY_PATH not found, try .key.pem in CWD
if [[ ! -f "$KEY_PATH" && -f "./butterflycluster_com.key.pem" ]]; then
  echo "ℹ️  KEY_PATH not found, using ./butterflycluster_com.key.pem"
  KEY_PATH="./butterflycluster_com.key.pem"
fi

# Requirements
need_cmd unzip
need_cmd openssl

[[ -f "$ZIP_PATH" ]] || die "Zip not found: $ZIP_PATH"
[[ -f "$KEY_PATH" ]] || die "Key not found: $KEY_PATH"

WORKDIR="$(mktemp -d -t namecheap-XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

info "Unzipping $ZIP_PATH"
unzip -o "$ZIP_PATH" -d "$WORKDIR" >/dev/null

CRT_SRC="$(ls "$WORKDIR"/__*butterflycluster_com.crt 2>/dev/null || true)"
CAB_SRC="$(ls "$WORKDIR"/__*butterflycluster_com.ca-bundle 2>/dev/null || true)"
P7B_SRC="$(ls "$WORKDIR"/__*butterflycluster_com.p7b 2>/dev/null || true)"

[[ -n "$CRT_SRC" ]] || die "Server cert not found in zip (expected __butterflycluster_com.crt)"
[[ -n "$CAB_SRC" || -n "$P7B_SRC" ]] || die "CA bundle not found (need __butterflycluster_com.ca-bundle or __butterflycluster_com.p7b)"

SSL_DIR="/etc/ssl"
CRT_OUT="$SSL_DIR/butterflycluster_com.crt.pem"
CAB_OUT="$SSL_DIR/butterflycluster_com.ca-bundle"
KEY_OUT="$SSL_DIR/butterflycluster_com.key.pem"

mkdir -p "$SSL_DIR"

info "Converting server certificate to PEM → $CRT_OUT"
openssl x509 -in "$CRT_SRC" -out "$CRT_OUT"

if [[ -n "$CAB_SRC" ]]; then
  info "Copying CA bundle → $CAB_OUT"
  cp "$CAB_SRC" "$CAB_OUT"
else
  info "Extracting CA bundle from PKCS#7 → $CAB_OUT"
  openssl pkcs7 -print_certs -in "$P7B_SRC" -out "$CAB_OUT"
fi

info "Normalizing private key (PKCS#8) → $KEY_OUT"
# If encrypted, this will prompt once for the passphrase and write an unencrypted key
openssl pkey -in "$KEY_PATH" -out "$KEY_OUT"

chown root:root "$CRT_OUT" "$CAB_OUT" "$KEY_OUT"
chmod 644 "$CRT_OUT" "$CAB_OUT"
chmod 600 "$KEY_OUT"

# ---- Validations ----
info "Checking cert validity dates / issuer / subject"
openssl x509 -in "$CRT_OUT" -noout -dates -issuer -subject

info "Checking SANs cover $HOSTNAME (supports wildcard matches)"
# Extract SAN DNS entries
mapfile -t SAN_DNS < <(
  openssl x509 -in "$CRT_OUT" -noout -text \
  | awk '/Subject Alternative Name/{flag=1;next} /X509v3/{flag=0} flag' \
  | tr -d ' ' | tr ',' '\n' | grep -E '^DNS:' || true
)

if [[ ${#SAN_DNS[@]} -eq 0 ]]; then
  die "No DNS SANs found in certificate (modern clients ignore CN)."
fi

match_found="false"
for entry in "${SAN_DNS[@]}"; do
  san="${entry#DNS:}"

  # Exact match
  if [[ "$HOSTNAME" == "$san" ]]; then
    match_found="true"; break
  fi

  # Wildcard match: *.example.com matches foo.example.com (but not example.com)
  if [[ "$san" == \*.* ]]; then
    base="${san#*.}"  # example.com
    if [[ "$HOSTNAME" == *".${base}" && "$HOSTNAME" != "$base" ]]; then
      match_found="true"; break
    fi
  fi
done

if [[ "$match_found" != "true" ]]; then
  echo "Found SANs:"
  printf '  - %s\n' "${SAN_DNS[@]}"
  die "Hostname $HOSTNAME is not covered by SANs (need exact SAN or appropriate wildcard)."
fi
ok "SANs cover $HOSTNAME"

info "Checking key ↔ cert match"
HASH_CERT="$(openssl x509 -noout -modulus -in "$CRT_OUT" | openssl md5 | awk '{print $2}')"
HASH_KEY="$(openssl pkey -noout -modulus -in "$KEY_OUT" | openssl md5 | awk '{print $2}')"
[[ "$HASH_CERT" == "$HASH_KEY" ]] || die "Key and certificate DO NOT match"
ok "Key and cert match"

info "Verifying full chain"
TMP_CHAIN="$(mktemp)"
cat "$CRT_OUT" "$CAB_OUT" > "$TMP_CHAIN"
if openssl verify -CAfile "$CAB_OUT" "$TMP_CHAIN" >/dev/null 2>&1; then
  ok "Chain verifies successfully"
else
  openssl verify -CAfile "$CAB_OUT" "$TMP_CHAIN" || true
  rm -f "$TMP_CHAIN"
  die "Full chain verification failed (bundle likely missing correct intermediates)."
fi
rm -f "$TMP_CHAIN"

ok "All certificate files installed and validated successfully"
echo "📍 Installed:"
echo "  - $CRT_OUT"
echo "  - $CAB_OUT"
echo "  - $KEY_OUT"
