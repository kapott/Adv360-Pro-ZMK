# Keymap changes have no effect after flashing new firmware

## Context

Adv360 Pro, this fork, left half flashed from `make left`. Added `hml`/`hmr` home
row mods to `config/adv360.keymap` on positions 29-32 and 41-44, built both
halves, flashed both over the UF2 bootloader.

The keyboard had previously been upgraded to Clique, so ZMK Studio was enabled
in the build (`bin/build.sh` passes `-S studio-rpc-usb-uart -DCONFIG_ZMK_STUDIO=y`
for the left side) and a layout had been saved from the Clique web app at some
point.

## Problem

Every home row mod acted like a plain letter. Holding `F` produced `fffffff`
from OS key repeat instead of Shift. Same for `A`, `S`, `D`, `J`, `K`, `L`, `;`.

The firmware itself was demonstrably new. Mod+V typed the fresh build string:

```
20260908-v3.0-f066199-clique
```

And the behaviors were compiled into the image:

```bash
strings -n 6 firmware/*-left-clique.uf2 | grep HOME_ROW_MOD
# HOME_ROW_MOD_RIGHT
# HOME_ROW_MOD_LEFT
```

So the build picked up the edited keymap, the board ran that build, and the
board still ignored the keymap.

## Solution

ZMK Studio saves per-key bindings to the settings partition and replays them
over the compiled keymap on every boot. `zmk/app/src/keymap.c`:

```c
load_stock_keymap_layer_ordering();
reload_from_stock_keymap();          // devicetree keymap
int ret = settings_load_subtree("keymap");   // NVS then overwrites it
```

Bindings live under `keymap/l/<layer>/<position>`, so a key remapped in Clique
outlives any number of firmware updates and silently beats
`config/adv360.keymap`. Positions 29-32 and 41-44 had been saved as plain `&kp`,
which is exactly the home row.

The version macro still updated because a macro's *contents* are compiled in.
The saved keymap only decides which behavior sits on which position, and Mod+V
was already pointing at `macro_ver`. That is why the build string was a
misleading "proof" that the update had landed.

Check whether a build carries the overlay at all:

```bash
strings -n 4 firmware/<file>.uf2 | grep '^keymap/'
# keymap/layer_order
# keymap/l/%d/%d
# keymap/l_n/%d
```

Three ways out, in rising order of finality:

1. Reset the stored keymap from Clique. `zmk_keymap_reset_settings()` in
   `keymap.c` deletes the saved bindings and reloads from the compiled keymap.
   Keeps BLE host profiles. Needs `&studio_unlock` first, which sits on the Mod
   layer at position 28.
2. Flash `settings-reset.uf2`, then flash the firmware again. Wipes the whole
   settings partition, so BLE bonds and the pairing between the halves go too.
3. Build with `CONFIG_ZMK_STUDIO=n`. The overlay code is not compiled in, so the
   repo becomes the only source of truth. Clique can no longer see the keyboard.

We took option 3, since the keymap lives in git and two editors writing the same
keymap is the underlying problem rather than a side issue. `bin/build.sh` and the
`Makefile` now take `BUILD_STUDIO`, default `true`:

```bash
make left BUILD_STUDIO=false
```

Confirm it worked by the absence of the serial port. A Studio build exposes
`/dev/ttyACM0`; a non-Studio build exposes nothing:

```bash
ls /dev/ttyACM*   # no matches = Studio compiled out
```

The saved bindings stay in NVS. Flash a Studio build again and they come back.

### Wrong turns

- Tuning the hold-tap. `require-prior-idle-ms` and `quick-tap-ms` both force a
  tap and both produce exactly this repeat, so they look guilty. They are worth
  one test (idle a full second, then hold) and no more. If *every* mod fails
  after a genuine idle pause, the behavior is not being reached at all and
  tuning its parameters is wasted effort.
- Believing the version macro. Mod+V proves the board booted a new image. It
  says nothing about which keymap that image is using.
- Suspecting the build. `strings` on the `.uf2` settles it in a second, and it
  settled it the wrong way here, which is what pointed at a runtime override.

### Only the left half needs reflashing

In a ZMK split the central side owns the keymap and the peripheral only reports
key positions. A keymap-only change needs the left half flashed and nothing
else, including for keys that physically sit on the right half. Confirmed by
flashing left alone and watching positions 71 and 72 change behavior.
