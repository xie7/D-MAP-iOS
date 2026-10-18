import SwiftUI

/// 闹钟视图 - 管理最多5个闹钟
struct AlarmView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var showingAddAlarm = false
    @State private var editingAlarm: Alarm?

    var body: some View {
        NavigationView {
            List {
                if viewModel.alarms.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "alarm")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("暂无闹钟")
                                    .foregroundColor(.gray)
                                Text("点击右上角 + 添加闹钟")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                    }
                } else {
                    ForEach(viewModel.alarms) { alarm in
                        AlarmRow(alarm: alarm) {
                            editingAlarm = alarm
                        } onToggle: {
                            viewModel.toggleAlarm(alarm)
                        }
                    }
                    .onDelete(perform: deleteAlarm)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("闹钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddAlarm = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.alarms.count >= 5)
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AlarmEditView(alarm: nil) { newAlarm in
                    viewModel.addAlarm(newAlarm)
                }
            }
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditView(alarm: alarm) { updatedAlarm in
                    viewModel.updateAlarm(updatedAlarm)
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.alarms.count >= 5 {
                    Text("最多支持 5 个闹钟")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private func deleteAlarm(at offsets: IndexSet) {
        offsets.forEach { index in
            viewModel.deleteAlarm(viewModel.alarms[index])
        }
    }
}

// MARK: - 闹钟行

struct AlarmRow: View {
    let alarm: Alarm
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.timeString)
                        .font(.largeTitle)
                        .fontWeight(.light)
                        .foregroundColor(alarm.isEnabled ? .primary : .gray)
                    Text(alarm.repeatDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 闹钟编辑视图

struct AlarmEditView: View {
    @Environment(\.dismiss) private var dismiss
    let alarm: Alarm?
    let onSave: (Alarm) -> Void

    @State private var hour: Int = 7
    @State private var minute: Int = 0
    @State private var isEnabled: Bool = true
    @State private var isRepeat: Bool = true
    @State private var repeatDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    init(alarm: Alarm?, onSave: @escaping (Alarm) -> Void) {
        self.alarm = alarm
        self.onSave = onSave
        if let alarm = alarm {
            _hour = State(initialValue: alarm.hour)
            _minute = State(initialValue: alarm.minute)
            _isEnabled = State(initialValue: alarm.isEnabled)
            _isRepeat = State(initialValue: alarm.isRepeat)
            _repeatDays = State(initialValue: alarm.repeatDays)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // 时间选择
                Section {
                    DatePicker("时间", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                }

                // 重复
                Section {
                    Toggle("重复", isOn: $isRepeat)

                    if isRepeat {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("重复日期")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                ForEach(Weekday.allCases) { day in
                                    DayButton(day: day, isSelected: repeatDays.contains(day)) {
                                        if repeatDays.contains(day) {
                                            repeatDays.remove(day)
                                        } else {
                                            repeatDays.insert(day)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // 开启
                Section {
                    Toggle("启用闹钟", isOn: $isEnabled)
                }
            }
            .navigationTitle(alarm == nil ? "添加闹钟" : "编辑闹钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let newAlarm = Alarm(
                            id: alarm?.id ?? UUID(),
                            hour: hour,
                            minute: minute,
                            isEnabled: isEnabled,
                            isRepeat: isRepeat,
                            repeatDays: isRepeat ? repeatDays : []
                        )
                        onSave(newAlarm)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var selectedTime: Date {
        get {
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            return Calendar.current.date(from: comps) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            hour = comps.hour ?? 0
            minute = comps.minute ?? 0
        }
    }
}

// MARK: - 星期按钮

struct DayButton: View {
    let day: Weekday
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(day.shortName)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(18)
        }
    }
}

#Preview {
    AlarmView()
        .environmentObject(DeviceViewModel())
}
