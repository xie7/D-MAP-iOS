import SwiftUI

/// 设置视图 - 久坐提醒、通知同步、时间同步等
struct SettingsView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        NavigationView {
            List {
                // 久坐提醒
                Section {
                    NavigationLink(destination: SedentarySettingsView()) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            Text("久坐提醒")
                            Spacer()
                            Text(viewModel.sedentarySettings.isEnabled ? "已开启" : "已关闭")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 通知同步
                Section {
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.red)
                                .frame(width: 30)
                            Text("通知同步")
                            Spacer()
                            Text("设置")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 时间同步
                Section {
                    Button(action: {
                        viewModel.syncTime()
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("同步时间到手表")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }

                // 关于
                Section("关于") {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("D-MAP")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("兼容设备")
                        Spacer()
                        Text("smartmovt 智能手表")
                            .foregroundColor(.secondary)
                    }
                }

                // iOS 限制说明
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("iOS 平台限制说明")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("• 短信同步：iOS 不允许第三方应用读取短信内容，仅支持来电和系统通知推送\n• 通知同步：需在「设置 > 通知」中授权对应应用的通知权限\n• 后台运行：iOS 对后台蓝牙连接有限制，建议保持 App 在前台或添加到常用 App")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 久坐提醒设置

struct SedentarySettingsView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var settings: SedentarySettings

    init() {
        _settings = State(initialValue: SedentarySettings.default)
    }

    var body: some View {
        Form {
            Section {
                Toggle("开启久坐提醒", isOn: $settings.isEnabled)
                    .onChange(of: settings.isEnabled) { _ in
                        save()
                    }
            }

            if settings.isEnabled {
                Section("提醒间隔") {
                    Stepper(value: $settings.intervalMinutes, in: 30...180, step: 15) {
                        HStack {
                            Text("每")
                            Text("\(settings.intervalMinutes) 分钟")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Text("提醒一次")
                        }
                    }
                    .onChange(of: settings.intervalMinutes) { _ in save() }
                }

                Section("提醒时段") {
                    DatePicker("开始时间", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _ in save() }
                    DatePicker("结束时间", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: endTime) { _ in save() }
                }

                Section("休息时长") {
                    Stepper(value: $settings.breakDuration, in: 1...15) {
                        HStack {
                            Text("休息")
                            Text("\(settings.breakDuration) 分钟")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: settings.breakDuration) { _ in save() }
                }
            }
        }
        .navigationTitle("久坐提醒")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = viewModel.sedentarySettings
        }
    }

    private var startTime: Date {
        get {
            var comps = DateComponents()
            comps.hour = settings.startHour
            comps.minute = settings.startMinute
            return Calendar.current.date(from: comps) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            settings.startHour = comps.hour ?? 9
            settings.startMinute = comps.minute ?? 0
        }
    }

    private var endTime: Date {
        get {
            var comps = DateComponents()
            comps.hour = settings.endHour
            comps.minute = settings.endMinute
            return Calendar.current.date(from: comps) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            settings.endHour = comps.hour ?? 18
            settings.endMinute = comps.minute ?? 0
        }
    }

    private func save() {
        viewModel.updateSedentarySettings(settings)
    }
}

// MARK: - 通知同步设置

struct NotificationSettingsView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var settings: NotificationSettings

    init() {
        _settings = State(initialValue: NotificationSettings())
    }

    var body: some View {
        Form {
            Section("推送到手表") {
                Toggle("来电提醒", isOn: $settings.callEnabled)
                Toggle("短信提醒", isOn: $settings.smsEnabled)
                Toggle("微信通知", isOn: $settings.wechatEnabled)
                Toggle("QQ 通知", isOn: $settings.qqEnabled)
                Toggle("其他应用", isOn: $settings.otherAppsEnabled)
            }

            Section {
                Button(action: {
                    // 发送测试通知到手表
                    viewModel.sendTestNotification(type: .otherApp)
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                        Text("发送测试通知到手表")
                    }
                }
            }

            Section("说明") {
                Text("iOS 系统限制：第三方应用无法直接读取短信内容。来电和通知推送需要在系统「设置 > 通知」中授权对应应用。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("通知同步")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = viewModel.notificationSettings
        }
        .onChange(of: settings) { newValue in
            // 保存设置 (实际项目中通过 ViewModel)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(DeviceViewModel())
}
