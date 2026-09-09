import Foundation

enum VehicleVIN {
    private static let allowed = Set("ABCDEFGHJKLMNPRSTUVWXYZ0123456789")
    private static let teslaWMIs = ["5YJ", "7SA", "7G2", "LRW", "XP7"]

    /// Keeps only characters permitted by the VIN standard. Swift's
    /// `isLetter` also accepts Chinese characters, so it must not be used here.
    static func normalized(_ input: String) -> String {
        String(input.uppercased().filter { allowed.contains($0) })
    }

    static func exact(_ input: String) -> String? {
        let value = normalized(input)
        return value.count == 17 ? value : nil
    }

    /// OCR often returns surrounding labels such as “车辆识别码 VIN:”. Search
    /// the cleaned text for a 17-character Tesla VIN instead of accepting an
    /// arbitrary 17-character Unicode window.
    static func scanned(from transcript: String) -> String? {
        let value = normalized(transcript)
        guard value.count >= 17 else { return nil }

        var matches: [String] = []
        for offset in 0...(value.count - 17) {
            let start = value.index(value.startIndex, offsetBy: offset)
            let end = value.index(start, offsetBy: 17)
            let candidate = String(value[start..<end])
            if teslaWMIs.contains(where: candidate.hasPrefix) {
                matches.append(candidate)
            }
        }
        return Array(Set(matches)).count == 1 ? matches[0] : nil
    }
}
