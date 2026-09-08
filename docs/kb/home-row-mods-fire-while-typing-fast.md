# Home row mods fire Ctrl/Alt while typing normal words

## Context

Adv360 Pro, this fork, `config/adv360.keymap` on the base layer. Goal was CAGS
home row mods (Ctrl, Alt, GUI, Shift running from pinky inwards) on `A S D F`
and `J K L ;`, on top of the stock layout.

The owner types fast. A naive hold-tap on the home row is unusable at speed.

## Problem

With a plain `zmk,behavior-hold-tap` like the `hm` behavior that ships in this
repo, typing normal words produces modifiers instead of letters:

```
hm: homerow_mods {
    compatible = "zmk,behavior-hold-tap";
    tapping-term-ms = <200>;
    flavor = "tap-preferred";
    bindings = <&kp>, <&kp>;
};
```

Two separate failure shapes, and they need two different fixes:

1. Same-hand rolls. Typing `sad` or `def` overlaps two keys on one hand. The
   first key is still down when the second goes down, so the hold-tap decides
   "hold" and you get Alt+D instead of `ad`.
2. Fast alternation. A word like `the` alternates hands within ~80ms. Even a
   correct positional check sees an opposite-hand key and fires the modifier.

## Solution

Two positional hold-taps, one per hand, with four properties doing four
distinct jobs. The `hm` behavior above has none of them.

```
hml: home_row_mod_left {
    compatible = "zmk,behavior-hold-tap";
    #binding-cells = <2>;
    flavor = "balanced";
    tapping-term-ms = <280>;
    quick-tap-ms = <175>;
    require-prior-idle-ms = <150>;
    bindings = <&kp>, <&kp>;
    hold-trigger-key-positions = <KEYS_R THUMBS>;
    hold-trigger-on-release;
};
```

`hold-trigger-key-positions` fixes failure 1. The left-hand behavior lists only
right-hand and thumb positions, so a same-hand roll can never resolve to a hold.
The position numbers come from `assets/key-positions.md`; copy them into the
keymap as `#define` and let the preprocessor expand them.

`require-prior-idle-ms = <150>` fixes failure 2, and it is the property that
matters most. If the previous keypress was less than 150ms ago, the key is a
tap no matter how long it is held. Mid-word the mods simply do not exist. Raise
it if misfires remain, lower it if reaching for a modifier feels sluggish.

`flavor = "balanced"` needs the next key both pressed and released while the
mod is held. `hold-preferred` would fire on press alone.

`hold-trigger-on-release` defers the decision to release, which is what lets
mods chain. Without it, Ctrl+Shift+T breaks: the second mod is treated as the
"other key" that resolves the first one.

Apply them with the mod as the first parameter:

```
&kp ESC  &hml LCTRL A  &hml LALT S  &hml LGUI D  &hml LSHFT F  ...
```

### Wrong turns

- Reusing the repo's existing `hm` behavior. It is defined but unused on the
  stock layout, and `tap-preferred` with no positional check is exactly the
  configuration that misfires.
- Assuming the properties exist. This fork pins `refil/zmk` at `adv360-z3.5-2`,
  not ZMK main. Check before writing them, or the build fails on an unknown
  devicetree property:

  ```
  curl -sf "https://raw.githubusercontent.com/refil/zmk/adv360-z3.5-2/app/dts/bindings/behaviors/zmk%2Cbehavior-hold-tap.yaml"
  ```

  All four are present there. Note that `quick_tap_ms` with an underscore, which
  the stock `hm` uses, is marked `deprecated: true`. Write `quick-tap-ms`.
- Editing only `config/adv360.keymap`. `UPGRADE.md` says `adv360.keymap` and
  `keymap.json` are kept in sync by hand. The build reads the keymap, but the
  Kinesis web app reads and rewrites the JSON, so a hand edit that skips the
  JSON gets silently reverted the next time the layout is opened in the app.
  Base layer indices are `29-32` for `A S D F` and `41-44` for `J K L ;`.

### Verifying without flashing

Binding count must stay at 76 per layer in both files, and the position macros
should expand to 44 entries each:

```bash
sed -n '/^#define KEYS_L/,/^#define THUMBS/p' config/adv360.keymap > /tmp/defs.h
printf 'KEYS_R THUMBS\n' >> /tmp/defs.h
cpp -P /tmp/defs.h | tail -1 | wc -w   # 44

make left                              # full devicetree compile in Docker
```
