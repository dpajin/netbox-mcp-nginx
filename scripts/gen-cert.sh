#!/bin/sh
# Usage: scripts/gen-cert.sh [ip-or-hostname ...]
# Writes a self-signed cert to ./certs (localhost/127.0.0.1 always included).
# Set FORCE=1 to overwrite an existing one.
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)/certs"
mkdir -p "$DIR"

if [ -s "$DIR/server.crt" ] && [ "${FORCE:-0}" != 1 ]; then
  echo "$DIR/server.crt exists; use FORCE=1 to overwrite."
  exit 0
fi

SAN="DNS:localhost,IP:127.0.0.1"
CN="${1:-localhost}"
for h in "$@"; do
  case "$h" in
    *[!0-9.]*) SAN="$SAN,DNS:$h" ;;
    *)         SAN="$SAN,IP:$h" ;;
  esac
done

CONF="$(mktemp)"
trap 'rm -f "$CONF"' EXIT
cat > "$CONF" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $CN
[ext]
subjectAltName = $SAN
EOF

umask 077
openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
  -days "${CERT_DAYS:-365}" -config "$CONF" \
  -keyout "$DIR/server.key" -out "$DIR/server.crt"
# Key must be readable by the nginx container user.
chmod 644 "$DIR/server.crt" "$DIR/server.key"
echo "Generated $DIR/server.crt for $SAN"
