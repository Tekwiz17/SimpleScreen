# Now Playing

Add Now Playing under Widgets. Choose Music, Spotify, Safari, Chrome, Edge, or Brave in its editor, then Connect. Connections are opt-in. Allow the requested macOS Automation permission. Disabled connections do not poll players. Playback is checked every five seconds while a connected widget uses that player.

Music and Spotify show track details and support play/pause, previous, and next. Spotify can provide album artwork; Music uses its app icon. Clicking the track opens the player.

## Browser audio

Enable your browser's **Allow JavaScript from Apple Events** option, then Retry in the widget. Consult your browser's developer menu/settings if the option is hidden. SimpleScreen also needs macOS Automation permission for that browser (System Settings → Privacy & Security → Automation).

Only accessible HTML5 audio/video in the current tab of the front browser window is supported. The widget uses page media-session metadata when supplied, otherwise the page title. Controls are play/pause and seek backward/forward ten seconds. Select the playing tab to display its media.

Cross-origin frames, closed shadow roots, private player implementations, and some protected media are unavailable. Browser autoplay rules may prevent playback until you click the page. This is not a system-wide audio capture feature and does not request microphone or screen-recording access.

Metadata stays local. Artwork is fetched from the HTTPS URL supplied by the player/page. Disconnect a source in its widget editor to stop reading it. Permission or script errors stop repeated requests until Retry.
