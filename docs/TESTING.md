# Validation

Release publishing depends on all checks passing.

- 47 model checks: persistence/legacy optional settings, layout, usage, motion policy including battery/Low Power overrides, calculator, daily counters, safe URLs, and connected-device battery fixtures.
- 64 wallpaper/palette combinations: render two different times and require different pixels for every procedural style, including Gradient.
- Eight native desktop-window animation tests: actual redraw timers advance, pixels change, pause freezes pixels/phase, and resume advances again.
- Five Claude status-line helper tests.
- Xcode Debug and universal arm64/x86_64 Release builds, signature/icon/plist checks.
- First-launch settings and wallpaper level, followed by a saved-settings launch of all 27 widget types.

Manual checks: connect real AirPods/keyboard/mouse/trackpad; compare their current levels with macOS; disconnect and refresh. Test battery and Low Power Mode transitions, Reduce Motion, external displays and Spaces/Stage Manager. Verify real Codex/Claude account snapshots, city weather, and each widget's click interactions. Check old v1.0.0 preferences on an existing installation.

Automated fixture/runner checks do not establish support for every physical Bluetooth device or every user's macOS configuration.
## Version 1.2 checks

CI adds 73 total model checks, eight mocked browser-media behavior checks executed by macOS JavaScript for Automation, and four checks against the packaged update (real extraction/signature/version, bad checksum, wrong version, helper syntax). All 29 widgets are included in the live launch.

Manual checks still required: real Music/Spotify and browser Automation prompts, current-tab website compatibility, actual app/folder selection and launching, and replacing a running installed app via Updates. The update test validates preparation, not actual quit/replacement/relaunch on a user's Mac.
