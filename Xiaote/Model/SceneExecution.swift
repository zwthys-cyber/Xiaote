import Foundation

struct SceneExecution: Identifiable {
    enum Status: Equatable {
        case pending, running, confirmed, sent, uncertain, failed(String), skipped(String)
        var title: String {
            switch self {
            case .pending: "未执行"
            case .running: "正在执行"
            case .confirmed: "车辆已确认"
            case .sent: "已发送，状态待确认"
            case .uncertain: "执行结果尚未确认"
            case .failed(let reason), .skipped(let reason): reason
            }
        }
        var symbol: String {
            switch self {
            case .pending: "circle"
            case .running: "ellipsis.circle"
            case .confirmed: "checkmark.circle.fill"
            case .sent, .uncertain: "clock"
            case .failed: "exclamationmark.circle"
            case .skipped: "minus.circle"
            }
        }
    }
    struct Step: Identifiable {
        let id: Int
        let title: String
        var status: Status = .pending
    }
    let id: UUID
    let sceneID: UUID
    let name: String
    let vehicleID: String
    var steps: [Step]
    private(set) var isRunning = true
    private(set) var summary = "等待身份验证"

    init(id: UUID, sceneID: UUID, name: String, vehicleID: String, titles: [String]) {
        self.id = id; self.sceneID = sceneID; self.name = name; self.vehicleID = vehicleID
        steps = titles.enumerated().map { Step(id: $0.offset, title: $0.element) }
    }

    mutating func update(_ index: Int, status: Status) {
        guard isRunning, steps.indices.contains(index) else { return }
        steps[index].status = status
        summary = "正在执行 \(index + 1)/\(steps.count)"
    }

    mutating func finish(reason: String? = nil) {
        guard isRunning else { return }
        isRunning = false
        let interrupted = steps.contains { $0.status == .pending || $0.status == .running }
        for index in steps.indices {
            if steps[index].status == .pending { steps[index].status = .skipped("未执行后续操作") }
            else if steps[index].status == .running { steps[index].status = .uncertain }
        }
        if let reason { summary = reason }
        else if interrupted { summary = "场景已中止" }
        else if steps.contains(where: { $0.status == .sent }) { summary = "指令已发送，部分状态待确认" }
        else { summary = "场景已完成" }
    }
}
