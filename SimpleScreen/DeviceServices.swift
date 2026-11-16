import Foundation
import AppKit
import IOKit.ps
import Darwin

struct MachineSnapshot {
    var batteries: [DeviceBattery] = []
    var macPercent: Int?
    var onBattery = false
    var diskTotal: Double = 0
    var diskFree: Double = 0
    var memoryTotal: Double = 0
    var memoryUsed: Double = 0
}
enum MachineReader {
    static func read() -> MachineSnapshot {
        var result = MachineSnapshot()
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for (index, source) in list.enumerated() {
                guard let item = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                      let current = item[kIOPSCurrentCapacityKey] as? Double,
                      let maximum = item[kIOPSMaxCapacityKey] as? Double, maximum > 0 else { continue }
                let percent = max(0, min(100, Int((current / maximum * 100).rounded())))
                let internalBattery = item[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
                if internalBattery {
                    result.macPercent = percent
                    result.onBattery = item[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
                }
                let name = internalBattery ? "This Mac" : item[kIOPSNameKey] as? String ?? "Power source"
                result.batteries.append(.init(id: "power:\(index)", name: name, component: "", percent: percent, symbol: internalBattery ? "laptopcomputer" : "battery.100percent", charging: item[kIOPSIsChargingKey] as? Bool))
            }
        }
        if result.macPercent == nil {
            result.batteries.insert(.init(id: "mac-ac", name: "This Mac", component: "AC power · no internal battery", percent: nil, symbol: "desktopcomputer"), at: 0)
        }
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            result.diskTotal = (attributes[.systemSize] as? NSNumber)?.doubleValue ?? 0
            result.diskFree = (attributes[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
        }
        result.memoryTotal = Double(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        if status == KERN_SUCCESS {
            var pageSize: vm_size_t = 0
            host_page_size(mach_host_self(), &pageSize)
            let reclaimable = Double(stats.free_count) + Double(stats.inactive_count) + Double(stats.speculative_count)
            result.memoryUsed = max(0, min(result.memoryTotal, result.memoryTotal - reclaimable * Double(pageSize)))
        }
        return result
    }
    static func bluetooth() -> [DeviceBattery]? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "mini", "-timeout", "8"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let timeout = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10, execute: timeout)
        let forcedStop = DispatchWorkItem {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 12, execute: forcedStop)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel(); forcedStop.cancel()
        guard process.terminationStatus == 0, data.count <= 4_194_304 else { return nil }
        return BatteryParser.bluetooth(data)
    }
}
