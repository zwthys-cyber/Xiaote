import SwiftUI

struct AutomationScenesView: View {
    @Environment(VehicleController.self) private var vehicle
    @State private var editingScene: VehicleController.AutomationScene?

    var body: some View {
        List {
            if let execution = vehicle.sceneExecution {
                Section {
                    Text(LocalizedStringKey(execution.summary)).font(.subheadline.weight(.medium))
                    ForEach(execution.steps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            if step.status == .running { ProgressView().controlSize(.small) }
                            else { Image(systemName: step.status.symbol).frame(width: 20) }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(step.id + 1). \(step.title)").font(.subheadline)
                                Text(LocalizedStringKey(step.status.title)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: { Text(execution.name) }
            }
            Section {
                ForEach(vehicle.automationScenes) { scene in
                    Button { Task { await vehicle.runScene(scene) } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: scene.symbol).frame(width: 34, height: 34).background(AppTheme.raised, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(scene.name).foregroundStyle(.primary)
                                Text(scene.actions.map(\.title).joined(separator: " → "))
                                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(); Image(systemName: "play.fill").font(.caption)
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(vehicle.isSceneRunning || vehicle.executingAction != nil)
                    .swipeActions { Button("编辑") { editingScene = scene }.tint(.gray).disabled(vehicle.isSceneRunning) }
                    .deleteDisabled(vehicle.isSceneRunning)
                }
                .onDelete(perform: vehicle.deleteScenes)
            } footer: {
                Text("动作按列表顺序依次执行。失败后停止后续操作；仅收到指令确认时，会显示状态待确认。")
            }
        }
        .scrollContentBackground(.hidden)
        .appDestinationPage(title: "自动化场景")
        .toolbar { Button { editingScene = newScene } label: { Image(systemName: "plus") }.disabled(vehicle.isSceneRunning) }
        .fullScreenCover(item: $editingScene) { scene in SceneEditorView(scene: scene).environment(vehicle) }
    }

    private var newScene: VehicleController.AutomationScene {
        .init(id: UUID(), name: "新场景", symbol: "sparkles", actions: [.lock])
    }
}

private struct SceneEditorView: View {
    @Environment(VehicleController.self) private var vehicle
    @Environment(\.dismiss) private var dismiss
    @State var scene: VehicleController.AutomationScene
    @State private var confirmDiscard = false
    @State private var originalScene: VehicleController.AutomationScene?

    private var hasChanges: Bool { originalScene.map { $0 != scene } ?? false }

    var body: some View {
        NavigationStack {
            Form {
                TextField("场景名称", text: $scene.name)
                Section {
                    ForEach(scene.actions, id: \.self) { action in
                        Text(action.title)
                    }
                    .onMove { source, destination in scene.actions.move(fromOffsets: source, toOffset: destination) }
                    .onDelete { scene.actions.remove(atOffsets: $0) }
                } header: { Text("动作顺序") } footer: { Text("拖动右侧把手调整顺序，点减号移除动作。") }
                Section("添加动作") {
                    ForEach(VehicleController.SceneAction.allCases.filter { !scene.actions.contains($0) }) { action in
                        Button { scene.actions.append(action) } label: { Label(action.title, systemImage: "plus.circle") }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("编辑场景").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { if hasChanges { confirmDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        scene.name = scene.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        vehicle.saveScene(scene); dismiss()
                    }
                    .disabled(scene.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || scene.actions.isEmpty)
                }
            }
            .confirmationDialog("放弃未保存的修改？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
            .onAppear { if originalScene == nil { originalScene = scene } }
        }
        .preferredColorScheme(.dark)
        .edgeSwipeToDismiss(enabled: !hasChanges)
    }
}
