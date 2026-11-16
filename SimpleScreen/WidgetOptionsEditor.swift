import SwiftUI

struct WidgetOptionsEditor: View {
    @Binding var widget: DesktopWidget
    @ObservedObject var store: Store
    @State private var showLauncherPicker = false
    @State private var newTask = ""
    @State private var newLink = ""
    @State private var newURL = "https://"
    @State private var zoneQuery = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Custom title (optional)", text: $widget.title)
            switch widget.kind {
            case .launcher: launcherEditor
            case .nowPlaying: playerEditor
            case .worldClock: zoneEditor
            case .analog: Toggle("Show second hand", isOn: $widget.showSeconds)
            case .countdown: DatePicker("Count down to", selection: option(\.targetDate))
            case .checklist: taskEditor
            case .links: linkEditor
            case .water: Stepper("Daily goal: \(widget.settings.goal) glasses", value: option(\.goal), in: 1...24)
            case .habit: Text("Give this habit a title above. Tap its desktop widget to mark today complete. Your last seven days appear below it.").font(.caption).foregroundStyle(.secondary)
            case .color: ColorPicker("Your color", selection: Binding(get: { Color(hex: widget.settings.colorHex) }, set: { color in set { $0.colorHex = color.hex } }), supportsOpacity: false)
            case .dice:
                Stepper("Dice: \(widget.settings.diceCount)", value: option(\.diceCount), in: 1...4)
                Picker("Sides", selection: option(\.diceSides)) { ForEach([4, 6, 8, 10, 12, 20, 100], id: \.self) { Text("d\($0)").tag($0) } }
            case .batteries:
                Text("Mac + connected Bluetooth accessories. AirPods left, right, and case readings appear separately when macOS reports them. Refreshes every two minutes, or click Refresh.").font(.caption).foregroundStyle(.secondary)
                Text("iPhone, iPad, Apple Watch, and accessories that do not publish battery data are not universally readable from a Mac. Missing values stay unavailable.").font(.caption).foregroundStyle(.secondary)
            case .memory: Text("An estimate based on macOS VM counters, excluding free, inactive, and speculative pages. Click to open Activity Monitor.").font(.caption).foregroundStyle(.secondary)
            case .breathing: Text("Four seconds in, four seconds hold, six seconds out. Start/stop from the widget. Circle motion follows your motion settings.").font(.caption).foregroundStyle(.secondary)
            default: EmptyView()
            }
        }.sheet(isPresented: $showLauncherPicker) { LauncherPicker(store: store, widgetID: widget.id) }
    }

    private var launcherEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Search apps & folders…") { showLauncherPicker = true }.buttonStyle(.borderedProminent)
            ForEach(Array((widget.settings.launchItems ?? []).enumerated()), id: \.element.id) { index, item in
                HStack {
                    Image(nsImage: LauncherIcons.shared.image(path: LaunchResolver.url(item).path)).resizable().scaledToFit().frame(width: 28, height: 28)
                    TextField("Label", text: Binding(get: { widget.settings.launchItems?.first { $0.id == item.id }?.name ?? item.name }, set: { value in
                        set { options in if let found = options.launchItems?.firstIndex(where: { $0.id == item.id }) { options.launchItems?[found].name = value } }
                    }))
                    Button { set { $0.launchItems?.swapAt(index, index - 1) } } label: { Image(systemName: "arrow.up") }.disabled(index == 0).help("Move earlier")
                    Button { set { $0.launchItems?.swapAt(index, index + 1) } } label: { Image(systemName: "arrow.down") }.disabled(index + 1 == (widget.settings.launchItems?.count ?? 0)).help("Move later")
                    Button(role: .destructive) { set { $0.launchItems?.removeAll { $0.id == item.id } } } label: { Image(systemName: "minus.circle") }.help("Remove shortcut")
                }
            }
            Stepper("Columns: \(widget.settings.launcherColumns ?? 3)", value: Binding(get: { widget.settings.launcherColumns ?? 3 }, set: { value in set { $0.launcherColumns = value } }), in: 1...6)
            HStack {
                Text("Icon size").font(.caption)
                Slider(value: Binding(get: { widget.settings.launcherIconSize ?? 48 }, set: { value in set { $0.launcherIconSize = value } }), in: 28...96, step: 4)
                Text("\(Int(widget.settings.launcherIconSize ?? 48)) pt").font(.caption)
            }
            Toggle("Show labels", isOn: Binding(get: { widget.settings.launcherLabels ?? true }, set: { value in set { $0.launcherLabels = value } }))
            Text("Use one item for a large app/folder button, or several for a launcher grid. App and folder icons come directly from macOS.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var playerEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Player", selection: Binding(get: { widget.settings.mediaSource ?? MediaSource.music.rawValue }, set: { value in set { $0.mediaSource = value } })) {
                ForEach(MediaSource.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
            }
            let source = MediaSource(rawValue: widget.settings.mediaSource ?? "") ?? .music
            let connected = (store.preferences.connectedPlayers ?? []).contains(source.rawValue)
            Button(connected ? "Disconnect \(source.rawValue)" : "Connect \(source.rawValue)") {
                var values = store.preferences.connectedPlayers ?? []
                if connected { values.removeAll { $0 == source.rawValue } } else { values.append(source.rawValue) }
                store.preferences.connectedPlayers = values
                store.services.nowPlaying.configure(store.preferences)
                if !connected { store.services.nowPlaying.retry(source) }
            }
            Text("Reads local track information and sends playback commands only after you connect. macOS may request Automation access. Disconnect affects all widgets using this player.").font(.caption).foregroundStyle(.secondary)
            if source.browser {
                Text("Current tab only: enable “Allow JavaScript from Apple Events” in the browser's developer menu. Play/pause and ±10-second seeking work with accessible HTML5 media. Cross-origin embedded players, browser restrictions, and some streaming sites may prevent access.").font(.caption).foregroundStyle(.secondary)
                Link("Browser setup guide ↗", destination: URL(string: "https://github.com/Tekwiz17/SimpleScreen/blob/main/docs/NOW-PLAYING.md")!)
            }
        }
    }
    private var zoneEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Filter time zones", text: $zoneQuery)
            Picker("Time zone", selection: option(\.timeZone)) {
                ForEach(TimeZone.knownTimeZoneIdentifiers.filter { zoneQuery.isEmpty || $0.localizedCaseInsensitiveContains(zoneQuery) || $0 == widget.settings.timeZone }, id: \.self) { zone in
                    Text(zone.replacingOccurrences(of: "_", with: " ")).tag(zone)
                }
            }
            Toggle("Show seconds", isOn: $widget.showSeconds)
        }
    }
    private var taskEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(widget.settings.items) { item in
                HStack {
                    TextField("Task", text: Binding(get: { widget.settings.items.first { $0.id == item.id }?.title ?? "" }, set: { title in set { options in if let index = options.items.firstIndex(where: { $0.id == item.id }) { options.items[index].title = title } } }))
                    Button(role: .destructive) { set { $0.items.removeAll { $0.id == item.id } } } label: { Image(systemName: "minus.circle") }
                }
            }
            HStack {
                TextField("New task", text: $newTask)
                Button("Add") { set { $0.items.append(.init(title: newTask.trimmingCharacters(in: .whitespaces))) }; newTask = "" }
                    .disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty || widget.settings.items.count >= 50)
            }
            Button("Uncheck all") { set { options in for index in options.items.indices { options.items[index].done = false } } }
        }
    }
    private var linkEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(widget.settings.links) { link in
                HStack {
                    Text(link.title).frame(width: 90, alignment: .leading)
                    Text(link.url).font(.caption).lineLimit(1).foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) { set { $0.links.removeAll { $0.id == link.id } } } label: { Image(systemName: "minus.circle") }
                }
            }
            HStack {
                TextField("Title", text: $newLink)
                TextField("https://…", text: $newURL)
                Button("Add") { set { $0.links.append(.init(title: newLink, url: newURL)) }; newLink = ""; newURL = "https://" }
                    .disabled(newLink.isEmpty || WidgetMath.safeURL(newURL) == nil || widget.settings.links.count >= 30)
            }
        }
    }
    private func option<Value>(_ key: WritableKeyPath<WidgetOptions, Value>) -> Binding<Value> {
        Binding(get: { widget.settings[keyPath: key] }, set: { value in set { $0[keyPath: key] = value } })
    }
    private func set(_ transform: (inout WidgetOptions) -> Void) {
        var options = widget.settings; transform(&options); widget.options = options
    }
}
