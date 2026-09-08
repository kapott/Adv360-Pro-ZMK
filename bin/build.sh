#!/usr/bin/env bash

set -eu

PWD=$(pwd)
TIMESTAMP="${TIMESTAMP:-$(date -u +"%Y%m%d%H%M")}"
COMMIT="${COMMIT:-$(echo xxxxxx)}"
BUILD_STUDIO="${BUILD_STUDIO:-true}"

# West Build (left)
#
# ZMK Studio persists per-key bindings to NVS under keymap/l/<layer>/<position>
# and replays them over the compiled keymap at boot (zmk/app/src/keymap.c:588).
# A key remapped in Clique therefore outlives a firmware update and silently
# wins over config/adv360.keymap. Set BUILD_STUDIO=false to compile that overlay
# out and make the repo the only source of truth.
if [ "${BUILD_STUDIO}" = true ]; then
    west build -s zmk/app -p -d build/left -b adv360_left -S studio-rpc-usb-uart -- -DZMK_CONFIG="${PWD}/config" -DCONFIG_ZMK_STUDIO=y
else
    west build -s zmk/app -p -d build/left -b adv360_left -- -DZMK_CONFIG="${PWD}/config" -DCONFIG_ZMK_STUDIO=n
fi
# Adv360 Left Kconfig file
grep -vE '(^#|^$)' build/left/zephyr/.config
# Rename zmk.uf2
cp build/left/zephyr/zmk.uf2 "./firmware/${TIMESTAMP}-${COMMIT}-left-clique.uf2"

# Build right side if selected
if [ "${BUILD_RIGHT}" = true ]; then
    # West Build (right)
    west build -s zmk/app -p -d build/right -b adv360_right -- -DZMK_CONFIG="${PWD}/config"
    # Adv360 Right Kconfig file
    grep -vE '(^#|^$)' build/right/zephyr/.config
    # Rename zmk.uf2
    cp build/right/zephyr/zmk.uf2 "./firmware/${TIMESTAMP}-${COMMIT}-right-clique.uf2"
fi
