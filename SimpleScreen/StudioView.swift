import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

struct StudioView: View {
    @ObservedObject var store: Store
    @ObservedObject var services: Services
    @State private var page = "Wallpapers"
    @State private var widgetSearch = ""
    @State private var globalSearch = ""
    @StateObject private var updater = UpdateService()
    @State private var locationQuery = ""
    @State private var locations: [WeatherLocation] = []
    @State private var findingLocation = false
    @State private var locationStatus = ""
    @State private var login = SMAppService.mainApp.status == .enabled
    private let pages = [("Wallpapers", "paintpalette"), ("Widgets", "square.grid.2x2"), ("Connections", "link"), ("Settings", "slider.horizontal.3"), ("Updates", "arrow.down.circle")]
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(page).font(.system(size: 30, weight: .semibold, design: .rounded))
                            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Desktop", isOn: $store.preferences.enabled).toggleStyle(.switch).controlSize(.small).fixedSize()
                    }
                    if !globalSearch.trimmingCharacters(in: .whitespaces).isEmpty { searchResults }
                    else { switch page {
                    case "Wallpapers": wallpaperPage
                    case "Widgets": widgetPage
                    case "Connections": connections
                    case "Updates": UpdatesView(updater: updater)
                    default: settings
                    } }
                }.padding(32)
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 620)
        .tint(Color(hex: "398A91"))
        .sheet(isPresented: Binding(get: { !store.preferences.onboardingComplete }, set: { if !$0 { store.preferences.onboardingComplete = true } })) { welcome }
        .alert("SimpleScreen", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
        .onReceive(store.$requestedPage) { requested in
            guard let requested else { return }
            page = requested; globalSearch = ""; store.requestedPage = nil
        }
        .onChange(of: store.selectedWidget) { _, value in if value != nil { page = "Widgets"; globalSearch = "" } }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.on.rectangle").font(.system(size: 23, weight: .light))
                    .frame(width: 42, height: 42).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text("SimpleScreen").font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("A little more you.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.top, 22)
            TextField("Search SimpleScreen…", text: $globalSearch).textFieldStyle(.roundedBorder)
            VStack(spacing: 6) {
                ForEach(pages, id: \.0) { item in
                    Button { page = item.0; globalSearch = "" } label: {
                        HStack(spacing: 11) {
                            Image(systemName: item.1).frame(width: 19)
                            Text(item.0)
                            Spacer()
                        }.font(.system(size: 13, weight: page == item.0 ? .semibold : .regular))
                            .padding(.horizontal, 12).padding(.vertical, 11)
                            .background(page == item.0 ? Color.accentColor.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Label("Made to feel like yours.", systemImage: "sparkle").font(.system(size: 11)).foregroundStyle(.secondary)
                Link("Open source on GitHub ↗", destination: URL(string: "https://github.com/Tekwiz17/SimpleScreen")!).font(.system(size: 11))
                Text("SimpleScreen 1.2.0").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }.padding(18).frame(width: 204).background(.ultraThinMaterial)
    }
    private var subtitle: String {
        switch page {
        case "Wallpapers": return "Make a backdrop that feels like home."
        case "Widgets": return "Small things. Right where you want them."
        case "Connections": return "Useful information, with you in control."
        case "Updates": return "See what’s new. Keep your desktop up to date."
        default: return "Quietly working in the background."
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results for “\(globalSearch)”").font(.headline)
            ForEach(WidgetKind.allCases.filter { $0.matches(globalSearch) }) { kind in
                searchRow(kind.rawValue, detail: "Add desktop widget", symbol: kind.symbol) { store.add(kind); page = "Widgets"; globalSearch = "" }
            }
            ForEach(WallpaperStyle.allCases.filter { SearchText.matches(globalSearch, in: $0.rawValue + " wallpaper background motion animation") }) { style in
                searchRow(style.rawValue, detail: "Wallpaper design", symbol: "paintpalette") {
                    store.preferences.wallpaper.style = style
                    page = "Wallpapers"; globalSearch = ""
                    if style == .image && store.preferences.wallpaper.mediaPath == nil { store.importMedia() }
                }
            }
            ForEach(Palette.all.filter { SearchText.matches(globalSearch, in: $0.name + " palette colors") }) { palette in
                searchRow(palette.name, detail: "Wallpaper palette", symbol: "circle.lefthalf.filled") { store.preferences.wallpaper.colors = palette.colors; page = "Wallpapers"; globalSearch = "" }
            }
            ForEach([("Wallpapers", "wallpaper background animation battery low power reduce motion colors"), ("Widgets", "widgets arrange snap desktop"), ("Connections", "connections weather city codex claude usage"), ("Settings", "settings login dock menu bar privacy"), ("Updates", "update download release version improvements")], id: \.0) { entry in
                if SearchText.matches(globalSearch, in: entry.1) {
                    searchRow(entry.0, detail: "Open settings page", symbol: "arrow.right.circle") { page = entry.0; globalSearch = "" }
                }
            }
            Text("Try “apps”, “folders”, “music”, “timer”, “AirPods”, or “updates”.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func searchRow(_ title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 24).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 13, weight: .semibold)); Text(detail).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
            }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
    private var wallpaperPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack(alignment: .bottomLeading) {
                WallpaperView(wallpaper: store.preferences.wallpaper, animate: store.animate)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your everyday, reimagined.").font(.system(size: 26, weight: .light, design: .rounded))
                    Text("LIVE PREVIEW").font(.system(size: 9, weight: .semibold)).tracking(2).opacity(0.7)
                }.foregroundStyle(.white).padding(24).shadow(color: .black.opacity(0.25), radius: 10)
            }.frame(height: 235).clipShape(RoundedRectangle(cornerRadius: 22))
            sectionTitle("The collection", detail: "Original designs. Endless combinations.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                ForEach(WallpaperStyle.allCases) { style in
                    Button { store.preferences.wallpaper.style = style; if style == .image && store.preferences.wallpaper.mediaPath == nil { store.importMedia() } } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                if style == .image { Color.secondary.opacity(0.08); Image(systemName: "photo.badge.plus").font(.title2).foregroundStyle(.secondary) }
                                else { WallpaperCanvas(wallpaper: Wallpaper(style: style, colors: store.preferences.wallpaper.colors), time: 0) }
                            }.frame(height: 76).clipShape(RoundedRectangle(cornerRadius: 12))
                            HStack {
                                Text(style.rawValue).font(.system(size: 11, weight: .medium))
                                Spacer()
                                if store.preferences.wallpaper.style == style { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
                            }
                        }.padding(7).background(store.preferences.wallpaper.style == style ? Color.accentColor.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                }
            }
            if store.preferences.wallpaper.style == .image {
                card {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Bring your own view").font(.headline)
                            Text("Images and animated GIFs · copied into SimpleScreen").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Choose image or GIF…") { store.importMedia() }
                    }
                    Toggle("Fill the screen (crop edges)", isOn: $store.preferences.wallpaper.fill)
                }
            } else {
                sectionTitle("Find your palette", detail: "Start with a mood, then make it yours.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135))], spacing: 10) {
                    ForEach(Palette.all) { palette in
                        Button { store.preferences.wallpaper.colors = palette.colors } label: {
                            HStack(spacing: 8) {
                                HStack(spacing: -6) { ForEach(palette.colors, id: \.self) { color in Circle().fill(Color(hex: color)).frame(width: 20, height: 20).overlay(Circle().stroke(.white.opacity(0.3))) } }
                                Text(palette.name).font(.system(size: 11))
                                Spacer()
                            }.padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    }
                }
                HStack {
                    ForEach(store.preferences.wallpaper.colors.indices, id: \.self) { index in
                        ColorPicker("Color \(index + 1)", selection: Binding(get: { Color(hex: store.preferences.wallpaper.colors[index]) }, set: { store.preferences.wallpaper.colors[index] = $0.hex }), supportsOpacity: false)
                    }
                    if store.preferences.wallpaper.colors.count < 5 { Button { store.preferences.wallpaper.colors.append("E9D9C6") } label: { Image(systemName: "plus") }.help("Add a color") }
                    if store.preferences.wallpaper.colors.count > 2 { Button { store.preferences.wallpaper.colors.removeLast() } label: { Image(systemName: "minus") }.help("Remove last color") }
                }
                HStack { Text("Direction").font(.caption); Slider(value: $store.preferences.wallpaper.angle, in: 0...360); Text("\(Int(store.preferences.wallpaper.angle))°").font(.caption.monospacedDigit()).frame(width: 35) }
            }
            card {
                Toggle("Bring it to life", isOn: $store.preferences.wallpaper.animated)
                Toggle("Animate on battery", isOn: Binding(get: { !store.preferences.pauseOnBattery }, set: { store.preferences.pauseOnBattery = !$0 }))
                Toggle("Pause in Low Power Mode", isOn: Binding(get: { store.preferences.pauseInLowPower ?? true }, set: { store.preferences.pauseInLowPower = $0 }))
                Toggle("Respect Reduce Motion", isOn: Binding(get: { store.preferences.respectReduceMotion ?? true }, set: { store.preferences.respectReduceMotion = $0 }))
                HStack { Text("Gentle").font(.caption).foregroundStyle(.secondary); Slider(value: $store.preferences.wallpaper.speed, in: 0.05...1); Text("Lively").font(.caption).foregroundStyle(.secondary) }
                    .disabled(!store.preferences.wallpaper.animated || store.preferences.wallpaper.style == .image)
                Text(store.motionStatus).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var widgetPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Toggle("Arrange on desktop", isOn: $store.editing).toggleStyle(.switch)
                Spacer()
                Toggle("Snap to grid", isOn: $store.preferences.snap)
            }
            Text("Turn on Arrange, then drag a widget by its top handle. Click its sliders to edit. Widgets stay behind your apps.").font(.caption).foregroundStyle(.secondary)
            TextField("Search all 29 widgets", text: $widgetSearch).textFieldStyle(.roundedBorder)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                ForEach(WidgetKind.allCases.filter { $0.matches(widgetSearch) }) { kind in
                    Button { store.add(kind) } label: {
                        HStack {
                            Image(systemName: kind.symbol).frame(width: 20).foregroundStyle(Color.accentColor)
                            Text(kind.rawValue).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Image(systemName: "plus").font(.system(size: 10))
                        }.padding(14).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }
            if store.preferences.widgets.isEmpty {
                ContentUnavailableView("Room for something useful", systemImage: "square.dashed", description: Text("Add a clock, a quiet reminder, or something entirely your own."))
            } else {
                ForEach(store.preferences.widgets.filter { $0.kind.matches(widgetSearch) || SearchText.matches(widgetSearch, in: $0.title) }) { widget in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(widget.title.isEmpty ? widget.kind.rawValue : widget.title, systemImage: widget.kind.symbol).font(.headline)
                            Spacer()
                            Button(store.selectedWidget == widget.id ? "Done" : "Customize") { store.selectedWidget = store.selectedWidget == widget.id ? nil : widget.id }
                            Button(role: .destructive) { store.remove(widget.id) } label: { Image(systemName: "trash") }.help("Remove widget")
                        }
                        if store.selectedWidget == widget.id, let index = store.preferences.widgets.firstIndex(where: { $0.id == widget.id }) {
                            WidgetEditor(widget: $store.preferences.widgets[index], store: store)
                        }
                    }.padding(18).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    private var connections: some View {
        VStack(alignment: .leading, spacing: 20) {
            card {
                Label("Weather", systemImage: "cloud.sun").font(.headline)
                Toggle("Get current conditions from Open-Meteo", isOn: $store.preferences.weatherEnabled)
                Text("When enabled, your chosen coordinates go to Open-Meteo. Find city sends your search to its GeoNames-based location service. No location permission or API key required.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("Search city", text: $locationQuery, prompt: Text("City or postal code"))
                    Button(findingLocation ? "Searching…" : "Find city") {
                        findingLocation = true
                        Task {
                            defer { findingLocation = false }
                            do {
                                locations = try await LocationSearch.find(locationQuery)
                                locationStatus = locations.isEmpty ? "No matching places. Try city, state or country." : "Choose your location:"
                            } catch { locationStatus = "Search unavailable. You can enter coordinates below."; locations = [] }
                        }
                    }.disabled(findingLocation || locationQuery.trimmingCharacters(in: .whitespaces).count < 2 || !store.preferences.weatherEnabled)
                }
                if !locationStatus.isEmpty { Text(locationStatus).font(.caption).foregroundStyle(.secondary) }
                ForEach(locations) { location in
                    Button(location.label) {
                        store.preferences.city = location.name
                        store.preferences.latitude = location.latitude
                        store.preferences.longitude = location.longitude
                        locations = []
                        locationStatus = "Location updated"
                    }.buttonStyle(.link).font(.caption)
                }
                TextField("Location name", text: $store.preferences.city)
                HStack {
                    TextField("Latitude", value: $store.preferences.latitude, format: .number)
                    TextField("Longitude", value: $store.preferences.longitude, format: .number)
                    Toggle("°F", isOn: $store.preferences.fahrenheit).fixedSize()
                }
                Text("Use decimal coordinates, such as 40.71 and −74.01 for New York.").font(.caption).foregroundStyle(.secondary)
                Link("Weather data by Open-Meteo · CC BY 4.0 ↗", destination: URL(string: "https://open-meteo.com/")!).font(.caption)
            }
            card {
                Label("Codex", systemImage: "terminal").font(.headline)
                Toggle("Read local Codex usage snapshots", isOn: $store.preferences.codexEnabled)
                Text("Reads rate-limit events from ~/.codex/sessions. No credentials, prompts, or session content are uploaded. Usage updates after Codex records a new turn; old readings are labeled.").font(.caption).foregroundStyle(.secondary)
                Text(services.codex.windows.isEmpty ? services.codex.message : "Connected · \(services.codex.windows.count) usage windows").font(.caption)
            }
            card {
                Label("Claude Code", systemImage: "terminal").font(.headline)
                Text("Use the included status-line helper to save Claude's official rate-limit fields to a local JSON file. SimpleScreen never reads your Claude credentials.").font(.caption).foregroundStyle(.secondary)
                TextField("Path to usage JSON", text: $store.preferences.claudePath, prompt: Text("~/Library/Application Support/SimpleScreen/claude-usage.json"))
                Button("Use default snapshot path") { store.preferences.claudePath = Store.directory.appendingPathComponent("claude-usage.json").path }
                Link("Set up the Claude Code connection ↗", destination: URL(string: "https://github.com/Tekwiz17/SimpleScreen/blob/main/docs/AI-USAGE.md")!).font(.caption)
                Text(services.claude.message).font(.caption).foregroundStyle(.secondary)
            }
            Button("Refresh connections") { services.configure(store.preferences); Task { await services.refresh() } }
            Text("Missing usage data stays missing. SimpleScreen does not estimate your account allowance from token counts.").font(.caption).foregroundStyle(.secondary)
        }.textFieldStyle(.roundedBorder)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 20) {
            card {
                Label("Make yourself at home", systemImage: "macwindow").font(.headline)
                Picker("Show SimpleScreen in", selection: $store.preferences.presence) { ForEach(Presence.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Text("If you choose Neither, reopen SimpleScreen from Applications or Spotlight to return to settings.").font(.caption).foregroundStyle(.secondary)
                Toggle("Open at login", isOn: $login).onChange(of: login) { _, enabled in
                    do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                    catch { store.error = error.localizedDescription; login = SMAppService.mainApp.status == .enabled }
                }
                Toggle("Animate on battery", isOn: Binding(get: { !store.preferences.pauseOnBattery }, set: { store.preferences.pauseOnBattery = !$0 }))
                Toggle("Pause in Low Power Mode", isOn: Binding(get: { store.preferences.pauseInLowPower ?? true }, set: { store.preferences.pauseInLowPower = $0 }))
                Toggle("Respect Reduce Motion", isOn: Binding(get: { store.preferences.respectReduceMotion ?? true }, set: { store.preferences.respectReduceMotion = $0 }))
                Text(store.motionStatus).font(.caption).foregroundStyle(.secondary)
                HStack { Text("Snap spacing"); Slider(value: $store.preferences.grid, in: 8...48, step: 4); Text("\(Int(store.preferences.grid)) pt").font(.caption).frame(width: 40) }
            }
            card {
                Label("Your setup, kept locally", systemImage: "externaldrive").font(.headline)
                Text("Wallpapers, widgets, and preferences live on your Mac. No account, analytics, or tracking. Your original desktop wallpaper is left untouched and reappears when SimpleScreen quits.").font(.caption).foregroundStyle(.secondary)
                Button("Show saved files") { NSWorkspace.shared.open(Store.directory) }
            }
            card {
                Label("A smaller footprint", systemImage: "leaf").font(.headline)
                Text("Procedural animation uses a native 30 fps redraw timer. Images render without a repeating animation timer. GIFs use their own frame timings. Weather refreshes every 15 minutes; battery and connected usage refresh every minute.").font(.caption).foregroundStyle(.secondary)
                Text("Glass uses Liquid Glass on macOS 26 builds and native backdrop blur on earlier versions. Desktop effects work without Accessibility or Screen Recording access.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Link("MIT License", destination: URL(string: "https://github.com/Tekwiz17/SimpleScreen/blob/main/LICENSE")!)
                Spacer()
                Button("Quit SimpleScreen") { NSApp.terminate(nil) }
            }
        }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            WallpaperCanvas(wallpaper: Wallpaper(), time: 0).frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 20))
            Text("A little more you.").font(.system(size: 32, weight: .light, design: .rounded))
            Text("Welcome to SimpleScreen. Give your desktop a new mood, add a few useful things, and make space for your day.").foregroundStyle(.secondary)
            Label("Pick a backdrop and make its colors yours.", systemImage: "paintpalette")
            Label("Add widgets, then arrange them by their handles.", systemImage: "square.grid.2x2")
            Label("Everything stays local unless you enable a connection.", systemImage: "lock")
            Text("No Accessibility permission needed. Reopen the app any time to return here.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Make it mine") {
                    store.preferences.onboardingComplete = true
                    if store.preferences.widgets.isEmpty { store.add(.clock); store.editing = false; store.selectedWidget = nil; page = "Wallpapers" }
                }.buttonStyle(.borderedProminent).controlSize(.large)
            }
        }.padding(32).frame(width: 510)
    }
    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content).padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }
}
struct WidgetEditor: View {
    @Binding var widget: DesktopWidget
    @ObservedObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
            WidgetOptionsEditor(widget: $widget, store: store)
            HStack {
                Picker("Surface", selection: $widget.surface) { ForEach(WidgetSurface.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                ColorPicker("Text", selection: color(\.foreground), supportsOpacity: false).fixedSize()
                ColorPicker("Tint", selection: color(\.background), supportsOpacity: false).fixedSize()
            }
            HStack { Text("Opacity").font(.caption); Slider(value: $widget.opacity, in: 0.1...1) }.disabled(widget.surface == .clear)
            HStack {
                Picker("Font", selection: $widget.fontName) {
                    Text("System Rounded").tag("System")
                    ForEach(["Helvetica Neue", "Avenir Next", "Georgia", "Menlo", "Baskerville", "Futura"], id: \.self) { Text($0).tag($0) }
                }
                Text("Size").font(.caption)
                Slider(value: $widget.fontSize, in: 14...56, step: 1)
                Text("\(Int(widget.fontSize))").font(.caption).frame(width: 25)
            }
            HStack {
                Text("Width").font(.caption); Slider(value: $widget.width, in: 180...600, step: 20)
                Text("Height").font(.caption); Slider(value: $widget.height, in: 140...500, step: 20)
            }
            Picker("Display", selection: $widget.screenID) {
                if !NSScreen.screens.contains(where: { screenID($0) == widget.screenID }) { Text("Main display").tag(widget.screenID) }
                ForEach(NSScreen.screens, id: \.self) { screen in Text(screen.localizedName).tag(screenID(screen)) }
            }
            Toggle(widget.kind == .weather ? "Click for weather effects" : "Enable click interactions", isOn: $widget.interaction)
            if widget.kind == .weather { Text("Eight seconds of layered rain and ripples, drifting snow, or soft sunlight. Effects respect Reduce Motion and energy settings.").font(.caption).foregroundStyle(.secondary) }
            if widget.kind == .clock { Toggle("Show seconds", isOn: $widget.showSeconds) }
            if widget.kind == .note {
                TextField("Title", text: $widget.title)
                TextEditor(text: $widget.text).frame(height: 90).font(.body).padding(8).background(.background, in: RoundedRectangle(cornerRadius: 8))
            }
            if widget.kind == .focus { Stepper("Focus for \(widget.focusMinutes) minutes", value: $widget.focusMinutes, in: 1...120) }
            if widget.kind == .usage {
                Picker("Provider", selection: $widget.provider) { Text("Codex").tag("Codex"); Text("Claude Code").tag("Claude Code") }.pickerStyle(.segmented)
                Text("Set up the provider under Connections. Click the widget to refresh.").font(.caption).foregroundStyle(.secondary)
            }
            if widget.kind == .html {
                Text("Your HTML, CSS, and JavaScript").font(.headline)
                TextEditor(text: $widget.html).font(.system(size: 11, design: .monospaced)).frame(height: 180)
                HStack {
                    Button("Import HTML…") {
                        let panel = NSOpenPanel(); panel.allowedContentTypes = [.html]
                        guard panel.runModal() == .OK, let url = panel.url else { return }
                        do {
                            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                            guard size < 1_048_576 else { store.error = "Keep HTML widgets under 1 MB."; return }
                            widget.html = try String(contentsOf: url, encoding: .utf8)
                        } catch { store.error = error.localizedDescription }
                    }
                    Spacer()
                    Link("Widget guide ↗", destination: URL(string: "https://github.com/Tekwiz17/SimpleScreen/blob/main/docs/HTML-WIDGETS.md")!)
                }
                Toggle("Allow HTTPS resources and requests", isOn: $widget.networkAllowed)
                Text("Off by default. HTML runs in an isolated web view with no native bridge, file access, pop-ups, or navigation. Inline JavaScript can animate and respond to clicks.").font(.caption).foregroundStyle(.secondary)
            }
        }.textFieldStyle(.roundedBorder)
    }
    private func color(_ key: WritableKeyPath<DesktopWidget, String>) -> Binding<Color> {
        Binding(get: { Color(hex: widget[keyPath: key]) }, set: { widget[keyPath: key] = $0.hex })
    }
}
