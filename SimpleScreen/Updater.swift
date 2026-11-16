import AppKit
import SwiftUI
import CryptoKit

enum UpdateError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
enum UpdateWorker {
    static func command(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.message("Update validation failed. Your installed app was not changed.") }
        return String(decoding: data, as: UTF8.self)
    }
    static func unpack(archive: URL, expectedHash: String, version: String, directory: URL) throws -> URL {
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == expectedHash else { throw UpdateError.message("The download checksum did not match. Please retry.") }
        let listing = try command("/usr/bin/unzip", ["-Z", "-1", archive.path])
        guard UpdateValidation.safeArchivePaths(listing) else { throw UpdateError.message("The update archive contains unexpected paths.") }
        _ = try command("/usr/bin/ditto", ["-x", "-k", archive.path, directory.path])
        let app = directory.appendingPathComponent("SimpleScreen.app")
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == "dev.tekwiz.SimpleScreen",
              let actual = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              AppVersion(actual) == AppVersion(version) else { throw UpdateError.message("The update has an unexpected app identity or version.") }
        _ = try command("/usr/bin/codesign", ["--verify", "--strict", app.path])
        return app
    }
    static let installScript = #"""
    set -eu
    pid="$1"
    target="$2"
    staged="$3"
    backup="$4"
    counter=0
    while /bin/kill -0 "$pid" 2>/dev/null; do
      counter=$((counter + 1))
      if [ "$counter" -gt 30 ]; then echo "Update cancelled: SimpleScreen did not quit."; exit 1; fi
      /bin/sleep 1
    done
    if ! /bin/mv "$target" "$backup"; then
      echo "Could not replace installed copy."
      /usr/bin/open "$target" || true
      exit 1
    fi
    if ! /bin/mv "$staged" "$target"; then
      /bin/mv "$backup" "$target"
      /usr/bin/open "$target" || true
      echo "Update rolled back."
      exit 1
    fi
    if ! /usr/bin/open -n "$target"; then
      /bin/mv "$target" "$staged"
      /bin/mv "$backup" "$target"
      /usr/bin/open "$target" || true
      echo "Launch failed; update rolled back."
      exit 1
    fi
    echo "Updated successfully. Previous version retained at $backup"
    """#
}
@MainActor final class UpdateService: ObservableObject {
    @Published var release: AppRelease?
    @Published var busy = false
    @Published var message = "Check GitHub for the latest release."
    @Published var preparedApp: URL?
    @Published var checked = false
    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.0" }
    var available: Bool {
        guard let current = AppVersion(currentVersion), let latest = release?.version else { return false }
        return latest > current
    }
    func check() async {
        guard !busy else { return }
        busy = true; message = "Checking for updates…"
        defer { busy = false; checked = true }
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/Tekwiz17/SimpleScreen/releases/latest")!)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.message("GitHub could not return the latest release. Try again later.") }
            let latest = try JSONDecoder().decode(AppRelease.self, from: data)
            guard latest.version != nil, !latest.draft, !latest.prerelease,
                  latest.assetURL("SimpleScreen-macOS.zip") != nil, latest.assetURL("SHA256SUMS.txt") != nil else { throw UpdateError.message("The latest release is not ready to install.") }
            release = latest
            message = available ? "\(latest.tag_name) is ready. Review the improvements below." : "You're up to date."
        } catch { release = nil; message = error.localizedDescription }
    }
    func update() async {
        guard !busy, available, let release,
              let archiveURL = release.assetURL("SimpleScreen-macOS.zip"),
              let hashURL = release.assetURL("SHA256SUMS.txt") else { return }
        busy = true; message = "Downloading and verifying the update…"
        defer { busy = false }
        do {
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SimpleScreen/Updates/\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var hashRequest = URLRequest(url: hashURL); hashRequest.timeoutInterval = 30
            let (hashData, hashResponse) = try await URLSession.shared.data(for: hashRequest)
            guard (hashResponse as? HTTPURLResponse)?.statusCode == 200,
                  let expected = UpdateValidation.checksum(String(decoding: hashData, as: UTF8.self), filename: "SimpleScreen-macOS.zip") else { throw UpdateError.message("Could not verify this release's checksum.") }
            var downloadRequest = URLRequest(url: archiveURL); downloadRequest.timeoutInterval = 180
            let (temporary, response) = try await URLSession.shared.download(for: downloadRequest)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.message("The update download failed.") }
            let archive = folder.appendingPathComponent("download.zip")
            try FileManager.default.moveItem(at: temporary, to: archive)
            let version = release.tag_name
            let unpacked = try await Task.detached(priority: .userInitiated) {
                try UpdateWorker.unpack(archive: archive, expectedHash: expected, version: version, directory: folder)
            }.value
            preparedApp = unpacked
            message = "Installing… SimpleScreen will restart."
            try install(unpacked)
        } catch {
            message = error.localizedDescription
            if preparedApp != nil { message += " Use Show Download to replace the app manually." }
        }
    }
    private func install(_ downloaded: URL) throws {
        let target = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard target.pathExtension == "app", Bundle.main.bundleIdentifier == "dev.tekwiz.SimpleScreen" else {
            throw UpdateError.message("Run the installed app to update automatically.")
        }
        let parent = target.deletingLastPathComponent()
        let staged = parent.appendingPathComponent(".SimpleScreen-update-\(UUID().uuidString).app")
        let backup = parent.appendingPathComponent(".SimpleScreen-previous-\(UUID().uuidString).app")
        do { try FileManager.default.copyItem(at: downloaded, to: staged) }
        catch { try? FileManager.default.removeItem(at: staged); throw UpdateError.message("This app's folder is not writable.") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", UpdateWorker.installScript, "simplescreen-update", String(ProcessInfo.processInfo.processIdentifier), target.path, staged.path, backup.path]
        let logURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SimpleScreen").appendingPathComponent("Update.log")
        try FileManager.default.createDirectory(at: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SimpleScreen"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        process.standardOutput = log; process.standardError = log
        do { try process.run() } catch { try? FileManager.default.removeItem(at: staged); throw error }
        NSApp.terminate(nil)
    }
}
struct UpdatesView: View {
    @ObservedObject var updater: UpdateService
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 15) {
                Image(systemName: "arrow.down.app").font(.system(size: 34, weight: .light))
                VStack(alignment: .leading, spacing: 5) {
                    Text("SimpleScreen \(updater.currentVersion)").font(.title2.weight(.semibold))
                    Text(updater.message).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if updater.busy { ProgressView().controlSize(.small) }
            }
            HStack {
                Button("Check for Updates") { Task { await updater.check() } }.disabled(updater.busy)
                if updater.available {
                    Button("Update to \(updater.release?.tag_name ?? "")") { Task { await updater.update() } }
                        .buttonStyle(.borderedProminent).disabled(updater.busy)
                }
                if let url = updater.preparedApp { Button("Show Download") { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
                Spacer()
                Link("All releases ↗", destination: URL(string: "https://github.com/Tekwiz17/SimpleScreen/releases")!)
            }
            if let release = updater.release {
                Divider()
                Text("What's improved in \(release.tag_name)").font(.headline)
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array((release.body ?? "No release notes supplied.").components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        if line.hasPrefix("#") {
                            Text(line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))).font(.headline).padding(.top, 8)
                        } else if line.hasPrefix("- ") {
                            HStack(alignment: .top, spacing: 8) { Text("•"); Text(.init(String(line.dropFirst(2)))) }.font(.callout)
                        } else if !line.isEmpty { Text(.init(line)).font(.callout) }
                    }
                }.textSelection(.enabled)
            }
            Divider()
            Text("Updates come from this project's GitHub releases. The download checksum, app identity, version, and signature are checked before replacement. Your wallpapers and settings are kept. If this copy cannot be replaced, you can install the verified download manually.").font(.caption).foregroundStyle(.secondary)
        }.task { if !updater.checked { await updater.check() } }
    }
}
