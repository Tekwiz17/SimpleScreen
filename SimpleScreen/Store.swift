import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor final class Store: ObservableObject {
    @Published var preferences: Preferences
    @Published var editing = false
    @Published var selectedWidget: UUID?
    @Published var error: String?
    @Published var sleeping = false
    @Published var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    let services = Services()
    var onChange: (() -> Void)?
    private var saveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SimpleScreen", isDirectory: true)
    }
    init() {
        let url = Self.directory.appendingPathComponent("Preferences.json")
        var initial = Preferences()
        var loadError: String?
        if FileManager.default.fileExists(atPath: url.path) {
            do { initial = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url)) }
            catch { loadError = "Settings could not be read. Your original settings were preserved as Preferences.backup.json."
                try? FileManager.default.copyItem(at: url, to: Self.directory.appendingPathComponent("Preferences.backup.json"))
            }
        }
        preferences = initial
        error = loadError
        $preferences.dropFirst().sink { [weak self] _ in
            guard let self else { return }
            self.saveTask?.cancel()
            self.saveTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, let self else { return }
                self.save()
                self.onChange?()
            }
        }.store(in: &cancellables)
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = true }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = false; self?.onChange?() }
        }
    }
    var animate: Bool {
        preferences.enabled && !sleeping && !lowPower && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && !(preferences.pauseOnBattery && services.onBattery)
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences).write(to: Self.directory.appendingPathComponent("Preferences.json"), options: .atomic)
        } catch { self.error = "Could not save settings: \(error.localizedDescription)" }
    }
    func add(_ kind: WidgetKind) {
        var widget = DesktopWidget(kind: kind)
        widget.screenID = NSScreen.main.map(screenID) ?? ""
        widget.x += Double(preferences.widgets.count % 5) * 30
        widget.y += Double(preferences.widgets.count % 5) * 30
        if kind == .usage { widget.height = 220; widget.width = 280 }
        if kind == .html { widget.width = 300; widget.height = 200 }
        preferences.widgets.append(widget)
        selectedWidget = widget.id
        editing = true
        onChange?()
    }
    func update(_ id: UUID, _ change: (inout DesktopWidget) -> Void) {
        guard let index = preferences.widgets.firstIndex(where: { $0.id == id }) else { return }
        change(&preferences.widgets[index])
    }
    func remove(_ id: UUID) {
        preferences.widgets.removeAll { $0.id == id }
        if selectedWidget == id { selectedWidget = nil }
    }
    func importMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 100 * 1024 * 1024 else { throw ImportError.tooLarge }
            guard NSImage(contentsOf: url) != nil else { throw ImportError.invalid }
            let folder = Self.directory.appendingPathComponent("Media")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
            try FileManager.default.copyItem(at: url, to: destination)
            preferences.wallpaper.mediaPath = destination.path
            preferences.wallpaper.style = .image
        } catch { self.error = error.localizedDescription }
    }
    enum ImportError: LocalizedError {
        case tooLarge, invalid
        var errorDescription: String? { self == .tooLarge ? "Choose an image or GIF smaller than 100 MB." : "This file is not a supported image." }
    }
}
func screenID(_ screen: NSScreen) -> String {
    let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    return number?.stringValue ?? screen.localizedName
}
