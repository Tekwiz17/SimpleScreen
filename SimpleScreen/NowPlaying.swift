import SwiftUI
import AppKit
import Darwin

enum MediaBridge {
    private static let queue = DispatchQueue(label: "dev.tekwiz.SimpleScreen.media", qos: .utility)
    static func request(_ source: MediaSource, action: MediaAction = .read) async -> NowPlayingSnapshot? {
        await withCheckedContinuation { continuation in
            queue.async {
                let process = Process()
                let output = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-l", "JavaScript", "-e", script, source.bundleID, action.rawValue, source == .safari ? "safari" : source.browser ? "chrome" : "native"]
                process.standardOutput = output; process.standardError = FileHandle.nullDevice
                do { try process.run() } catch { continuation.resume(returning: nil); return }
                let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                let killTask = DispatchWorkItem { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
                DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: timeout)
                DispatchQueue.global().asyncAfter(deadline: .now() + 17, execute: killTask)
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                timeout.cancel(); killTask.cancel()
                continuation.resume(returning: process.terminationStatus == 0 && data.count < 1_048_576 ? NowPlayingSnapshot.decode(data) : nil)
            }
        }
    }
    // Source and action come only from enums, never user-entered script text.
    static let script = #"""
    function run(argv) {
      var id = argv[0], action = argv[1], kind = argv[2];
      var empty = {title:"",artist:"",album:"",state:"stopped",position:0,duration:0,artwork:null,error:null};
      try {
        var app = Application(id);
        if (!app.running()) return JSON.stringify(empty);
        if (kind !== "native") {
          if (!app.windows.length) return JSON.stringify(empty);
          var browserCode = "(" + browserMedia.toString() + ")(" + JSON.stringify(action) + ")";
          var result;
          if (kind === "safari") result = app.doJavaScript(browserCode, {in:app.windows[0].currentTab});
          else result = app.windows[0].activeTab.execute({javascript:browserCode});
          return typeof result === "string" ? result : JSON.stringify(empty);
        }
        if (action === "toggle") app.playpause();
        if (action === "next") app.nextTrack();
        if (action === "previous") app.previousTrack();
        var state = String(app.playerState());
        if (state === "stopped") return JSON.stringify(empty);
        var track = app.currentTrack();
        var duration = Number(track.duration()) || 0;
        if (id === "com.spotify.client") duration /= 1000;
        return JSON.stringify({title:String(track.name() || ""),artist:String(track.artist() || ""),
          album:String(track.album() || ""),state:state,position:Number(app.playerPosition()) || 0,
          duration:duration,artwork:id === "com.spotify.client" ? String(track.artworkUrl() || "") : null,error:null});
      } catch (e) {
        empty.error = String(e); return JSON.stringify(empty);
      }
    }
    function browserMedia(action) {
      var empty = {title:"",artist:"",album:"",state:"stopped",position:0,duration:0,artwork:null,error:null};
      try {
        var elements = Array.from(document.querySelectorAll("audio, video"));
        // Same-origin frames only. Cross-origin/private player internals are not inspected.
        document.querySelectorAll("iframe").forEach(function(frame) {
          try { elements = elements.concat(Array.from(frame.contentDocument.querySelectorAll("audio,video"))); } catch (_) {}
        });
        var media = elements.find(function(e) { return !e.paused && !e.ended; }) ||
                    elements.find(function(e) { return e.currentTime > 0 && e.readyState > 0; }) ||
                    elements.find(function(e) { return e.readyState > 0; });
        if (!media) { empty.error = "No accessible audio or video in the current tab."; return JSON.stringify(empty); }
        if (action === "toggle") {
          if (media.paused) {
            var play = media.play();
            if (play && play.catch) play.catch(function(){});
          } else media.pause();
        }
        if (action === "next" && isFinite(media.duration)) media.currentTime = Math.min(media.duration, media.currentTime + 10);
        if (action === "previous") media.currentTime = Math.max(0, media.currentTime - 10);
        var metadata = navigator.mediaSession && navigator.mediaSession.metadata;
        var art = metadata && metadata.artwork && metadata.artwork.length ? metadata.artwork[metadata.artwork.length-1].src : null;
        return JSON.stringify({title:metadata && metadata.title || document.title || "Browser audio",
          artist:metadata && metadata.artist || location.hostname,album:metadata && metadata.album || "Current tab",
          state:media.paused ? "paused" : "playing",position:Number(media.currentTime)||0,
          duration:isFinite(media.duration) ? Number(media.duration) : 0,artwork:art,error:null});
      } catch (e) { empty.error = String(e); return JSON.stringify(empty); }
    }
    """#
}
@MainActor final class NowPlayingService: ObservableObject {
    @Published var snapshots: [MediaSource: NowPlayingSnapshot] = [:]
    @Published var statuses: [MediaSource: String] = [:]
    @Published var timestamps: [MediaSource: Date] = [:]
    @Published var working = Set<MediaSource>()
    private var enabled = Set<MediaSource>()
    private var blocked = Set<MediaSource>()
    private var task: Task<Void, Never>?
    func configure(_ preferences: Preferences) {
        let connected = Set((preferences.connectedPlayers ?? []).compactMap(MediaSource.init(rawValue:)))
        let used = Set(preferences.widgets.filter { $0.kind == .nowPlaying }.map { MediaSource(rawValue: $0.settings.mediaSource ?? "") ?? .music })
        let active = connected.intersection(used)
        guard active != enabled else { return }
        enabled = active
        task?.cancel()
        guard !enabled.isEmpty else { snapshots = [:]; return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                for source in self.enabled.sorted(by: { $0.rawValue < $1.rawValue }) {
                    if Task.isCancelled { return }
                    await self.refresh(source)
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
    func retry(_ source: MediaSource) {
        blocked.remove(source)
        Task { await refresh(source) }
    }
    func command(_ source: MediaSource, action: MediaAction) {
        guard enabled.contains(source), !working.contains(source) else { return }
        working.insert(source)
        Task {
            let result = await MediaBridge.request(source, action: action)
            working.remove(source)
            accept(result, source: source)
        }
    }
    private func refresh(_ source: MediaSource) async {
        guard enabled.contains(source), !blocked.contains(source), !working.contains(source) else { return }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).isEmpty else {
            snapshots.removeValue(forKey: source)
            statuses[source] = "Open \(source.rawValue) and start playback."
            return
        }
        let result = await MediaBridge.request(source)
        guard enabled.contains(source) else { return }
        accept(result, source: source)
    }
    private func accept(_ result: NowPlayingSnapshot?, source: MediaSource) {
        guard enabled.contains(source) else { return }
        guard let result else {
            snapshots.removeValue(forKey: source); blocked.insert(source)
            statuses[source] = "Player did not respond. Check permissions, then Retry."
            return
        }
        if let error = result.error, !error.isEmpty {
            snapshots.removeValue(forKey: source)
            let lower = error.lowercased()
            if lower.contains("no accessible audio") {
                statuses[source] = "Play audio or video in this browser's current tab."
            } else {
                blocked.insert(source)
                statuses[source] = source.browser ? "Allow Automation and JavaScript from Apple Events for \(source.rawValue), then Retry." : "Allow \(source.rawValue) in System Settings → Privacy & Security → Automation, then Retry."
            }
            return
        }
        snapshots[source] = result
        timestamps[source] = Date()
        statuses[source] = result.title.isEmpty ? "Nothing playing in \(source.rawValue)." : (source.browser ? "Current tab · HTML5 media" : source.rawValue)
    }
}
struct NowPlayingWidgetView: View {
    @ObservedObject var store: Store
    @ObservedObject var media: NowPlayingService
    let widget: DesktopWidget
    var source: MediaSource { MediaSource(rawValue: widget.settings.mediaSource ?? "") ?? .music }
    var connected: Bool { (store.preferences.connectedPlayers ?? []).contains(source.rawValue) }
    var snapshot: NowPlayingSnapshot? { media.snapshots[source] }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(widget.title.isEmpty ? "Now Playing" : widget.title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(source.rawValue).font(.system(size: 10)).opacity(0.6)
            }
            if connected, let track = snapshot, !track.title.isEmpty {
                trackView(track)
            } else {
                HStack(spacing: 12) {
                    appIcon.frame(width: 48, height: 48)
                    Text(connected ? media.statuses[source] ?? "Connecting…" : "Connect \(source.rawValue) to show and control playback.").font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                }
                if !connected {
                    Button("Connect \(source.rawValue)") {
                        var players = store.preferences.connectedPlayers ?? []
                        if !players.contains(source.rawValue) { players.append(source.rawValue) }
                        store.preferences.connectedPlayers = players
                        media.configure(store.preferences); media.retry(source)
                    }.font(.system(size: 12, weight: .semibold))
                } else {
                    HStack {
                        Button("Open \(source.rawValue)") { openPlayer() }
                        Spacer()
                        Button("Retry") { media.retry(source) }
                    }.font(.system(size: 12, weight: .semibold))
                }
                if source.browser { Text("Current tab only. Enable “Allow JavaScript from Apple Events” in your browser.").font(.system(size: 9)).opacity(0.6) }
            }
        }.buttonStyle(.plain)
    }
    private var appIcon: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) {
                Image(nsImage: LauncherIcons.shared.image(path: url.path)).resizable().scaledToFit()
            } else { Image(systemName: source.browser ? "globe" : "music.note").resizable().scaledToFit().padding(12) }
        }
    }
    private func trackView(_ track: NowPlayingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                AsyncImage(url: track.validArtworkURL) { image in image.resizable().scaledToFit() } placeholder: { appIcon }
                    .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title).font(.system(size: 16, weight: .semibold)).lineLimit(2)
                    Text(track.artist).font(.system(size: 12)).opacity(0.7).lineLimit(1)
                    Text(track.album).font(.system(size: 10)).opacity(0.5).lineLimit(1)
                }
            }.contentShape(Rectangle()).onTapGesture { openPlayer() }
            TimelineView(.periodic(from: .now, by: 1)) { tick in
                let elapsed = track.playing ? max(0, tick.date.timeIntervalSince(media.timestamps[source] ?? tick.date)) : 0
                let position = min(track.duration, track.position + elapsed)
                VStack(spacing: 4) {
                    ProgressView(value: position, total: max(1, track.duration)).tint(Color(hex: widget.foreground))
                    HStack { Text(time(position)); Spacer(); Text(track.duration > 0 ? time(track.duration) : "Live") }.font(.system(size: 9, design: .monospaced)).opacity(0.6)
                }
            }
            HStack(spacing: 28) {
                Spacer()
                Button { media.command(source, action: .previous) } label: { Image(systemName: source.browser ? "gobackward.10" : "backward.end.fill") }.help(source.browser ? "Back 10 seconds" : "Previous track")
                Button { media.command(source, action: .toggle) } label: { Image(systemName: track.playing ? "pause.fill" : "play.fill").font(.system(size: 23)) }.help("Play or pause")
                Button { media.command(source, action: .next) } label: { Image(systemName: source.browser ? "goforward.10" : "forward.end.fill") }.help(source.browser ? "Forward 10 seconds" : "Next track")
                Spacer()
            }.disabled(media.working.contains(source))
        }
    }
    private func time(_ seconds: Double) -> String { let value = Int(min(9_999_999, max(0, seconds))); return String(format: "%d:%02d", value / 60, value % 60) }
    private func openPlayer() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else { store.error = "\(source.rawValue) is not installed."; return }
        NSWorkspace.shared.open(url)
    }
}
