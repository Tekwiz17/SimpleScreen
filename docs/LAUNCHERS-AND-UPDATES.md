# Launchers and updates

## App & Folder Launcher

Add the launcher widget, then Choose Apps & Folders. Search installed applications or Spotlight-indexed folders, filter Apps/Folders, or Browse to select a folder outside the index. Standard home folders appear without a search. Each launcher holds up to 36 items using their actual macOS icons. Configure columns, icon size, labels, item order, and custom labels. A one-item launcher works as a single shortcut button.

Saved file bookmarks help resolve moved items. Unavailable items report an error and can be selected again. Spotlight results depend on indexing and macOS access permissions.

## Updates

Open Updates in the sidebar or Check for Updates in the app/menu-bar menu. Opening the page checks the latest stable GitHub release and shows its improvements. If newer than your installed version, Update downloads and checks the ZIP's SHA-256 checksum, app identity, version, and code signature before installation.

The installer stages the new app beside your installed copy, waits for SimpleScreen to quit, replaces it, and opens it again. It retains the prior version as a hidden sibling backup and writes an Update.log in Application Support/SimpleScreen. Settings and imported images remain in Application Support.

If the installed location cannot be written, Show Download reveals the verified app for manual replacement. Install into Applications rather than running from a temporary/download preview location. Releases are ad-hoc signed, not notarized; the checksum and signature integrity checks are not a Developer ID identity guarantee.

The first version with this updater is 1.2.0; earlier versions need a manual download once. Checks happen when requested or when opening Updates, not in the background.
