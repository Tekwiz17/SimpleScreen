import SwiftUI
import AppKit

extension Notification.Name {
    static let openSimpleScreenSettings = Notification.Name("openSimpleScreenSettings")
    static let openSimpleScreenUpdates = Notification.Name("openSimpleScreenUpdates")
}
struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
struct DesktopWidgetView: View {
    @ObservedObject var store: Store
    @ObservedObject var services: Services
    let id: UUID
    let effect: (String) -> Void
    var widget: DesktopWidget? { store.preferences.widgets.first { $0.id == id } }
    var body: some View {
        if let widget {
            ZStack {
                surface(widget)
                VStack(alignment: .leading, spacing: 8) {
                    if store.editing {
                        HStack {
                            Image(systemName: "line.3.horizontal")
                            Text(widget.kind.rawValue).font(.caption.weight(.medium))
                            Spacer()
                            Button { store.selectedWidget = id; store.requestedPage = "Widgets"; NotificationCenter.default.post(name: .openSimpleScreenSettings, object: nil) } label: { Image(systemName: "slider.horizontal.3") }
                                .buttonStyle(.plain).help("Edit widget")
                        }
                        .overlay(alignment: .leading) { DragHandle(enabled: true).padding(.trailing, 28) }
                    }
                    content(widget)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(widget.interaction && !store.editing)
                }
                .padding(widget.kind == .html && !store.editing ? 0 : 18)
            }
            .foregroundStyle(Color(hex: widget.foreground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(store.editing ? Color.accentColor.opacity(0.8) : .white.opacity(widget.surface == .clear ? 0 : 0.22), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .font(widget.fontName == "System" ? .system(size: widget.fontSize, weight: .medium, design: .rounded) : .custom(widget.fontName, size: widget.fontSize))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(widget.kind.rawValue)
        }
    }
    @ViewBuilder private func surface(_ w: DesktopWidget) -> some View {
        switch w.surface {
        case .glass:
            WidgetGlass(tint: Color(hex: w.background), opacity: w.opacity)
        case .solid: Color(hex: w.background).opacity(w.opacity)
        case .clear: Color.clear
        }
    }
    @ViewBuilder private func content(_ w: DesktopWidget) -> some View {
        switch w.kind {
        case .clock:
            TimelineView(.periodic(from: .now, by: 1)) { tick in
                VStack(alignment: .leading, spacing: 6) {
                    Text(tick.date, format: w.showSeconds ? .dateTime.hour().minute().second() : .dateTime.hour().minute())
                        .font(clockFont(w)).monospacedDigit().minimumScaleFactor(0.4).lineLimit(1)
                    Text(tick.date, format: .dateTime.weekday(.wide).month(.abbreviated).day()).font(.system(size: 13, weight: .medium)).opacity(0.7)
                }.contentShape(Rectangle()).onTapGesture { store.update(id) { $0.showSeconds.toggle() } }
            }
        case .weather:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(store.preferences.city).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: services.weather?.symbol ?? "cloud").symbolRenderingMode(.hierarchical)
                }
                if let weather = services.weather {
                    Text("\(Int(weather.temperature.rounded()))°").font(clockFont(w))
                    HStack {
                        Text(weather.description)
                        Spacer()
                        Text(store.preferences.fahrenheit ? "°F" : "°C")
                    }.font(.system(size: 12)).opacity(0.7)
                    if Date().timeIntervalSince(weather.date) > 1800 { Text("Last reading · offline").font(.system(size: 10)).opacity(0.6) }
                } else { Text(services.weatherStatus).font(.system(size: 13)) }
            }.contentShape(Rectangle()).onTapGesture { if let weather = services.weather { effect(weather.effect) } }
        case .battery:
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: services.onBattery ? "battery.75percent" : "bolt.fill")
                    Text(services.onBattery ? "On battery" : "Connected").font(.system(size: 12))
                }.opacity(0.7)
                Text(services.battery.map { "\($0)%" } ?? "AC").font(clockFont(w))
                if let battery = services.battery {
                    ProgressView(value: Double(battery), total: 100).tint(battery < 20 ? .orange : Color(hex: w.foreground))
                }
            }.contentShape(Rectangle()).onTapGesture {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") { NSWorkspace.shared.open(url) }
            }
        case .calendar:
            TimelineView(.periodic(from: .now, by: 60)) { tick in
                VStack(alignment: .leading, spacing: 8) {
                    Text(tick.date, format: .dateTime.month(.wide).year()).font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 0) {
                        ForEach(0..<7) { day in
                            let date = Calendar.current.date(byAdding: .day, value: day - (Calendar.current.component(.weekday, from: tick.date) - Calendar.current.firstWeekday + 7) % 7, to: tick.date)!
                            VStack(spacing: 7) {
                                Text(date, format: .dateTime.weekday(.narrow)).opacity(0.6)
                                Text(date, format: .dateTime.day()).fontWeight(Calendar.current.isDateInToday(date) ? .bold : .regular)
                                    .padding(5).background(Calendar.current.isDateInToday(date) ? Color.white.opacity(0.2) : .clear, in: Circle())
                            }.font(.system(size: 12)).frame(maxWidth: .infinity)
                        }
                    }
                }.contentShape(Rectangle()).onTapGesture {
                    if let url = URL(string: "ical://") { NSWorkspace.shared.open(url) }
                }
            }
        case .focus:
            TimelineView(.periodic(from: .now, by: 1)) { tick in
                let remaining = w.focusEnd.map { max(0, Int($0.timeIntervalSince(tick.date).rounded(.up))) } ?? w.focusMinutes * 60
                VStack(alignment: .leading, spacing: 10) {
                    Text(remaining == 0 ? "A little breathing room." : "One thing at a time.").font(.system(size: 12)).opacity(0.7)
                    Text(String(format: "%02d:%02d", remaining / 60, remaining % 60)).font(clockFont(w)).monospacedDigit()
                    HStack {
                        Button(w.focusEnd == nil ? "Begin focus" : "Reset") {
                            store.update(id) { $0.focusEnd = $0.focusEnd == nil ? Date().addingTimeInterval(Double($0.focusMinutes * 60)) : nil }
                        }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if remaining == 0 { Image(systemName: "checkmark.circle") }
                    }
                }
            }
        case .note:
            VStack(alignment: .leading, spacing: 10) {
                Text(w.title.isEmpty ? "A small reminder" : w.title).font(.system(size: 11, weight: .semibold)).textCase(.uppercase).tracking(1.2).opacity(0.6)
                Text(w.text).font(w.fontName == "System" ? .system(size: min(w.fontSize, 26), weight: .medium, design: .serif) : .custom(w.fontName, size: w.fontSize))
                    .minimumScaleFactor(0.5)
            }.contentShape(Rectangle()).onTapGesture {
                store.selectedWidget = id; store.requestedPage = "Widgets"; NotificationCenter.default.post(name: .openSimpleScreenSettings, object: nil)
            }
        case .usage: usage(w)
        case .html: HTMLWidget(html: w.html, networkAllowed: w.networkAllowed)
        default: ExtraWidgetView(store: store, services: services, widget: w)
        }
    }
    private func clockFont(_ w: DesktopWidget) -> Font {
        w.fontName == "System" ? .system(size: w.fontSize * 1.65, weight: .light, design: .rounded) : .custom(w.fontName, size: w.fontSize * 1.65)
    }
    private func usage(_ w: DesktopWidget) -> some View {
        let snapshot = w.provider == "Codex" ? services.codex : services.claude
        return VStack(alignment: .leading, spacing: 12) {
            HStack { Text(w.provider).font(.system(size: 13, weight: .semibold)); Spacer(); Image(systemName: "chart.bar.xaxis").font(.system(size: 13)) }
            if snapshot.windows.isEmpty {
                Text(snapshot.message).font(.system(size: 12)).opacity(0.7)
            } else {
                ForEach(Array(snapshot.windows.enumerated()), id: \.offset) { _, window in
                    let expired = window.reset.map { $0 < Date() } ?? false
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(window.label)
                            Spacer()
                            Text("\(Int(window.remaining.rounded()))% left")
                        }.font(.system(size: 12, weight: .medium))
                        ProgressView(value: window.remaining, total: 100).tint(Color(hex: w.foreground))
                        if let reset = window.reset {
                            HStack(spacing: 3) {
                                Text(expired ? "Reset passed · awaiting update" : "Resets")
                                if !expired { Text(reset, style: .relative) }
                            }.font(.system(size: 10)).opacity(0.6)
                        }
                    }
                }
                HStack(spacing: 3) {
                    Circle().fill(snapshot.stale ? .orange : .green).frame(width: 5, height: 5)
                    Text(snapshot.stale ? "Older snapshot" : "Local snapshot")
                    if let date = snapshot.captured { Text(date, style: .relative) }
                }.font(.system(size: 10)).opacity(0.65)
            }
        }.contentShape(Rectangle()).onTapGesture { Task { await services.refresh() } }
    }
}

struct WidgetGlass: View {
    let tint: Color
    let opacity: Double
    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular.tint(tint.opacity(opacity * 0.35)), in: RoundedRectangle(cornerRadius: 24))
        } else {
            fallback
        }
        #else
        fallback
        #endif
    }
    private var fallback: some View {
        ZStack {
            GlassBackground()
            LinearGradient(colors: [.white.opacity(0.14), tint.opacity(opacity * 0.35), .white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
