# Validation

Automated checks live in .github/workflows/macos.yml. The release job depends on the entire build job passing.

## Automated

- 20 model checks: persistence, grid rounding/clamping, invalid geometry recovery, opt-in defaults, Codex/Claude parsing, missing/invalid windows, weekly-only plans, timestamps, stale readings.
- 40 renders: five procedural styles × eight palettes, checking image dimensions and nonblank pixel diversity.
- Four Python tests: usage-only filtering, missing values, invalid percentages, independently optional windows.
- Xcode Debug and universal arm64/x86_64 Release compilation.
- Ad-hoc signature, executable architectures, Info.plist, and generated icon checks.
- Actual app launch with a visible settings window and a wallpaper window at the intended desktop layer.
- Release archive and checksum validation; downloaded release compared byte-for-byte.

## Manual on a physical Mac

1. Fresh install: onboarding, import PNG/JPEG and animated GIF; fill/fit; change all procedural designs and palettes.
2. Add each widget; change appearance, font, size; arrange/snap; quit/relaunch; verify positions.
3. Keep desktop icons clickable outside widgets. Place ordinary app windows above widgets. Test Mission Control, Spaces, Stage Manager, and full-screen apps.
4. Attach/disconnect/reconnect an external display with nonzero/negative coordinates; confirm widget fallback and restoration.
5. Pause/resume; sleep/wake; Low Power Mode; battery transition; Reduce Motion.
6. Click weather for rain/snow/sun matching the current condition; disable interaction and verify click-through. Test offline weather and stale labels.
7. Configure real Codex and Claude Code accounts. Compare remaining/reset fields to their CLIs, including absent windows and stale snapshots.
8. Import the HTML example; test network-disabled versus enabled and verify links/pop-ups/file URLs cannot escape.
9. Test Dock/menu bar/both/neither; reopen from Finder when hidden. Register/unregister login item from /Applications.
10. On a separate Mac, download the release to exercise Gatekeeper and first-launch handling.

No CI result should be described as validating live account integrations or every physical macOS configuration.
