import AppKit
import IOKit.ps
import Combine

struct WeatherReading {
    var temperature: Double
    var code: Int
    var date: Date
    var symbol: String {
        switch code {
        case 0, 1: return "sun.max.fill"
        case 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.rain.fill"
        }
    }
    var description: String {
        switch code {
        case 0, 1: return "Clear skies"
        case 2, 3: return "Cloudy"
        case 45, 48: return "Misty"
        case 71...77, 85, 86: return "Snow"
        case 95...99: return "Thunderstorms"
        default: return "Rain"
        }
    }
    var effect: String {
        switch code {
        case 0...3: return "sun"
        case 71...77, 85, 86: return "snow"
        default: return "rain"
        }
    }
}
@MainActor final class Services: ObservableObject {
    @Published var battery: Int?
    @Published var onBattery = false
    @Published var weather: WeatherReading?
    @Published var weatherStatus = "Enable weather in Settings"
    @Published var codex = UsageSnapshot()
    @Published var claude = UsageSnapshot()
    private var task: Task<Void, Never>?
    private var weatherTask: Task<Void, Never>?
    private var weatherKey = ""
    private var lastWeather = Date.distantPast
    private var config = Preferences()
    init() {
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }
    func configure(_ preferences: Preferences) {
        config = preferences
        let key = "\(config.weatherEnabled):\(config.latitude):\(config.longitude):\(config.fahrenheit)"
        if key != weatherKey {
            weatherKey = key
            weatherTask?.cancel()
            weather = nil
            lastWeather = .distantPast
            weatherTask = Task { [weak self] in await self?.refreshWeather() }
        }
        if !config.codexEnabled { codex = UsageSnapshot() }
    }
    func refresh() async {
        readBattery()
        await refreshWeather()
        let enabled = config.codexEnabled
        let path = config.claudePath
        let result = await Task.detached(priority: .utility) { () -> (UsageSnapshot, UsageSnapshot) in
            (enabled ? LocalUsage.codex() : UsageSnapshot(), LocalUsage.claude(path: path))
        }.value
        if config.codexEnabled == enabled { codex = result.0 }
        if config.claudePath == path { claude = result.1 }
    }
    private func readBattery() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }
        battery = nil; onBattery = false
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            battery = Int(Double(current) / Double(maximum) * 100)
            onBattery = description[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
            return
        }
    }
    private func refreshWeather() async {
        guard config.weatherEnabled else { weather = nil; weatherStatus = "Enable weather in Settings"; return }
        guard Date().timeIntervalSince(lastWeather) > 900 else { return }
        let key = weatherKey
        let latitude = config.latitude, longitude = config.longitude
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { weatherStatus = "Check coordinates"; return }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)), .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,weather_code"),
            .init(name: "temperature_unit", value: config.fahrenheit ? "fahrenheit" : "celsius")
        ]
        weatherStatus = "Updating…"
        do {
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            struct Response: Decodable {
                struct Current: Decodable { let temperature_2m: Double; let weather_code: Int }
                let current: Current
            }
            let value = try JSONDecoder().decode(Response.self, from: data)
            guard !Task.isCancelled, key == weatherKey else { return }
            weather = .init(temperature: value.current.temperature_2m, code: value.current.weather_code, date: Date())
            weatherStatus = "Open-Meteo"
            lastWeather = Date()
        } catch {
            guard !Task.isCancelled, key == weatherKey else { return }
            weatherStatus = weather == nil ? "Weather unavailable · retrying" : "Offline · last reading"
        }
    }
}
enum LocalUsage {
    static func tail(_ url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > 2_097_152 ? size - 2_097_152 : 0)
        return try? handle.readToEnd()
    }
    static func codex() -> UsageSnapshot {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return UsageSnapshot(message: "No Codex sessions found")
        }
        var files: [(URL, Date)] = []
        var count = 0
        while let url = enumerator.nextObject() as? URL {
            count += 1
            if count > 30_000 { break }
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]), values.isRegularFile == true else { continue }
            files.append((url, values.contentModificationDate ?? .distantPast))
        }
        var latest: UsageSnapshot?
        for (url, date) in files.sorted(by: { $0.1 > $1.1 }).prefix(12) {
            guard let data = tail(url), let text = String(data: data, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n").reversed() {
                guard line.contains("\"rate_limits\""),
                      let snapshot = UsageParser.parse(Data(line.utf8), provider: "Codex", captured: date) else { continue }
                if latest == nil || (snapshot.captured ?? .distantPast) > (latest?.captured ?? .distantPast) { latest = snapshot }
                break
            }
        }
        return latest ?? UsageSnapshot(message: "Run a Codex turn to record usage")
    }
    static func claude(path: String) -> UsageSnapshot {
        guard !path.isEmpty else { return UsageSnapshot(message: "Connect Claude status line in Settings") }
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              (values.fileSize ?? 0) <= 1_048_576,
              let data = try? Data(contentsOf: url),
              let result = UsageParser.parse(data, provider: "Claude Code", captured: values.contentModificationDate ?? .distantPast) else {
            return UsageSnapshot(message: "Waiting for Claude usage snapshot")
        }
        return result
    }
}
