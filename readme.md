# SimpleScreen

**A little more you.** A native, minimalist wallpaper and desktop widget studio for macOS. Free, open source, and local-first.

[Download the latest app](https://github.com/Tekwiz17/SimpleScreen/releases/latest) · [Build status](https://github.com/Tekwiz17/SimpleScreen/actions/workflows/macos.yml) · [MIT License](LICENSE)

## Make your desktop yours

- **Wallpaper studio:** Aurora, Gradient, Dunes, Orbit, Contour, Ripple, Starlight, and Ribbons; eight original palettes; two to five custom colors; adjustable direction and motion.
- **Your own images:** import still images or animated GIFs. Fit or fill. Originals are copied into Application Support.
- **29 widgets:** Clock, Weather, Battery, Calendar, Focus, Note, AI Usage, HTML, Device Batteries, World Clock, Analog Clock, Countdown, Stopwatch, Checklist, Habit, Water, Breathe, Daily Thought, Day Progress, Storage, Memory, Uptime, Quick Links, Calculator, Dice, Color Studio, Weather Details, App & Folder Launcher, and Now Playing.
- **Launchers:** actual app/folder icons, searchable picker, configurable grids, labels, and one-click opening.
- **Now Playing:** opt-in Music/Spotify controls and supported browser current-tab audio/video. [Setup and limits](docs/NOW-PLAYING.md).
- **Search and updates:** global search, widget synonyms, release notes, and a verified in-app update flow. [Guide](docs/LAUNCHERS-AND-UPDATES.md).
- **Personal styling:** glass, solid-color, or transparent surfaces; text/tint colors, opacity, fonts, dimensions, and display assignment.
- **Arrange mode:** drag widgets by their top handles, with optional grid snapping. Layout survives relaunch.
- **Weather you can touch:** click for layered rain and surface ripples, drifting snow, or sun rays. Effects last eight seconds and can be disabled.
- **Visible, controllable motion:** native 30 fps redraws, with separate battery/Low Power/Reduce Motion controls and an explicit pause reason. Dock, menu bar, both, or neither. Optional launch at login.

SimpleScreen uses its own desktop-level windows; it does not replace your saved macOS wallpaper or require Accessibility/Screen Recording access. Desktop icons and ordinary app windows remain separate.

## Install

Requires **macOS 14 Sonoma or later**, on Apple silicon or Intel.

1. Download `SimpleScreen-macOS.zip` from Releases.
2. Unzip and move SimpleScreen to Applications.
3. Open it. The app is **ad-hoc signed, not notarized**: no paid Apple developer membership is required to build it. macOS may block the downloaded app; after attempting to open it, use **System Settings → Privacy & Security → Open Anyway** if you trust the source. Do not disable Gatekeeper globally.
4. Choose a wallpaper. Under Widgets, add a widget, enable Arrange, and drag its handle.
5. Configure weather/AI under Connections only if you want them.

If you hide both Dock and menu bar icons, reopen SimpleScreen through Spotlight or Applications to access settings.

## Build in Xcode

Open **SimpleScreen.xcodeproj**, choose the shared **SimpleScreen** scheme, and Run. No package dependencies, project generators, API keys, provisioning profile, or development team needed. Xcode 16 or later is recommended.
The project generates its original glass-style icon during the build. Debug and Release both use ad-hoc signing.

```sh
xcodebuild -project SimpleScreen.xcodeproj -scheme SimpleScreen -configuration Release -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO -derivedDataPath build build
```

The app is at `build/Build/Products/Release/SimpleScreen.app`.

## Connections and custom widgets

- [Device batteries](docs/DEVICE-BATTERIES.md): connected accessories and what macOS can report.
- [AI usage setup](docs/AI-USAGE.md): local Codex snapshots and the opt-in Claude Code status-line helper.
- [HTML widget guide](docs/HTML-WIDGETS.md): self-contained HTML, CSS, and click interactions. HTTPS access is opt-in.
- Weather uses [Open-Meteo](https://open-meteo.com/) current conditions, attributed under CC BY 4.0. Search for your city or enter coordinates; automatic location is not requested.

## Privacy and behavior

Preferences and copied images are stored in `~/Library/Application Support/SimpleScreen/`. No analytics, account system, credential scraping, or telemetry.

Weather sends configured coordinates and requested weather variables to Open-Meteo; city searches go to its GeoNames-based geocoding service. Codex reading is opt-in and bounded to recent session-file tails; nothing is uploaded. The Claude helper extracts only rate-limit percentages/reset times. HTML uses an ephemeral WebKit data store, a restrictive content-security policy, blocked navigation, and no native script bridge.

AI values are **last recorded account snapshots**, not a promise of live remaining usage. Missing windows are not fabricated; readings older than 15 minutes and passed reset times are labeled. Reading Codex history may change if its file format changes.

Wallpaper settings currently apply to every display; widgets can be assigned separately. When a display disconnects, its widgets appear on the main display and return when it reconnects. Full-screen apps, Mission Control, and Stage Manager behavior is governed by macOS window management. Glass uses native Liquid Glass on macOS 26 when built with Xcode 26+, with native backdrop blur and translucent highlights on earlier macOS versions.

Weather effects are procedural visual effects, not photographic video. The Calendar widget shows the current week and opens Calendar; it does not read private events. Battery reports the Mac power source; Device Batteries adds connected Bluetooth accessories and separate AirPods components when macOS exposes them. iPhone/iPad/Apple Watch battery access is not universal. The Focus timer stores its end date, so it survives app relaunch.

## CI and releases

Every push and PR runs model/usage checks, all 64 wallpaper-palette render-and-motion combinations plus native desktop redraw/pause/resume checks, Python bridge and browser-media tests, real-release update preparation checks, Debug and universal Release builds, signature/architecture/icon validation, and live first-launch/all-29-widget window checks on macOS. A successful push to main publishes a versioned ZIP plus SHA-256 checksum. Increment the version in `SimpleScreen/Info.plist` and add matching notes under `releases/` for subsequent releases.

CI cannot establish behavior on every physical display, a real user's weather/network connection, real subscribed AI accounts, or all macOS window-management configurations. See [manual checks](docs/TESTING.md).

## Contribute

Small, thoughtful improvements welcome. Keep interactions accessible, avoid unnecessary permissions, preserve offline functionality, and clearly label unavailable data. Include relevant tests for changes to usage parsing, persistence, and layout. All wallpaper designs and icon artwork in this repository are original procedural artwork.
