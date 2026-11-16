import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum LaunchResolver {
    static func url(_ item: LaunchItem) -> URL {
        if let data = item.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) { return url }
        }
        return URL(fileURLWithPath: item.path)
    }
    static func item(_ url: URL) -> LaunchItem? {
        let url = url.standardizedFileURL
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .localizedNameKey]), values.isDirectory == true else { return nil }
        let app = url.pathExtension.lowercased() == "app"
        guard app || values.isPackage != true else { return nil }
        let name = values.localizedName ?? url.lastPathComponent
        let label = app && name.lowercased().hasSuffix(".app") ? String(name.dropLast(4)) : name
        return LaunchItem(name: label, path: url.path, isApplication: app,
                          bookmark: try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil))
    }
    static func key(_ url: URL) -> String { url.standardizedFileURL.resolvingSymlinksInPath().path }
}
@MainActor final class LauncherIcons {
    static let shared = LauncherIcons()
    private let cache = NSCache<NSString, NSImage>()
    func image(path: String) -> NSImage {
        if let image = cache.object(forKey: path as NSString) { return image }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache.countLimit = 160
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}
struct LaunchCandidate: Identifiable {
    let path: String
    let name: String
    let application: Bool
    var id: String { path }
}
@MainActor final class LauncherSearch: ObservableObject {
    @Published var results: [LaunchCandidate] = []
    @Published var searching = false
    private var applications: [LaunchCandidate] = []
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var delay: Task<Void, Never>?
    private var text = ""
    private var filter = "All"
    private var indexed: [LaunchCandidate] = []
    func load() {
        Task {
            applications = await Task.detached(priority: .utility) { Self.scanApps() }.value
            publish()
        }
        search("", filter: "All")
    }
    nonisolated private static func scanApps() -> [LaunchCandidate] {
        let roots = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
        var found: [String: LaunchCandidate] = [:]
        for root in roots {
            let rootURL = URL(fileURLWithPath: root)
            guard let walker = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            var inspected = 0
            while let url = walker.nextObject() as? URL {
                inspected += 1
                if inspected > 6000 { break }
                if url.pathExtension.lowercased() == "app" {
                    found[LaunchResolver.key(url)] = .init(path: url.path, name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), application: true)
                    walker.skipDescendants()
                } else if walker.level > 3 { walker.skipDescendants() }
            }
        }
        return Array(found.values)
    }
    func search(_ text: String, filter: String) {
        self.text = text; self.filter = filter
        delay?.cancel(); stopQuery(); indexed = []
        publish()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { searching = false; return }
        searching = true
        delay = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self else { return }
            self.startQuery()
        }
    }
    private func startQuery() {
        let next = NSMetadataQuery()
        let application = NSPredicate(format: "kMDItemContentTypeTree == %@", "com.apple.application-bundle")
        let folders = NSPredicate(format: "kMDItemContentType == %@", "public.folder")
        let types = filter == "Apps" ? application : filter == "Folders" ? folders : NSCompoundPredicate(orPredicateWithSubpredicates: [application, folders])
        let name = NSPredicate(format: "kMDItemFSName CONTAINS[cd] %@", text)
        next.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [types, name])
        next.searchScopes = filter == "Apps" ? [NSMetadataQueryLocalComputerScope] : [NSHomeDirectory(), "/Applications", "/System/Applications"]
        next.notificationBatchingInterval = 0.2
        query = next
        for event in [NSMetadataQuery.didFinishGatheringNotification, NSMetadataQuery.didUpdateNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: event, object: next, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.collect() }
            })
        }
        if !next.start() { searching = false }
    }
    private func collect() {
        guard let query else { return }
        query.disableUpdates(); defer { query.enableUpdates() }
        indexed = []
        for index in 0..<min(300, query.resultCount) {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !path.contains("/.Trash/"), !path.contains("/Library/") else { continue }
            let app = path.lowercased().hasSuffix(".app")
            indexed.append(.init(path: path, name: FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""), application: app))
        }
        searching = false
        publish()
    }
    private func publish() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folders = [home] + ["Desktop", "Documents", "Downloads", "Pictures", "Music", "Movies", "Public"].map { home.appendingPathComponent($0) }
        var candidates = applications + indexed
        candidates += folders.filter { FileManager.default.fileExists(atPath: $0.path) }.map { .init(path: $0.path, name: $0 == home ? "Home" : $0.lastPathComponent, application: false) }
        var unique: [String: LaunchCandidate] = [:]
        for item in candidates where (filter == "All" || (filter == "Apps") == item.application) && SearchText.matches(text, in: item.name + " " + item.path) {
            unique[LaunchResolver.key(URL(fileURLWithPath: item.path))] = item
        }
        results = Array(unique.values).sorted {
            let left = $0.name.lowercased() == text.lowercased(), right = $1.name.lowercased() == text.lowercased()
            if left != right { return left }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    func stop() { delay?.cancel(); stopQuery() }
    private func stopQuery() {
        query?.stop(); query = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
    }
    deinit { query?.stop(); observers.forEach { NotificationCenter.default.removeObserver($0) } }
}
struct LauncherPicker: View {
    @ObservedObject var store: Store
    let widgetID: UUID
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = LauncherSearch()
    @State private var query = ""
    @State private var filter = "All"
    var items: [LaunchItem] { store.preferences.widgets.first { $0.id == widgetID }?.settings.launchItems ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your desktop, one click away.").font(.title2.weight(.semibold))
                    Text("Choose apps and folders for this launcher.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search apps or folders…", text: $query).textFieldStyle(.roundedBorder)
                if search.searching { ProgressView().controlSize(.small) }
            }
            Picker("Show", selection: $filter) { ForEach(["All", "Apps", "Folders"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(search.results.prefix(150)) { candidate in
                        Button { toggle(URL(fileURLWithPath: candidate.path)) } label: {
                            HStack(spacing: 12) {
                                Image(nsImage: LauncherIcons.shared.image(path: candidate.path)).resizable().interpolation(.high).frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.name).font(.system(size: 13, weight: .medium))
                                    Text(candidate.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Image(systemName: selected(candidate.path) ? "checkmark.circle.fill" : "plus.circle").foregroundStyle(Color.accentColor)
                            }.padding(10).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 11))
                        }.buttonStyle(.plain)
                    }
                    if search.results.isEmpty && !search.searching {
                        ContentUnavailableView("No matches", systemImage: "magnifyingglass", description: Text("Try another name, or browse for an app or folder."))
                    }
                }
            }
            HStack {
                Button("Browse…") { browse() }
                Text("\(items.count) selected").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Folders use Spotlight · Browse works without indexing").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(24).frame(width: 620, height: 590)
            .onAppear { search.load() }
            .onDisappear { search.stop() }
            .onChange(of: query) { _, _ in search.search(query, filter: filter) }
            .onChange(of: filter) { _, _ in search.search(query, filter: filter) }
    }
    private func selected(_ path: String) -> Bool {
        let key = LaunchResolver.key(URL(fileURLWithPath: path))
        return items.contains { LaunchResolver.key(LaunchResolver.url($0)) == key }
    }
    private func toggle(_ url: URL) {
        guard let item = LaunchResolver.item(url) else { store.error = "Choose an application or a folder."; return }
        store.updateOptions(widgetID) { options in
            var list = options.launchItems ?? []
            if let index = list.firstIndex(where: { LaunchResolver.key(LaunchResolver.url($0)) == LaunchResolver.key(url) }) { list.remove(at: index) }
            else if list.count < 36 { list.append(item) }
            options.launchItems = list
        }
    }
    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = true; panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !selected(url.path) { toggle(url) }
    }
}
struct LauncherWidgetView: View {
    @ObservedObject var store: Store
    let widget: DesktopWidget
    var items: [LaunchItem] { widget.settings.launchItems ?? [] }
    var body: some View {
        if items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "square.grid.2x2").font(.title)
                Text("Your favorite places.").font(.system(size: 16, weight: .medium))
                Button("Choose apps & folders…") {
                    store.selectedWidget = widget.id
                    store.requestedPage = "Widgets"
                    NotificationCenter.default.post(name: .openSimpleScreenSettings, object: nil)
                }.font(.system(size: 12, weight: .semibold))
            }
        } else {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: min(items.count, max(1, min(6, widget.settings.launcherColumns ?? 3)))), spacing: 16) {
                    ForEach(items) { item in
                        Button { launch(item) } label: {
                            VStack(spacing: 6) {
                                Image(nsImage: LauncherIcons.shared.image(path: LaunchResolver.url(item).path))
                                    .resizable().interpolation(.high).scaledToFit()
                                    .frame(width: widget.settings.launcherIconSize ?? 48, height: widget.settings.launcherIconSize ?? 48)
                                if widget.settings.launcherLabels ?? true {
                                    Text(item.name).font(widget.fontName == "System" ? .system(size: 11, weight: .medium) : .custom(widget.fontName, size: 11)).lineLimit(2).multilineTextAlignment(.center)
                                }
                            }.frame(maxWidth: .infinity).padding(5).contentShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).help("Open " + item.name).accessibilityLabel("Open " + item.name)
                    }
                }.padding(2)
            }
        }
    }
    private func launch(_ item: LaunchItem) {
        let url = LaunchResolver.url(item)
        guard FileManager.default.fileExists(atPath: url.path) else { store.error = "\(item.name) has moved or is unavailable. Choose it again in this widget's settings."; return }
        if item.isApplication {
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
                if let error { Task { @MainActor in store.error = "Could not open \(item.name): \(error.localizedDescription)" } }
            }
        } else if !NSWorkspace.shared.open(url) { store.error = "Could not open \(item.name)." }
    }
}
