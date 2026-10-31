#!/bin/sh
# Create a QNX SDP 6.5.0 licence configuration for the qnx650-sdk image, using
# QNX's own licence library (qnxlm_linux.so + com.qnx.install.License) from the
# SDP installer, run in a 32-bit JVM container with networking disabled.
#
# usage: make-license.sh <sdp-iso-dir> <licence-key> [config-dir]
#   config-dir defaults to ./qnx-config; the result is <config-dir>/license/licenses
#   Mount it with: docker run -v <config-dir>/license:/etc/qnx/license ...
set -eu

iso=$1 key=$2 out=${3:-qnx-config}
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

unzip -q -j "$iso/qnx_linux_setup.jar" '*/beanLoadDLL/qnxlm_linux.so' -d "$work"
unzip -q "$iso/qnx_linux_setup.jar" 'com/qnx/install/License.class' \
    'com/qnx/install/LicenseInfo.class' 'com/qnx/install/LicenseException.class' -d "$work"
cp "$here/tools/AddKey.java" "$work/"

docker build -q -t qnx650-addkey - >/dev/null <<'EOF'
FROM i386/debian:bookworm-slim
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends openjdk-17-jdk-headless >/dev/null \
 && rm -rf /var/lib/apt/lists/*
EOF

mkdir -p "$out"
docker run --rm --network none -u "$(id -u):$(id -g)" \
    -v "$work":/w -v "$(cd "$out" && pwd)":/cfg -w /w qnx650-addkey \
    sh -c 'javac -cp /w -d /w AddKey.java && java -cp /w AddKey /w/qnxlm_linux.so /cfg "$0"' "$key"
chmod 1777 "$out/license"
chmod 666 "$out/license/licenses"
echo "wrote $out/license/licenses"
