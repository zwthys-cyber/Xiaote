import Foundation

/// All fields are optional: absence of a permission or a sleeping vehicle must
/// never be rendered as a zero battery, unlocked door, or stopped charger.
struct FleetVehicleData: Decodable, Sendable {
    struct Charge: Decodable, Sendable {
        let batteryLevel: Int?
        let batteryRange: Double?
        let chargingState: String?
        let chargeLimitSoc: Int?
        enum CodingKeys: String, CodingKey {
            case batteryLevel = "battery_level", batteryRange = "battery_range"
            case chargingState = "charging_state", chargeLimitSoc = "charge_limit_soc"
        }
    }
    struct Climate: Decodable, Sendable {
        let insideTemp: Double?
        let outsideTemp: Double?
        let isClimateOn: Bool?
        enum CodingKeys: String, CodingKey {
            case insideTemp = "inside_temp", outsideTemp = "outside_temp", isClimateOn = "is_climate_on"
        }
    }
    struct VehicleState: Decodable, Sendable {
        let locked: Bool?
        let sentryMode: Bool?
        let carVersion: String?
        enum CodingKeys: String, CodingKey {
            case locked, sentryMode = "sentry_mode", carVersion = "car_version"
        }
    }
    let vin: String?
    let chargeState: Charge?
    let climateState: Climate?
    let vehicleState: VehicleState?
    enum CodingKeys: String, CodingKey {
        case vin, chargeState = "charge_state", climateState = "climate_state", vehicleState = "vehicle_state"
    }
}
