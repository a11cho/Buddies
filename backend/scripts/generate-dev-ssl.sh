#!/usr/bin/env bash
set -euo pipefail

PASSWORD="${1:-buddies-local-ssl}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${BACKEND_DIR}/config"
KEYSTORE="${CONFIG_DIR}/dev-ssl.p12"

mkdir -p "${CONFIG_DIR}"
rm -f "${KEYSTORE}"

docker run --rm \
  -v "${CONFIG_DIR}:/work" \
  eclipse-temurin:21-jre \
  keytool -genkeypair \
    -alias buddies-local \
    -keyalg RSA \
    -keysize 2048 \
    -storetype PKCS12 \
    -keystore /work/dev-ssl.p12 \
    -storepass "${PASSWORD}" \
    -keypass "${PASSWORD}" \
    -validity 3650 \
    -dname "CN=110.76.94.211, OU=Development, O=Buddies, L=Daejeon, ST=Daejeon, C=KR" \
    -ext "SAN=dns:localhost,ip:127.0.0.1,ip:110.76.94.211"

echo "Generated ${KEYSTORE}"
