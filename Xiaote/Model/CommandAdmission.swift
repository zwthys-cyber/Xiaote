import Foundation

/// Reserved synchronously, before authentication or waiting for a BLE read.
/// A ticket is invalid after disconnect/switch, even when the VIN is unchanged.
struct CommandAdmission {
    struct Ticket: Equatable {
        let id = UUID()
        let generation: UInt64
    }
    private(set) var generation: UInt64 = 0
    private(set) var active: Ticket?

    mutating func reserve() -> Ticket? {
        guard active == nil else { return nil }
        let ticket = Ticket(generation: generation)
        active = ticket
        return ticket
    }

    func owns(_ ticket: Ticket) -> Bool { active == ticket && generation == ticket.generation }

    mutating func finish(_ ticket: Ticket) {
        if owns(ticket) { active = nil }
    }

    mutating func invalidate() {
        generation &+= 1
        active = nil
    }
}

enum SceneCommandContext {
    @TaskLocal static var batchID: UUID?
}
