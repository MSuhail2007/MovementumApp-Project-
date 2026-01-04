import Foundation

final class ScanLogger {
    static let shared = ScanLogger()
    private let fileURL: URL
    private let queue = DispatchQueue(label: "scan.logger.queue")

    private init() {
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            fileURL = docs.appendingPathComponent("scan_logs.txt")
        } else {
            fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("scan_logs.txt")
        }
        // Ensure file exists
        if !fm.fileExists(atPath: fileURL.path) {
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n\n"
        queue.async {
            if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                handle.seekToEndOfFile()
                if let data = entry.data(using: .utf8) {
                    handle.write(data)
                }
                try? handle.close()
            } else {
                try? entry.write(to: self.fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    func readAll() -> String {
        return (try? String(contentsOf: fileURL)) ?? ""
    }

    func readLastLines(_ count: Int = 200) -> String {
        let content = readAll()
        let lines = content.components(separatedBy: .newlines)
        let last = lines.suffix(count)
        return last.joined(separator: "\n")
    }
}
