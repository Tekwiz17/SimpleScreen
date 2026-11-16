# Device batteries

Add **Device Batteries** in Widgets. No account or pairing changes are performed. Pair/connect accessories normally in macOS first.

SimpleScreen reads the Mac's internal power source via IOKit, and connected accessories from the local `/usr/sbin/system_profiler SPBluetoothDataType -json -detailLevel mini` report. Only this public local report is used; no private iCloud endpoints, tokens, or credential stores are accessed.

Supported readings depend on what macOS publishes: AirPods may include left, right, and case; keyboards, mice, trackpads, and headphones may expose a main battery. A connected accessory without a reading shows “Not reported by macOS.” Disconnected entries are excluded. Names and addresses are used in memory to distinguish devices and are not uploaded or saved as a history.

The Mac battery row is separate from UPS/external power sources. Desktop Macs show AC power instead of a fabricated battery level.

Bluetooth discovery runs only while a Device Batteries widget exists, at most every two minutes unless you press Refresh. Scans run off the main thread with a timeout and no overlapping process. Failed scans clear accessory readings and display an unavailable status.

iPhone, iPad, and Apple Watch battery levels are not universally exposed to third-party macOS apps. This version does not claim support for devices absent from macOS's connected-accessory report.

CI validates realistic report fixtures, missing/invalid values, component separation, and disconnected-device filtering. Physical accessory discovery still needs testing with your actual Mac and devices.