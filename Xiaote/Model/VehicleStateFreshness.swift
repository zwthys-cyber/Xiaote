import Foundation

struct VehicleStateFreshness {
    enum Category: String, CaseIterable {
        case basic, charge, climate, closures, tires, drive, software, media
        case lock, battery, range, climateEnabled, defrost, sentry
    }
    private(set) var dates: [Category: Date] = [:]

    mutating func record(_ category: Category, at date: Date = .now) {
        dates[category] = date
    }

    /// The oldest required category describes the combined state honestly.
    /// A successful media/temperature read cannot make old lock data fresh.
    func updatedAt(requiring categories: [Category]) -> Date? {
        let values = categories.compactMap { dates[$0] }
        guard values.count == categories.count else { return nil }
        return values.min()
    }
}

enum ChargingCondition: Equatable {
    case disconnected, noPower, starting, charging, complete, stopped, calibrating, unknown

    // Stopped is also a normal manual/scheduled state. Without evidence of a
    // fault it must never be promoted to an abnormal charging notification.
    var hasPowerIssue: Bool { self == .noPower }
}
