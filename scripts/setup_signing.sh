#!/bin/bash
# One-time setup: creates a stable self-signed code-signing certificate
# ("MScreenshot Signing") in the login keychain and trusts it for code
# signing. Signing every build with the same identity keeps macOS TCC
# permissions (Screen Recording, folder access) across app updates —
# ad-hoc signatures change on every build, which resets permissions.
#
# May prompt for your macOS password when adding trust.
set -euo pipefail

NAME="MScreenshot Signing"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
    echo "Signing identity \"$NAME\" already exists — nothing to do."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
basicConstraints = critical,CA:false
EOF

openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -config "$TMP/cert.conf" >/dev/null 2>&1

# Import key and certificate as PEM (PKCS12 from OpenSSL 3 is not always
# accepted by `security import`).
security import "$TMP/key.pem" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
security import "$TMP/cert.pem" -k ~/Library/Keychains/login.keychain-db

if ! security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db "$TMP/cert.pem"; then
    echo
    echo "Automatic trust failed. Open Keychain Access → login → My Certificates,"
    echo "double-click \"$NAME\" → Trust → Code Signing: Always Trust."
fi

echo
security find-identity -v -p codesigning
echo "Done. Rebuild and reinstall the app (scripts/install.sh)."
