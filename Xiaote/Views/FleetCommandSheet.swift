import SwiftUI
import LocalAuthentication

struct FleetCommandSheet: View {
    let control: FleetRemoteController
    let command: FleetCommandDefinition
    private let form: FleetControlForm
    @State private var values: [String: String]
    @State private var isSending = false
    @State private var succeeded = false
    @State private var feedback: String?
    @State private var confirmSensitive = false
    @Environment(\.dismiss) private var dismiss

    init(control: FleetRemoteController, command: FleetCommandDefinition) {
        self.control = control
        self.command = command
        let form = FleetControlForm.forCommand(command.id) ?? FleetControlForm(fields: [])
        self.form = form
        _values = State(initialValue: form.initialValues)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(LocalizedStringKey(command.summary), systemImage: command.symbol).font(.headline).padding(.vertical, 8)
                    LabeledContent("车辆", value: control.vehicle.name)
                    LabeledContent("识别码", value: "•••• \(control.vehicle.vin.suffix(4))")
                }
                .listRowBackground(AppTheme.surface)
                if !form.fields.isEmpty {
                    Section("设置") {
                        ForEach(form.fields) { field in fieldView(field) }
                    }
                    .listRowBackground(AppTheme.surface)
                    .disabled(isSending)
                }
                if !form.note.isEmpty {
                    Section { Text(LocalizedStringKey(form.note)).font(.subheadline).foregroundStyle(.secondary) }
                        .listRowBackground(AppTheme.surface)
                }
                if let feedback {
                    Section {
                        Label(feedback, systemImage: succeeded ? "checkmark.circle" : "info.circle")
                            .foregroundStyle(succeeded ? Color.green : Color.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("remote-command-result")
                    }.listRowBackground(AppTheme.surface)
                }
                Section {
                    Button {
                        if command.risk == .critical || command.id == "actuate_trunk" { confirmSensitive = true }
                        else { send() }
                    } label: {
                        HStack(spacing: 10) {
                            Spacer(minLength: 0)
                            if isSending { ProgressView().tint(.black) }
                            Text(LocalizedStringKey(isSending ? "正在发送…" : succeeded ? "车辆已接受指令" : command.title))
                                .font(.body.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.black)
                        .padding(.vertical, 12)
                        .frame(minHeight: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PrimaryPressStyle())
                    .disabled(isSending || succeeded || !control.canControl || control.account.remoteCommandInFlight || !isValid)
                    .opacity(isValid && control.canControl ? 1 : 0.4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("remote-send-command")
                } footer: {
                    Text("指令只发送给上方车辆。页面不会自动重试控制操作。")
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .appDestinationPage(title: NSLocalizedString(command.title, comment: ""))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.disabled(isSending)
                }
            }
            .confirmationDialog("确认\(command.title)？", isPresented: $confirmSensitive, titleVisibility: .visible) {
                Button(LocalizedStringKey(command.title)) { send() }
                Button("取消", role: .cancel) {}
            } message: { Text("车辆：\(control.vehicle.name) · \(control.vehicle.vin.suffix(4))") }
            .onChange(of: values) { _, _ in succeeded = false; feedback = nil }
            .onChange(of: control.account.isSignedIn) { _, signedIn in if !signedIn { dismiss() } }
        }
        .tint(.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSending)
    }

    private var isValid: Bool { FleetControlForm.forCommand(command.id) != nil && (try? form.payload(commandID: command.id, values: values)) != nil }

    @ViewBuilder private func fieldView(_ field: FleetControlField) -> some View {
        switch field.kind {
        case .number(let range, let step, let unit):
            Stepper(value: Binding(
                get: { Double(values[field.id] ?? field.initial) ?? range.lowerBound },
                set: { values[field.id] = String($0) }
            ), in: range, step: step) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(field.title))
                    Text("\((Double(values[field.id] ?? field.initial) ?? 0).formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                        .font(.title3.weight(.medium)).monospacedDigit()
                }.padding(.vertical, 4)
            }.accessibilityIdentifier("remote-field-\(field.id)")
        case .toggle:
            Toggle(LocalizedStringKey(field.title), isOn: Binding(
                get: { values[field.id] == "true" }, set: { values[field.id] = String($0) }
            )).tint(.green).accessibilityIdentifier("remote-field-\(field.id)")
        case .choice(let options):
            Picker(LocalizedStringKey(field.title), selection: binding(field)) {
                ForEach(options, id: \.0) { value, label in Text(LocalizedStringKey(label)).tag(value) }
            }.accessibilityIdentifier("remote-field-\(field.id)")
        case .text(let maximum):
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(field.title)).font(.caption).foregroundStyle(.secondary)
                TextField(LocalizedStringKey(field.title), text: binding(field), axis: .vertical)
                    .lineLimit(1...4)
                    .submitLabel(.done)
                    .accessibilityIdentifier("remote-field-\(field.id)")
                if (values[field.id] ?? "").count > maximum {
                    Text("最多 \(maximum) 个字符").font(.caption).foregroundStyle(.orange)
                }
            }.padding(.vertical, 6)
        case .time:
            DatePicker(LocalizedStringKey(field.title), selection: Binding(
                get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(Double(Int(values[field.id] ?? "0") ?? 0) * 60) },
                set: {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                    values[field.id] = String((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
                }
            ), displayedComponents: .hourAndMinute).accessibilityIdentifier("remote-field-\(field.id)")
        }
    }

    private func binding(_ field: FleetControlField) -> Binding<String> {
        Binding(get: { values[field.id] ?? field.initial }, set: { values[field.id] = $0 })
    }

    private func send() {
        guard !isSending, !succeeded, isValid, control.canControl else { return }
        isSending = true
        feedback = nil
        // Freeze the values and target before authentication or any suspension.
        let submittedValues = values
        Task { @MainActor in
            defer { isSending = false }
            do {
                let payload = try form.payload(commandID: command.id, values: submittedValues)
                try await control.account.send(command: command, to: control.vehicle, payload: payload)
                succeeded = true
                feedback = "车辆已接受“\(command.title)”指令。最新状态请返回首页后下拉读取。"
                // Do not issue a second physical command, or optimistically
                // overwrite telemetry, when a response is late or lost.
            } catch {
                if FleetRemoteController.isCancellation(error) || (error as? LAError)?.code == .userCancel {
                    feedback = "操作已取消。"
                } else {
                    feedback = FleetRemoteController.describe(error)
                }
            }
        }
    }
}
