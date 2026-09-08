import XCTest
@testable import Xiaote

final class FleetControlTests: XCTestCase {
    func testEveryVisibleCommandHasAValidTypedForm() throws {
        XCTAssertGreaterThan(FleetControlForm.commands.count, 35)
        for command in FleetControlForm.commands {
            let form = try XCTUnwrap(FleetControlForm.forCommand(command.id))
            var values = form.initialValues
            for field in form.fields {
                if case .text = field.kind { values[field.id] = "测试目的地" }
            }
            let payload = try form.payload(commandID: command.id, values: values)
            XCTAssertTrue(try JSONSerialization.jsonObject(with: payload) is [String: Any], command.id)
        }
    }

    func testNavigationEncodesTextSafelyAndUsesCurrentTimestamp() throws {
        let form = try XCTUnwrap(FleetControlForm.forCommand("navigation_request"))
        let data = try form.payload(commandID: "navigation_request", values: ["destination": " 上海 \"虹桥\"\n站 "], now: Date(timeIntervalSince1970: 123))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["timestamp_ms"] as? String, "123000")
        XCTAssertEqual((object["value"] as? [String: String])?["android.intent.extra.TEXT"], "上海 \"虹桥\"\n站")
        XCTAssertNil(object["destination"])
    }

    func testEmptyDestinationAndInvalidNumberAreRejected() throws {
        let navigation = try XCTUnwrap(FleetControlForm.forCommand("navigation_request"))
        XCTAssertThrowsError(try navigation.payload(commandID: "navigation_request", values: ["destination": "  \n"]))
        let charge = try XCTUnwrap(FleetControlForm.forCommand("set_charge_limit"))
        for value in ["0", "101", "nan", "80.5", ""] {
            XCTAssertThrowsError(try charge.payload(commandID: "set_charge_limit", values: ["percent": value]))
        }
    }

    func testChoicesCannotSendArbitraryValues() throws {
        let form = try XCTUnwrap(FleetControlForm.forCommand("actuate_trunk"))
        XCTAssertThrowsError(try form.payload(commandID: "actuate_trunk", values: ["which_trunk": "anything"]))
        XCTAssertNil(FleetControlForm.forCommand("erase_user_data"))
        XCTAssertNil(FleetControlForm.forCommand("trigger_homelink"), "Do not send a fake zero location")
    }

    func testTemperaturePreservesHalfDegrees() throws {
        let form = try XCTUnwrap(FleetControlForm.forCommand("set_temps"))
        let data = try form.payload(commandID: "set_temps", values: ["driver_temp": "21.5", "passenger_temp": "23"])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Double])
        XCTAssertEqual(object, ["driver_temp": 21.5, "passenger_temp": 23])
    }

    func testUpdateDelayConvertsMinutesToSeconds() throws {
        let form = try XCTUnwrap(FleetControlForm.forCommand("schedule_software_update"))
        let data = try form.payload(commandID: "schedule_software_update", values: ["delay_minutes": "30"])
        XCTAssertEqual(try JSONSerialization.jsonObject(with: data) as? [String: Int], ["offset_sec": 1800])
    }

    func testAbsentTelemetryDoesNotBecomeUnlockedOrZeroBattery() throws {
        let value = try JSONDecoder().decode(FleetVehicleData.self, from: Data(#"{"charge_state":{},"vehicle_state":{"locked":null}}"#.utf8))
        XCTAssertNil(value.chargeState?.batteryLevel)
        XCTAssertNil(value.vehicleState?.locked)
        XCTAssertNil(value.climateState)
    }

    func testTelemetryDecodesRealAPIFieldNames() throws {
        let value = try JSONDecoder().decode(FleetVehicleData.self, from: Data(#"{"charge_state":{"battery_level":76,"battery_range":210.5},"vehicle_state":{"locked":true},"climate_state":{"inside_temp":23.5}}"#.utf8))
        XCTAssertEqual(value.chargeState?.batteryLevel, 76)
        XCTAssertEqual(value.vehicleState?.locked, true)
        XCTAssertEqual(value.climateState?.insideTemp, 23.5)
    }
}
