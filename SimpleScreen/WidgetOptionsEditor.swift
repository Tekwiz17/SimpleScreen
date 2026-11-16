import SwiftUI

struct WidgetOptionsEditor: View {
    @Binding var widget: DesktopWidget
    @State private var newTask = ""
    @State private var newLink = ""
    @State private var newURL = "https://"
    @State private var zoneQuery = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Custom title (optional)", text: $widget.title)
            switch widget.kind {
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
