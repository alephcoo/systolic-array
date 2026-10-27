#!/usr/bin/env bash
set -euo pipefail

VERILATOR_VERSION="5.020"

echo "Installing system dependencies"
sudo apt-get update -y
sudo apt-get install -y \
    build-essential git python3 python3-pip python3-venv \
    autoconf flex bison libfl2 libfl-dev zlib1g zlib1g-dev \
    help2man perl wget curl gtkwave

echo "Building Verilator ${VERILATOR_VERSION}"
TMP=$(mktemp -d)
git clone https://github.com/verilator/verilator.git "$TMP/verilator"
cd "$TMP/verilator"
git checkout "v${VERILATOR_VERSION}"
autoconf
./configure
make -j"$(nproc)"
sudo make install
cd /
rm -rf "$TMP"

echo "Installing Python packages"
pip3 install --user cocotb==1.8.1 pytest numpy

echo "Done"
echo "Run: make sim2   (2x2)"
echo "Run: make sim4   (4x4)"
