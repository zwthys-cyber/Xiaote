import Foundation

/// A curated, typed UI for commands. Payload templates are documentation only;
/// they must not become editable JSON or silently send placeholder coordinates.
struct FleetControlField: Identifiable {
    enum Kind {
        case number(ClosedRange<Double>, step: Double, unit: String)
        case choice([(String, String)])
        case toggle
        case text(maxLength: Int)
        case time
    }
    let id: String
    let title: String
    let kind: Kind
    let initial: String
}

struct FleetControlForm {
    let fields: [FleetControlField]
    var note: String = ""

    static func forCommand(_ id: String) -> Self? {
        func number(_ key: String, _ title: String, _ range: ClosedRange<Double>, _ value: String, _ unit: String, step: Double = 1) -> FleetControlField {
            .init(id: key, title: title, kind: .number(range, step: step, unit: unit), initial: value)
        }
        func toggle(_ key: String = "on", _ title: String = "开启") -> FleetControlField {
            .init(id: key, title: title, kind: .toggle, initial: "true")
        }
        func choice(_ key: String, _ title: String, _ options: [(String, String)]) -> FleetControlField {
            .init(id: key, title: title, kind: .choice(options), initial: options[0].0)
        }
        let seats = [("0", "主驾驶"), ("1", "副驾驶")]
        switch id {
        case "door_lock", "door_unlock", "flash_lights", "honk_horn", "charge_start", "charge_stop",
             "charge_port_door_open", "charge_port_door_close", "charge_standard", "charge_max_range",
             "auto_conditioning_start", "auto_conditioning_stop", "media_toggle_playback",
             "media_next_track", "media_prev_track", "media_next_fav", "media_prev_fav",
             "media_volume_up", "media_volume_down", "cancel_software_update", "remote_start_drive":
            return .init(fields: [], note: id == "remote_start_drive" ? "短时间内允许无钥匙驾驶，请确认车辆周围环境安全。" : "")
        case "actuate_trunk":
            return .init(fields: [choice("which_trunk", "行李厢", [("rear", "后备箱"), ("front", "前备箱")])], note: "请确认行李厢周围没有障碍物。")
        case "sun_roof_control":
            return .init(fields: [choice("state", "天窗", [("close", "关闭"), ("vent", "通风")])], note: "仅适用于配备可开启天窗的车型。")
        case "set_charge_limit": return .init(fields: [number("percent", "充电上限", 50...100, "80", "%")])
        case "set_charging_amps": return .init(fields: [number("charging_amps", "交流充电电流", 1...48, "16", "A")], note: "实际电流受车辆、充电设备和电源限制。")
        case "set_temps":
            return .init(fields: [number("driver_temp", "主驾驶温度", 15...28, "22", "°C", step: 0.5), number("passenger_temp", "副驾驶温度", 15...28, "22", "°C", step: 0.5)])
        case "set_preconditioning_max", "remote_steering_wheel_heater_request", "remote_auto_steering_wheel_heat_climate_request", "set_sentry_mode":
            return .init(fields: [toggle()])
        case "set_bioweapon_mode": return .init(fields: [toggle()], note: "需要车辆配备 HEPA 空气过滤系统。")
        case "set_cabin_overheat_protection": return .init(fields: [toggle(), toggle("fan_only", "仅使用风扇")])
        case "set_climate_keeper_mode":
            return .init(fields: [choice("climate_keeper_mode", "空调模式", [("0", "关闭"), ("1", "保持"), ("2", "爱犬"), ("3", "露营")])])
        case "set_cop_temp": return .init(fields: [choice("cop_temp", "温度阈值", [("High", "高"), ("Medium", "中"), ("Low", "低")])])
        case "remote_seat_heater_request":
            return .init(fields: [choice("heater", "座椅", seats + [("2", "后排左"), ("4", "后排中"), ("5", "后排右")]), number("level", "加热等级", 0...3, "1", "")], note: "请先开启空调；0 表示关闭。")
        case "remote_seat_cooler_request":
            return .init(fields: [choice("seat_position", "座椅", [("1", "主驾驶"), ("2", "副驾驶")]), number("seat_cooler_level", "通风等级", 0...3, "1", "")], note: "需要座椅通风配置，并先开启空调；0 表示关闭。")
        case "remote_auto_seat_climate_request":
            return .init(fields: [choice("auto_seat_position", "座椅", seats), toggle("auto_climate_on")], note: "请先开启空调。")
        case "remote_steering_wheel_heat_level_request": return .init(fields: [number("level", "加热等级", 0...3, "1", "")])
        case "adjust_volume": return .init(fields: [number("volume", "车机音量", 0...10, "3", "", step: 0.5)], note: "需要车内有人并已开启手机访问。")
        case "remote_boombox": return .init(fields: [choice("sound", "外放音效", [("2000", "寻车提示音"), ("0", "随机趣味音效")])], note: "仅适用于支持外放音效的车型。")
        case "navigation_request": return .init(fields: [.init(id: "destination", title: "目的地", kind: .text(maxLength: 500), initial: "")])
        case "set_vehicle_name": return .init(fields: [.init(id: "vehicle_name", title: "车辆名称", kind: .text(maxLength: 32), initial: "")])
        case "schedule_software_update": return .init(fields: [number("delay_minutes", "多久后开始", 0...1440, "30", "分钟", step: 5)], note: "更新期间车辆无法驾驶，请确认车辆已停妥。")
        case "set_scheduled_charging": return .init(fields: [toggle("enable", "启用预约"), .init(id: "time", title: "开始充电", kind: .time, initial: "0")], note: "按车辆当地时间执行；仅适用于支持旧版预约的车辆。")
        default: return nil
        }
    }

    static var commands: [FleetCommandDefinition] {
        FleetCommandDefinition.all.filter { forCommand($0.id) != nil }
    }

    var initialValues: [String: String] { Dictionary(uniqueKeysWithValues: fields.map { ($0.id, $0.initial) }) }

    func payload(commandID: String, values: [String: String], now: Date = .now) throws -> Data {
        var object: [String: Any] = [:]
        let numericChoices: Set<String> = ["climate_keeper_mode", "heater", "seat_position", "auto_seat_position", "sound"]
        for field in fields {
            let value = (values[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            switch field.kind {
            case .number(let range, let step, _):
                guard let number = Double(value), number.isFinite, range.contains(number),
                      abs((number - range.lowerBound) / step - ((number - range.lowerBound) / step).rounded()) < 0.0001 else {
                    throw FleetAPIError.server("请检查\(field.title)的取值。")
                }
                object[field.id] = number
            case .choice(let options):
                guard options.contains(where: { $0.0 == value }) else { throw FleetAPIError.server("请选择\(field.title)。") }
                if numericChoices.contains(field.id) { object[field.id] = Int(value) }
                else { object[field.id] = value }
            case .toggle:
                guard value == "true" || value == "false" else { throw FleetAPIError.server("请选择\(field.title)。") }
                object[field.id] = value == "true"
            case .text(let maximum):
                guard !value.isEmpty, value.count <= maximum else { throw FleetAPIError.server("请填写\(field.title)，最多 \(maximum) 个字符。") }
                object[field.id] = value
            case .time:
                guard let minute = Int(value), (0..<1440).contains(minute) else { throw FleetAPIError.server("请选择有效时间。") }
                object[field.id] = minute
            }
        }
        if commandID == "navigation_request" {
            object = ["type": "share_ext_content_raw", "locale": "zh-CN", "timestamp_ms": String(Int64(now.timeIntervalSince1970 * 1000)),
                      "value": ["android.intent.extra.TEXT": object["destination"] as? String ?? ""]]
        } else if commandID == "schedule_software_update" {
            object = ["offset_sec": Int((object["delay_minutes"] as? Double ?? 0) * 60)]
        } else if commandID == "set_bioweapon_mode" {
            object["manual_override"] = true
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
