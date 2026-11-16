import SwiftUI
import AppKit

struct ExtraWidgetView: View {
    @ObservedObject var store: Store
    @ObservedObject var services: Services
    let widget: DesktopWidget
    @State private var calculator = CalculatorState()
    @State private var rolls: [Int] = [1, 1]
    @State private var breathing = false
    @State private var breathStart = Date()
    @State private var copied = false
    var settings: WidgetOptions { widget.settings }
    var accent: Color { Color(hex: widget.foreground) }
    var largeFont: Font { widget.fontName == "System" ? .system(size: widget.fontSize * 1.35, weight: .light, design: .rounded) : .custom(widget.fontName, size: widget.fontSize * 1.35) }
    var body: some View {
        Group {
            switch widget.kind {
            case .launcher: LauncherWidgetView(store: store, widget: widget)
            case .nowPlaying: NowPlayingWidgetView(store: store, media: services.nowPlaying, widget: widget)
            case .batteries: batteries
            case .worldClock: worldClock
            case .analog: analog
            case .countdown: countdown
            case .stopwatch: stopwatch
            case .checklist: checklist
            case .habit: habit
            case .water: water
            case .breathing: breath
            case .quote: quote
            case .dayProgress: dayProgress
            case .storage: storage
            case .memory: memory
            case .uptime: uptime
            case .links: links
            case .calculator: calculatorView
            case .dice: dice
            case .color: colorStudio
            case .weatherDetails: weatherDetails
            default: EmptyView()
            }
        }.font(.system(size: 12)).buttonStyle(.plain)
    }
    private func heading(_ fallback: String, symbol: String) -> some View {
        HStack { Text(widget.title.isEmpty ? fallback : widget.title).font(.system(size: 12, weight: .semibold)); Spacer(); Image(systemName: symbol) }.opacity(0.75)
    }
    private func edit(_ transform: (inout WidgetOptions) -> Void) { store.updateOptions(widget.id, transform) }
    private var batteries: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Device batteries").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { Task { await services.refreshDevices(force: true) } } label: { Image(systemName: "arrow.clockwise") }.help("Refresh connected devices")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(services.devices) { device in
                        HStack(spacing: 10) {
                            Image(systemName: device.symbol).font(.system(size: 20)).frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                if !device.component.isEmpty { Text(device.component).font(.system(size: 10)).opacity(0.6) }
                                if let percent = device.percent { ProgressView(value: Double(percent), total: 100).tint(percent < 20 ? .orange : accent) }
                            }
                            Spacer(minLength: 4)
                            VStack {
                                Text(device.percent.map { "\($0)%" } ?? "—").monospacedDigit().font(.system(size: 13, weight: .medium))
                                if device.charging == true { Image(systemName: "bolt.fill").font(.system(size: 9)) }
                            }
                        }
                    }
                }
            }
            Text(services.deviceStatus).font(.system(size: 9)).opacity(0.6).lineLimit(2)
            if let updated = services.deviceUpdated { Text("Updated \(updated.formatted(date: .omitted, time: .shortened))").font(.system(size: 9)).opacity(0.5) }
        }
    }
    private var worldClock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tick in
            let zone = TimeZone(identifier: settings.timeZone) ?? .current
            VStack(alignment: .leading, spacing: 8) {
                heading(settings.timeZone.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? "World Clock", symbol: "globe")
                Text(clockString(tick.date, zone: zone)).font(largeFont).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                Text(dayString(tick.date, zone: zone)).font(.system(size: 11)).opacity(0.65)
            }
        }
    }
    private func clockString(_ date: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone; formatter.dateStyle = .none
        formatter.timeStyle = widget.showSeconds ? .medium : .short
        return formatter.string(from: date)
    }
    private func dayString(_ date: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone; formatter.dateStyle = .medium
        return formatter.string(from: date) + " · " + (zone.abbreviation(for: date) ?? zone.identifier)
    }
    private var analog: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tick in
            AnalogFace(date: tick.date, color: accent, seconds: widget.showSeconds)
                .contentShape(Rectangle()).onTapGesture { store.update(widget.id) { $0.showSeconds.toggle() } }
        }
    }
    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tick in
            let seconds = max(0, settings.targetDate.timeIntervalSince(tick.date))
            VStack(alignment: .leading, spacing: 8) {
                heading("Something to look forward to", symbol: "calendar.badge.clock")
                Text(seconds >= 86400 ? "\(Int(ceil(seconds / 86400))) days" : seconds > 0 ? duration(seconds) : "It's time.").font(largeFont).lineLimit(1).minimumScaleFactor(0.4)
                Text(settings.targetDate, format: .dateTime.month().day().hour().minute()).font(.system(size: 11)).opacity(0.6)
            }
        }
    }
    private var stopwatch: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { tick in
            VStack(alignment: .leading, spacing: 12) {
                heading("A little time", symbol: "stopwatch")
                Text(duration(WidgetMath.stopwatch(settings, at: tick.date))).font(largeFont).monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
                HStack {
                    Button(settings.startedAt == nil ? "Start" : "Pause") {
                        edit { options in
                            if options.startedAt != nil { options.elapsed = WidgetMath.stopwatch(options, at: Date()); options.startedAt = nil }
                            else { options.startedAt = Date() }
                        }
                    }
                    Spacer()
                    Button("Reset") { edit { $0.elapsed = 0; $0.startedAt = nil } }
                }.font(.system(size: 12, weight: .semibold))
            }
        }
    }
    private var checklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("One thing at a time", symbol: "checklist")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(settings.items) { item in
                        Button {
                            edit { options in if let index = options.items.firstIndex(where: { $0.id == item.id }) { options.items[index].done.toggle() } }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                Text(item.title).strikethrough(item.done).opacity(item.done ? 0.5 : 1).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            Text("\(settings.items.filter(\.done).count) of \(settings.items.count) complete").font(.system(size: 10)).opacity(0.55)
        }
    }
    private var habit: some View {
        TimelineView(.periodic(from: .now, by: 30)) { tick in
            let key = WidgetMath.dayKey(tick.date)
            let done = settings.completedDays.contains(key)
            VStack(alignment: .leading, spacing: 14) {
                heading("Show up for yourself", symbol: "checkmark.seal")
                Button {
                    edit {
                        if done { $0.completedDays.removeAll { $0 == key } }
                        else { $0.completedDays.append(key); $0.completedDays = Array($0.completedDays.suffix(366)) }
                    }
                } label: {
                    HStack { Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 36)); Text(done ? "Done today" : "Mark today").font(.system(size: 17, weight: .medium)) }
                }
                HStack(spacing: 6) {
                    ForEach(0..<7) { offset in
                        let date = Calendar.current.date(byAdding: .day, value: offset - 6, to: tick.date)!
                        VStack(spacing: 5) {
                            Circle().fill(accent.opacity(settings.completedDays.contains(WidgetMath.dayKey(date)) ? 0.9 : 0.13)).frame(width: 18, height: 18)
                            Text(date, format: .dateTime.weekday(.narrow)).font(.system(size: 9))
                        }.frame(maxWidth: .infinity)
                    }
                }
                Text("Your last seven days").font(.system(size: 10)).opacity(0.55)
            }
        }
    }
    private var water: some View {
        TimelineView(.periodic(from: .now, by: 30)) { tick in
            let count = WidgetMath.dailyCount(settings, at: tick.date)
            VStack(alignment: .leading, spacing: 10) {
                heading("A sip, then another", symbol: "drop.fill")
                HStack(alignment: .firstTextBaseline) { Text("\(count)").font(largeFont); Text("/ \(settings.goal) glasses").opacity(0.6) }
                ProgressView(value: Double(min(count, settings.goal)), total: Double(max(1, settings.goal))).tint(accent)
                HStack {
                    Button("−") { changeWater(-1) }.font(.title2)
                    Spacer()
                    Text("Resets each day").font(.system(size: 10)).opacity(0.6)
                    Spacer()
                    Button("+") { changeWater(1) }.font(.title2)
                }
            }
        }
    }
    private func changeWater(_ delta: Int) {
        edit { options in options.count = min(99, max(0, WidgetMath.dailyCount(options, at: Date()) + delta)); options.dayKey = WidgetMath.dayKey(Date()) }
    }
    private var breath: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { tick in
            let phase = tick.date.timeIntervalSince(breathStart).truncatingRemainder(dividingBy: 14)
            let amount = phase < 4 ? phase / 4 : phase < 8 ? 1 : 1 - (phase - 8) / 6
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(accent.opacity(0.15), lineWidth: 1)
                    Circle().fill(accent.opacity(0.2)).scaleEffect(breathing && store.animate ? 0.45 + amount * 0.5 : 0.7)
                    Text(!breathing ? "A quiet minute" : phase < 4 ? "Breathe in" : phase < 8 ? "Hold" : "Breathe out").font(.system(size: 16, weight: .light))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                Button(breathing ? "Finish" : "Begin") { breathStart = Date(); breathing.toggle() }.font(.system(size: 12, weight: .semibold))
            }
        }
    }
    private var quote: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tick in
            let day = Calendar.current.ordinality(of: .day, in: .era, for: tick.date) ?? 0
            let thoughts = ["Leave a little room for wonder.", "Small steps still change the view.", "You do not have to fill every quiet moment.", "Make something you would like to find.", "A fresh start can be very small.", "Give the next thing your full attention.", "Slow is a perfectly good speed.", "There is more than one way to have a good day.", "Notice what is already working.", "Rest belongs in the plan.", "Keep the useful. Make space for the lovely.", "Begin before it feels like the perfect moment."]
            VStack(alignment: .leading, spacing: 12) {
                heading("A thought for today", symbol: "quote.opening")
                Text(thoughts[(day + max(0, settings.count)) % thoughts.count]).font(.system(size: min(24, widget.fontSize), weight: .medium, design: .serif)).minimumScaleFactor(0.6)
                Text("Tap for another").font(.system(size: 9)).opacity(0.45)
            }.contentShape(Rectangle()).onTapGesture { edit { $0.count = ($0.count + 1) % thoughts.count } }
        }
    }
    private var dayProgress: some View {
        TimelineView(.periodic(from: .now, by: 30)) { tick in
            VStack(alignment: .leading, spacing: 12) {
                heading("Make room for today", symbol: "sun.horizon")
                progressRow("Today", value: WidgetMath.progress(tick.date, component: .day))
                progressRow("This week", value: WidgetMath.progress(tick.date, component: .weekOfYear))
                progressRow("This year", value: WidgetMath.progress(tick.date, component: .year))
            }
        }
    }
    private func progressRow(_ title: String, value: Double) -> some View {
        VStack(spacing: 4) {
            HStack { Text(title); Spacer(); Text("\(Int(value * 100))%").monospacedDigit() }.font(.system(size: 11))
            ProgressView(value: value).tint(accent)
        }
    }
    private var storage: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Room to make things", symbol: "externaldrive")
            Text(bytes(services.machine.diskFree)).font(largeFont).lineLimit(1).minimumScaleFactor(0.4)
            Text("free of \(bytes(services.machine.diskTotal))").opacity(0.6)
            if services.machine.diskTotal > 0 { ProgressView(value: services.machine.diskTotal - services.machine.diskFree, total: services.machine.diskTotal).tint(accent) }
        }.contentShape(Rectangle()).onTapGesture { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser) }
    }
    private var memory: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Memory", symbol: "memorychip")
            Text(bytes(services.machine.memoryUsed)).font(largeFont).lineLimit(1).minimumScaleFactor(0.4)
            Text("active estimate · \(bytes(services.machine.memoryTotal)) total").font(.system(size: 10)).opacity(0.6)
            if services.machine.memoryTotal > 0 { ProgressView(value: services.machine.memoryUsed, total: services.machine.memoryTotal).tint(accent) }
        }.contentShape(Rectangle()).onTapGesture {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") { NSWorkspace.shared.open(url) }
        }
    }
    private var uptime: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let seconds = ProcessInfo.processInfo.systemUptime
            VStack(alignment: .leading, spacing: 10) {
                heading("Up and running", symbol: "power")
                Text("\(Int(seconds / 86400))d \(Int(seconds / 3600) % 24)h").font(largeFont).monospacedDigit()
                Text("\(Int(seconds / 60) % 60) minutes · since this Mac booted").font(.system(size: 11)).opacity(0.6)
            }
        }
    }
    private var links: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("A few favorite places", symbol: "link")
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(settings.links) { link in
                        Button {
                            if let url = WidgetMath.safeURL(link.url) { NSWorkspace.shared.open(url) }
                        } label: {
                            HStack { Text(link.title); Spacer(); Image(systemName: "arrow.up.right").opacity(0.5) }
                        }.disabled(WidgetMath.safeURL(link.url) == nil)
                    }
                }
            }
        }
    }
    private var calculatorView: some View {
        VStack(spacing: 8) {
            Text(calculator.display).font(largeFont).monospacedDigit().lineLimit(1).minimumScaleFactor(0.3).frame(maxWidth: .infinity, alignment: .trailing)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
                ForEach(["C", "±", "%", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "0", ".", "⌫", "="], id: \.self) { key in
                    Button { calculator.press(key) } label: {
                        Text(key).font(.system(size: 16, weight: .medium)).frame(maxWidth: .infinity).frame(height: 28)
                            .background(accent.opacity(key == "=" ? 0.3 : 0.08), in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
        }
    }
    private var dice: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Let chance have a turn", symbol: "dice")
            HStack { ForEach(Array(rolls.enumerated()), id: \.offset) { _, value in Text("\(value)").font(largeFont).frame(maxWidth: .infinity).padding(5).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)) } }
            HStack {
                Text("Total \(rolls.reduce(0, +))").opacity(0.6)
                Spacer()
                Button("Roll \(settings.diceCount)d\(settings.diceSides)") { rolls = (0..<max(1, min(4, settings.diceCount))).map { _ in Int.random(in: 1...max(2, settings.diceSides)) } }
            }
        }
    }
    private var colorStudio: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 14).fill(Color(hex: settings.colorHex)).frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text("#" + settings.colorHex).font(.system(size: 17, weight: .medium, design: .monospaced))
                Spacer()
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString("#" + settings.colorHex, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }
            }
            Button("Use in wallpaper") { if store.preferences.wallpaper.colors.isEmpty { store.preferences.wallpaper.colors = [settings.colorHex, "FFFFFF"] } else { store.preferences.wallpaper.colors[0] = settings.colorHex } }
        }
    }
    private var weatherDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading(store.preferences.city, symbol: "thermometer.sun")
            if let weather = services.weather {
                Text("\(Int(weather.temperature.rounded()))°").font(largeFont)
                metric("Feels like", value: weather.feelsLike.map { "\(Int($0.rounded()))°" } ?? "—", icon: "thermometer")
                metric("Humidity", value: weather.humidity.map { "\(Int($0))%" } ?? "—", icon: "humidity")
                metric("Wind", value: weather.wind.map { String(format: "%.0f km/h", $0) } ?? "—", icon: "wind")
                Text(services.weatherStatus).font(.system(size: 9)).opacity(0.6)
            } else { Text(services.weatherStatus).opacity(0.6) }
        }
    }
    private func metric(_ title: String, value: String, icon: String) -> some View {
        HStack { Image(systemName: icon).frame(width: 18); Text(title).opacity(0.7); Spacer(); Text(value).monospacedDigit() }
    }
    private func duration(_ seconds: Double) -> String {
        let value = Int(min(999_999_999, max(0, seconds)))
        return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
    }
    private func bytes(_ value: Double) -> String { ByteCountFormatter.string(fromByteCount: Int64(max(0, value)), countStyle: .binary) }
}
struct AnalogFace: View {
    let date: Date
    let color: Color
    let seconds: Bool
    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
    }
    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2 - 8
        guard radius > 0 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for index in 0..<60 {
            let angle = Double(index) * .pi / 30
            let length: CGFloat = index % 5 == 0 ? 10 : 4
            let start = point(center, angle: angle, radius: radius - length)
            let end = point(center, angle: angle, radius: radius)
            var path = Path(); path.move(to: start); path.addLine(to: end)
            context.stroke(path, with: .color(color.opacity(index % 5 == 0 ? 0.9 : 0.3)), lineWidth: index % 5 == 0 ? 2 : 1)
        }
        let values = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let second = Double(values.second ?? 0)
        let minute = Double(values.minute ?? 0) + second / 60
        let hour = Double((values.hour ?? 0) % 12) + minute / 60
        hand(&context, center: center, angle: hour * .pi / 6, radius: radius * 0.5, width: 5)
        hand(&context, center: center, angle: minute * .pi / 30, radius: radius * 0.75, width: 3)
        if seconds { hand(&context, center: center, angle: second * .pi / 30, radius: radius * 0.82, width: 1) }
        context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(color))
    }
    private func point(_ center: CGPoint, angle: Double, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + CGFloat(sin(angle)) * radius, y: center.y - CGFloat(cos(angle)) * radius)
    }
    private func hand(_ context: inout GraphicsContext, center: CGPoint, angle: Double, radius: CGFloat, width: CGFloat) {
        var path = Path(); path.move(to: center); path.addLine(to: point(center, angle: angle, radius: radius))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
