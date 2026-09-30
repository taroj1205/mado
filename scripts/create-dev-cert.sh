#!/bin/sh
set -eu

name="${1:-Mado Development}"

if security find-identity -p codesigning | grep -q "\"$name\""; then
  echo "create-dev-cert: \"$name\" already exists"
  exit 0
fi

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
pass=$(openssl rand -hex 16)

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=$name/O=Local Development/OU=Code Signing" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -keyout "$dir/key.pem" -out "$dir/cert.pem" 2>/dev/null
openssl pkcs12 -export -legacy -inkey "$dir/key.pem" -in "$dir/cert.pem" \
  -name "$name" -out "$dir/id.p12" -passout "pass:$pass"
security import "$dir/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P "$pass" -T /usr/bin/codesign
echo "create-dev-cert: created \"$name\""
