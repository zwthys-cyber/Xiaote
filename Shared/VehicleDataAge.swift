import Foundation

enum VehicleDataAge {
    static func isFresh(_ date: Date?, at now: Date = .now, maxAge: TimeInterval = 120) -> Bool {
        guard let date else { return false }
        let age = now.timeIntervalSince(date)
        return age >= -5 && age <= maxAge
    }
}
