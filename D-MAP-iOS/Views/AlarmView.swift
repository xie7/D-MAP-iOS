import SwiftUI

// MARK: - 智玩（安卓原版第二主页面：7 个功能项）

struct PlayView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @AppStorage("dmap.disconnectAlert") private var disconnectAlert = false

    var body: some View {
        DMapPage(title: "智玩") {
            ScrollView {
                VStack(spacing: 12) {
                    // 主功能列表（安卓顺序）
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapNavRow(icon: "alarm.fill", tint: .blue, title: "智能闹钟") {
                                AlarmListViewPage()
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "camera.fill", tint: .green, title: "遥控拍照") {
                                CameraPage()
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "watchface.applewatch.case", tint: .purple, title: "手表模式") {
                                WatchModePage()
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "bell.badge.fill", tint: .orange, title: "智能提醒") {
                                SmartRemindPage()
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "clock.arrow.circlepath", tint: .blue, title: "手表指针校正") {
                                PointerCalibrationPage()
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "heart.fill", tint: .red, title: "心率估测") {
                                HeartRatePage()
                            }
                            DMapRowDivider()
                            DMapToggleRow(icon: "link.circle.fill", tint: .gray,
                                          title: "断开提醒", isOn: $disconnectAlert)
                        }
                    }

                    // 附加功能（安卓也有这些入口）
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapNavRow(icon: "figure.walk", tint: .green, title: "久坐提醒") {
                                SedentaryPage()
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "app.badge.fill", tint: .blue, title: "应用消息提醒") {
                                NotificationPage()
                            }
                            DMapRowDivider()
                            DMapRow(icon: "location.fill.viewfinder", tint: .orange, title: "查找手表",
                                    action: { viewModel.findWatch() })
                            DMapRowDivider()
                            DMapRow(icon: "clock.fill", tint: .blue, title: "同步时间",
                                    action: { viewModel.manualSyncTime() })
                        }
                    }

                    Text("提示：来电 / 短信 / 应用消息提醒需 iOS 通知权限，系统沙盒不允许第三方 App 读取来电与短信内容；闹钟、久坐、校时、找表等功能可正常下发到手表。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - 智能闹钟（安卓：最多添加五个闹钟）

struct AlarmListViewPage: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var showingAddAlarm = false
    @State private var editingAlarm: Alarm?

    var body: some View {
        DMapSubPage(title: "智能闹钟") {
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.alarms.isEmpty {
                        DMapCard {
                            VStack(spacing: 12) {
                                Image(systemName: "alarm")
                                    .font(.system(size: 42))
                                    .foregroundColor(DMapTheme.tabNormal)
                                Text("暂无闹钟")
                                    .font(.system(size: 14))
                                    .foregroundColor(DMapTheme.textGray)
                                Text("点击右上角 + 添加闹钟")
                                    .font(.system(size: 12))
                                    .foregroundColor(DMapTheme.tabNormal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    } else {
                        DMapCard {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.alarms.enumerated()), id: \.element.id) { idx, alarm in
                                    AlarmRow(alarm: alarm) {
                                        editingAlarm = alarm
                                    } onToggle: {
                                        viewModel.toggleAlarm(alarm)
                                    } onDelete: {
                                        viewModel.deleteAlarm(alarm)
                                    }
                                    if idx < viewModel.alarms.count - 1 { DMapRowDivider() }
                                }
                            }
                        }
                    }

                    Button(action: { showingAddAlarm = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加闹钟")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(DMapTheme.brandBlue)
                        .cornerRadius(6)
                    }
                    .padding(.horizontal, 8)
                    .disabled(viewModel.alarms.count >= 5)

                    Text("最多只能添加五个闹钟 · 设置后自动保存到手表")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.bottom, 20)
                }
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $showingAddAlarm) {
            AlarmEditView(alarm: nil) { newAlarm in viewModel.addAlarm(newAlarm) }
        }
        .sheet(item: $editingAlarm) { alarm in
            AlarmEditView(alarm: alarm) { updated in viewModel.updateAlarm(updated) }
        }
    }
}

// MARK: - 闹钟行
struct AlarmRow: View {
    let alarm: Alarm
    let onEdit: () -> Void
    let onToggle: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(alarm.timeString)
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(alarm.isEnabled ? DMapTheme.textDark : DMapTheme.textGray)
                    Text(alarm.repeatDescription)
                        .font(.system(size: 12))
                        .foregroundColor(DMapTheme.textGray)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .tint(DMapTheme.brandBlue)
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
    }
}

// MARK: - 闹钟编辑视图（保留原逻辑，安卓蓝配色）
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
                Section {
                    DatePicker("时间", selection: selectedTimeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                }
                Section {
                    Toggle("重复", isOn: $isRepeat).tint(DMapTheme.brandBlue)
                    if isRepeat {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("重复日期").font(.system(size: 13)).foregroundColor(DMapTheme.textGray)
                            HStack {
                                ForEach(Weekday.allCases) { day in
                                    DayButton(day: day, isSelected: repeatDays.contains(day)) {
                                        if repeatDays.contains(day) { repeatDays.remove(day) }
                                        else { repeatDays.insert(day) }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section {
                    Toggle("启用闹钟", isOn: $isEnabled).tint(DMapTheme.brandBlue)
                }
            }
            .navigationTitle(alarm == nil ? "添加闹钟" : "闹钟编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let newAlarm = Alarm(id: alarm?.id ?? UUID(), hour: hour, minute: minute,
                                             isEnabled: isEnabled, isRepeat: isRepeat,
                                             repeatDays: isRepeat ? repeatDays : [])
                        onSave(newAlarm)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(DMapTheme.brandBlue)
    }

    private var selectedTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents(); comps.hour = self.hour; comps.minute = self.minute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                self.hour = comps.hour ?? 0; self.minute = comps.minute ?? 0
            })
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
                .font(.system(size: 14, weight: .medium))
                .frame(width: 36, height: 36)
                .background(isSelected ? DMapTheme.brandBlue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : DMapTheme.textDark)
                .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 手表模式（安卓：健康省电模式 / 勿扰 / 飞行模式 / 暂停手表时间）
struct WatchModePage: View {
    @AppStorage("dmap.powerSave") private var powerSave = false
    @AppStorage("dmap.dnd") private var dnd = false
    @AppStorage("dmap.flight") private var flight = false
    @AppStorage("dmap.pauseTime") private var pauseTime = false

    var body: some View {
        DMapSubPage(title: "手表模式") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapToggleRow(icon: "leaf.fill", tint: .green, title: "健康省电模式", isOn: $powerSave)
                            DMapRowDivider()
                            DMapToggleRow(icon: "moon.fill", tint: .purple, title: "勿扰模式", isOn: $dnd)
                            DMapRowDivider()
                            DMapToggleRow(icon: "airplane", tint: .blue, title: "飞行模式", isOn: $flight)
                            DMapRowDivider()
                            DMapToggleRow(icon: "pause.circle.fill", tint: .orange, title: "暂停手表时间模式", isOn: $pauseTime)
                        }
                    }
                    Text("手表模式开关为本地记录；对应 BLE 帧未在真表上验证，暂不向手表下发，避免手表进入异常状态。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - 智能提醒（安卓：来电/短信/应用消息/邮件/低电/防丢）
struct SmartRemindPage: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @AppStorage("dmap.callRemind") private var call = true
    @AppStorage("dmap.smsRemind") private var sms = true
    @AppStorage("dmap.appRemind") private var app = true
    @AppStorage("dmap.mailRemind") private var mail = false
    @AppStorage("dmap.lowPower") private var lowPower = true
    @AppStorage("dmap.phoneLost") private var phoneLost = false

    var body: some View {
        DMapSubPage(title: "智能提醒") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapToggleRow(icon: "phone.fill", tint: .blue, title: "来电提醒", isOn: $call)
                            DMapRowDivider()
                            DMapToggleRow(icon: "message.fill", tint: .green, title: "短信及应用消息", isOn: $sms)
                            DMapRowDivider()
                            DMapToggleRow(icon: "app.badge.fill", tint: .orange, title: "APP 提醒", isOn: $app)
                            DMapRowDivider()
                            DMapToggleRow(icon: "envelope.fill", tint: .purple, title: "邮件提醒", isOn: $mail)
                            DMapRowDivider()
                            DMapToggleRow(icon: "battery.25percent", tint: .red, title: "低电提醒", isOn: $lowPower)
                            DMapRowDivider()
                            DMapToggleRow(icon: "location.fill.viewfinder", tint: .blue, title: "防丢提醒", isOn: $phoneLost)
                        }
                    }
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapRow(icon: "bell.badge.fill", tint: .orange, title: "测试提醒（发送到手表）",
                                    action: { viewModel.bluetoothManager.sendNotification(type: .call) })
                            DMapRowDivider()
                            DMapRow(icon: "app.badge.fill", tint: .blue, title: "测试应用消息",
                                    action: { viewModel.bluetoothManager.sendNotification(type: .otherApp) })
                        }
                    }
                    Text("iOS 限制：第三方 App 无法读取来电与短信内容，来电/短信自动提醒无法像安卓那样实现。可在上方手动发送测试提醒验证通知帧链路。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - 手表指针校正（真表验证的校时流程）
struct PointerCalibrationPage: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        DMapSubPage(title: "手表指针校正") {
            ScrollView {
                VStack(spacing: 12) {
                    PairingGuideView()

                    DMapCard {
                        VStack(spacing: 0) {
                            DMapRow(icon: "clock.arrow.circlepath", tint: .blue, title: "同步手机时间到手表",
                                    action: { viewModel.manualSyncTime() })
                            DMapRowDivider()
                            DMapRow(icon: "hand.tap.fill", tint: .orange, title: "确认连接（按侧键后）",
                                    action: { viewModel.confirmSideButtonPressed() })
                            DMapRowDivider()
                            DMapNavRow(icon: "link.circle.fill", tint: .blue, title: "连接 / 断开设备") {
                                DeviceConnectPage()
                            }
                        }
                    }
                    DMapCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("校时步骤").font(.system(size: 14, weight: .medium)).foregroundColor(DMapTheme.textDark)
                            Text("1. 长按手表侧键约 3 秒开蓝牙（红灯闪 2 秒）")
                            Text("2. App 自动发送连接确认与授权，手表震动")
                            Text("3. 短按一下手表侧键确认（不可跳过）")
                            Text("4. App 循环发送校时帧，指针自动追到当前时间")
                            Text("5. 收到校时成功帧即完成")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(DMapTheme.textGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                    Text("安卓原版为手指拨动虚拟表盘校针；本版本按真表实测协议直接同步手机时间，效果等价且更简单。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - 心率估测（安卓有该入口，本版本标注未接入）
struct HeartRatePage: View {
    var body: some View {
        DMapSubPage(title: "心率估测") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 14) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red.opacity(0.6))
                            Text("暂无心率数据")
                                .font(.system(size: 15))
                                .foregroundColor(DMapTheme.textGray)
                            Text("最佳测量时间在睡眠清醒后及起床之前")
                                .font(.system(size: 12))
                                .foregroundColor(DMapTheme.tabNormal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                    Text("手表心率上报协议未在真表上验证，本版本不显示模拟数据。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                }
                .padding(.top, 12)
            }
        }
    }
}

#Preview {
    PlayView()
        .environmentObject(DeviceViewModel())
}
