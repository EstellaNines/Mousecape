# macOS compatibility development build

Version 1822 has been tested on macOS 26.5 (25F71), Apple Silicon. It fixes the system Arrow and IBeam replacements observed on this machine, and corrects the local build's missing icon and titlebar overlap. This is not a claim that every cursor in every application, or every macOS version, can be replaced.

## Changes

- Discover `com.apple.coregraphics.ArrowS` and `com.apple.coregraphics.IBeamS` only when WindowServer exposes them. Register these names alongside their legacy names; keep ArrowCtx and IBeamXOR independent.
- Retain upstream's [2024 registration ABI correction](https://github.com/alexzielenski/Mousecape/commit/3d119373acebce33bca6423bc66a6e1101252dd4).
- Back up each exposed name independently, including when a legacy Arrow backup already exists. Abort application if an existing cursor cannot be backed up. Restore each exact name and retain backups when restoration fails.
- Initialize only known CoreCursor IDs when resetting. On the tested system, gaps 6 and 44 return an error and must not prevent a theme from being applied.
- Reject invalid frame counts, dimensions, durations, and undecodable image data before registration. Report application/restoration errors and return a failing CLI exit status.
- Disable the upstream Sparkle update feed so that it cannot replace this fork with upstream 1813.
- Preserve the app icon metadata in the CLT fallback build, and use AppKit's titlebar accessory controller on macOS 10.10+ to prevent title/window-button overlap.

The additional Tahoe cursor names were identified in the [TahoeSupport fork](https://github.com/AdamWawrzynkowskiGF/Mousecape-TahoeSupport/commit/894c5a3). This fork uses exact names and checks whether each is present on the running system.

## Build

With full Xcode selected:

```sh
git submodule update --init --recursive
./script/test.sh
./script/build_and_run.sh
```

The app is written to `build/Mousecape.app` and signed ad hoc for local use. This does not produce a Developer ID signed or notarized release.

### Command Line Tools fallback

The native CLI can be built with the macOS Command Line Tools alone:

```sh
./script/build.sh --cli
./build/mousecloak --help
```

To test the existing GUI without full Xcode, install upstream 1813 at `/Applications/Mousecape.app`, then run:

```sh
./script/build_and_run.sh --reuse-installed-resources
```

This compiles the current GUI, CLI, and helper source for Intel, reusing upstream 1813's compiled interface resources and Intel Sparkle framework. Apple Silicon runs this GUI through Rosetta. The separately built CLI is native arm64. Interface resources have not changed between 1813 and the upstream base used here. Full Xcode is required for interface changes and a native or universal GUI release.

The build does not replace `/Applications/Mousecape.app` or install the login helper. The development app shares the upstream preferences and cape library. Save edits before using `build_and_run.sh`, which stops a running Mousecape process before rebuilding. Avoid running both app/helper versions together.

## Apply, inspect, and restore

Use an absolute path to the animated theme:

```sh
./build/mousecloak --apply /absolute/path/to/theme.cape
./script/verify_theme.sh /absolute/path/to/theme.cape
./build/mousecloak --reset
```

`verify_theme.sh` is read-only. It compares each theme cursor and any discovered aliases with WindowServer's registered frame count, duration, dimensions, hotspot, and representation count. These commands require a connection to the logged-in desktop. Applying and restoring change the active system cursors.

## Validation on 2026-10-09

| Check | Result |
| --- | --- |
| Test platform | macOS 26.5 (25F71), arm64; SIP enabled |
| Regression tests | Passed both modern-name and legacy-only environments, including alias errors, invalid input, independent backups, backup failure abort, partial application rollback, and failed restore retry |
| Native CLI | Built arm64; applied `PRTS Replica v1` successfully |
| WindowServer readback | All 18 theme entries and the two discovered aliases matched: 20 checks passed |
| Local GUI | Current source compiled x86_64 with reused resources; ad hoc signature verification passed |
| Version 1822 appearance | AppIcon2 metadata/resource checked; title and window buttons no longer overlap, applied-theme label remains visible; user confirmed the icon and interface display normally |
| GUI Apply Cape | Applied the animated theme and displayed the correct applied name |
| GUI Restore Defaults | Cleared the applied name; ArrowS returned to 28×40 and IBeamS to 23×22, both one frame |
| Visible behavior | User confirmed that the Arrow replacement and IBeam animation both work after GUI reapplication |

The tested PRTS theme's Arrow has one frame. Its IBeam has 24 frames. Arrow replacement and animated IBeam are therefore separate acceptance checks; this theme cannot demonstrate an animated Arrow.

## Remaining coverage and risks

The full Xcode build, a native/universal GUI distribution, login helper installation, login/reboot persistence, display reconnection, multiple displays, full-screen applications, and other macOS versions have not been tested. Applications that install their own cursor images can still override system cursor replacements.

The discovery scan covers system cursor IDs 0–127. Apple's private APIs have no stable compatibility contract; a later release may require new names or signatures. No SIP change or modification of system files is required by this build.

Targeted risk review:

- **P0:** No new privileged service, credential access, SIP change, or system-file modification. The installed app and cape files were left untouched.
- **P1:** A failed restore retains its backup for retry. A partial application attempts to restore defaults; persistent WindowServer errors may leave a partial theme, requiring another restore attempt or a fresh desktop session.
- **P2:** The CLT GUI depends on reused resources and Rosetta; shared preferences and untested platforms remain development-build limits.
