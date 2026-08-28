#!/usr/bin/env bash
set -e

rm -f or1420SingleCore.bit or1420SingleCore.config or1420SingleCore.json
yosys -m ghdl -D GECKO5Education -s ../scripts/yosysOr1420.script
nextpnr-ecp5 --timing-allow-fail --85k --package CABGA381 --json or1420SingleCore.json --lpf ../scripts/gecko5_or1420.lpf --textcfg or1420SingleCore.config
ecppack --compress --freq 62.0 --input or1420SingleCore.config --bit or1420SingleCore.bit

if [[ "${1:-}" != "--no-program" ]]; then
  openFPGALoader or1420SingleCore.bit
fi
