import Foundation
import CryptoKit

@main struct UpdateChecks {
    static func main() throws {
        let archive = URL(fileURLWithPath: CommandLine.arguments[1])
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SimpleScreenUpdateCheck-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let hash = SHA256.hash(data: try Data(contentsOf: archive)).map { String(format: "%02x", $0) }.joined()
        let app = try UpdateWorker.unpack(archive: archive, expectedHash: hash, version: "1.2.0", directory: directory.appendingPathComponent("valid"))
        guard Bundle(url: app)?.bundleIdentifier == "dev.tekwiz.SimpleScreen" else { fatalError("Prepared app identity mismatch") }
        print("PASS: Real release archive checksum, extraction, version, identity, and signature")
        do {
            _ = try UpdateWorker.unpack(archive: archive, expectedHash: String(repeating: "0", count: 64), version: "1.2.0", directory: directory.appendingPathComponent("bad-hash"))
            fatalError("Invalid checksum accepted")
        } catch { print("PASS: Corrupt download rejected before extraction") }
        do {
            _ = try UpdateWorker.unpack(archive: archive, expectedHash: hash, version: "9.9.9", directory: directory.appendingPathComponent("bad-version"))
            fatalError("Wrong version accepted")
        } catch { print("PASS: Unexpected version rejected") }
        let script = directory.appendingPathComponent("install.sh")
        try UpdateWorker.installScript.write(to: script, atomically: true, encoding: .utf8)
        _ = try UpdateWorker.command("/bin/sh", ["-n", script.path])
        print("PASS: Update replacement helper shell syntax")
    }
}
