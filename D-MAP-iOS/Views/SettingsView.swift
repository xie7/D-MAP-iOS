import SwiftUI

// MARK: - 我的（安卓原版：蓝色渐变波浪头部 + 分组卡片）

struct MineView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        DMapPage(title: "我的") {
            ScrollView {
                VStack(spacing: 0) {
                    // 蓝色渐变头部 + 波浪
                    ZStack(alignment: .bottom) {
                        DMapTheme.headerGradient
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.35))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(.white)
                            }
                            Text("D-MAP")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Text("个人信息 ›")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.bottom, 44)
                        WaveShape()
                            .fill(DMapTheme.pageBg)
                            .frame(height: 26)
                    }
                    .frame(height: 230)

                    // 分组卡片（与安卓「我的」页一致）
                    VStack(spacing: 12) {
                        DMapCard {
                            VStack(spacing: 0) {
                                DMapNavRow(icon: "target", tint: .blue, title: "我的目标") { MyGoalPage() }
                                DMapRowDivider()
                                DMapNavRow(icon: "gearshape.fill", tint: .green, title: "设备设置") { DeviceSettingsPage() }
                                DMapRowDivider()
                                DMapNavRow(icon: "ruler.fill", tint: .teal, title: "单位设置") { UnitSettingsPage() }
                            }
                        }
                        DMapCard {
                            VStack(spacing: 0) {
                                DMapNavRow(icon: "questionmark.circle.fill", tint: .purple, title: "帮助") { HelpPage() }
                                DMapRowDivider()
                                DMapNavRow(icon: "info.circle.fill", tint: .red, title: "关于系统") { AboutPage() }
                            }
                        }
                    }
                    .padding(.top, 6)

                    Spacer(minLength: 20)
                }
            }
        }
    }
}

// MARK: - 波浪形状（安卓「我的」页头部底边）
struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height * 0.55))
        p.addCurve(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.15),
                   control1: CGPoint(x: rect.width * 0.22, y: rect.height * 0.95),
                   control2: CGPoint(x: rect.width * 0.35, y: 0))
        p.addCurve(to: CGPoint(x: rect.width, y: rect.height * 0.6),
                   control1: CGPoint(x: rect.width * 0.68, y: rect.height * 0.35),
                   control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.95))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - 我的目标（安卓：步数目标 / 睡眠目标 / 运动目标）
struct MyGoalPage: View {
    @AppStorage("dmap.stepGoal") private var stepGoal = 10000
    @AppStorage("dmap.sleepGoal") private var sleepGoal = 480
    @AppStorage("dmap.sportGoal") private var sportGoal = 30

    var body: some View {
        DMapSubPage(title: "我的目标") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 0) {
                            StepperRow(title: "日步数目标", value: $stepGoal, range: 1000...50000, step: 1000, unit: "步")
                            DMapRowDivider()
                            StepperRow(title: "睡眠时长目标", value: $sleepGoal, range: 60...720, step: 30, unit: "分")
                            DMapRowDivider()
                            StepperRow(title: "运动目标", value: $sportGoal, range: 5...180, step: 5, unit: "分")
                        }
                    }
                    Text("目标设置完成后会保存在本机；手表目标同步帧未在真表验证，暂不下发。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                }
                .padding(.top, 12)
            }
        }
    }
}

struct StepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(DMapTheme.textDark)
            Spacer()
            Button(action: { value = max(range.lowerBound, value - step) }) {
                Image(systemName: "minus.circle.fill").foregroundColor(DMapTheme.brandBlue)
            }
            Text("\(value) \(unit)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DMapTheme.brandBlue)
                .frame(minWidth: 88)
            Button(action: { value = min(range.upperBound, value + step) }) {
                Image(systemName: "plus.circle.fill").foregroundColor(DMapTheme.brandBlue)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .buttonStyle(.plain)
    }
}

// MARK: - 设备设置（安卓：配对 / 清除历史数据）
struct DeviceSettingsPage: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var showClearConfirm = false

    var body: some View {
        DMapSubPage(title: "设备设置") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapNavRow(icon: "link.circle.fill", tint: .blue, title: "配对") {
                                DeviceConnectPage()
                            }
                            DMapRowDivider()
                            DMapRow(icon: "trash.fill", tint: .red, title: "清除历史数据") {
                                showClearConfirm = true
                            }
                        }
                    }
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapRow(icon: "battery.75percent", tint: .green, title: "设备电量",
                                    detail: viewModel.bluetoothManager.isConnected ? "\(viewModel.bluetoothManager.batteryLevel)%" : "未连接",
                                    showArrow: false)
                            DMapRowDivider()
                            DMapRow(icon: "info.circle.fill", tint: .blue, title: "设备固件版本号",
                                    detail: viewModel.bluetoothManager.firmwareVersion, showArrow: false)
                            DMapRowDivider()
                            DMapRow(icon: "cpu.fill", tint: .purple, title: "系统版本号",
                                    detail: "D-MAP iOS 2.0", showArrow: false)
                        }
                    }
                    Text("清除历史数据仅清除本机记录，手表端数据不受影响。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                }
                .padding(.top, 12)
            }
        }
        .alert("清除历史数据", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                viewModel.clearLocalHistory()
            }
        } message: {
            Text("确定清除本机保存的闹钟与设置记录吗？")
        }
    }
}

// MARK: - 单位设置（安卓：单位 / 时间格式）
struct UnitSettingsPage: View {
    @AppStorage("dmap.unitSystem") private var unitSystem = 0  // 0=公制 1=英制
    @AppStorage("dmap.timeFormat") private var timeFormat = 0  // 0=24小时 1=12小时

    var body: some View {
        DMapSubPage(title: "单位设置") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("单位").font(.system(size: 13)).foregroundColor(DMapTheme.textGray)
                            Picker("", selection: $unitSystem) {
                                Text("公制（公里 / 千克）").tag(0)
                                Text("英制（英里 / 磅）").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(14)
                    }
                    DMapCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("时间格式").font(.system(size: 13)).foregroundColor(DMapTheme.textGray)
                            Picker("", selection: $timeFormat) {
                                Text("24 小时").tag(0)
                                Text("12 小时").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(14)
                    }
                    Text("单位与时间格式为本机显示设置，不影响手表时间。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - 帮助（安卓原版帮助页常见问题）
struct HelpPage: View {
    var body: some View {
        DMapSubPage(title: "帮助") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapNavRow(icon: "questionmark.circle.fill", tint: .blue, title: "为什么我的手表校不准?") {
                                HelpDetailPage(title: "为什么我的手表校不准?", items: [
                                    "1. 确定 APP 和手表蓝牙已经连接上",
                                    "2. APP 中提醒开关已经打开",
                                    "3. 长期佩戴、物理冲击导致指针偏差",
                                    "4. 使用「手表指针校正」功能重新校时"
                                ])
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "antenna.radiowaves.left.and.right", tint: .green, title: "我怎么搜索不到蓝牙?") {
                                HelpDetailPage(title: "我怎么搜索不到蓝牙?", items: [
                                    "1. 长按手表侧键约 3 秒，直到红灯闪 2 秒",
                                    "2. 确定手表和手机离得足够近",
                                    "3. 清除 APP 进程，重新打开",
                                    "4. 若仍失败，捅后盖 RST 小孔复位"
                                ])
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "battery.25percent", tint: .orange, title: "手表没电了 / 低电提醒") {
                                HelpDetailPage(title: "手表没电了", items: [
                                    "手表秒针指向低电刻度，或红灯闪烁，表示电池电量低",
                                    "请更换 CR2430 3V 电池（建议松下 / 索尼）",
                                    "更换后短按 S0 按键检测电池是否安装完成"
                                ])
                            }
                            DMapRowDivider()
                            DMapNavRow(icon: "hand.tap.fill", tint: .purple, title: "查看星期 / 日期 / 电量 / 运动完成度") {
                                HelpDetailPage(title: "手表本地按键功能", items: [
                                    "短按 2 次：查看日期",
                                    "短按 3 次：查看运动完成量（指向 ACT）",
                                    "短按 4 次：查看星期（秒针先指 WEEK 再指当天）",
                                    "这些功能由手表机芯本地驱动，无需连接手机"
                                ])
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }
}

struct HelpDetailPage: View {
    let title: String
    let items: [String]
    var body: some View {
        DMapSubPage(title: "查看帮助") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(DMapTheme.textDark)
                            ForEach(items, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: 13))
                                    .foregroundColor(DMapTheme.textGray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - 关于系统
struct AboutPage: View {
    var body: some View {
        DMapSubPage(title: "关于系统") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 14) {
                            Image(systemName: "watchface.applewatch.case")
                                .font(.system(size: 48))
                                .foregroundColor(DMapTheme.brandBlue)
                            Text("D-MAP")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(DMapTheme.textDark)
                            Text("版本 2.0（安卓界面复刻版）")
                                .font(.system(size: 13))
                                .foregroundColor(DMapTheme.textGray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                    }
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapRow(icon: "checkmark.seal.fill", tint: .green, title: "真表协议验证",
                                    detail: "已通过", showArrow: false)
                            DMapRowDivider()
                            DMapRow(icon: "cpu.fill", tint: .blue, title: "机芯方案",
                                    detail: "smartmovt C004", showArrow: false)
                            DMapRowDivider()
                            DMapRow(icon: "waveform.path.ecg", tint: .purple, title: "通信服务",
                                    detail: "A800 / A801-A805", showArrow: false)
                        }
                    }
                    Text("本 App 按安卓版 D-MAP (V1.0.36) 界面与功能复刻。校时、闹钟、智能提醒、查找手表等帧已在真实手表上验证；步数、睡眠、心率等需手表主动上报的数据暂未接入。")
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

// MARK: - 久坐提醒页（安卓原版功能，保留 BLE 下发）
struct SedentaryPage: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var enabled = false
    @State private var interval = 60

    var body: some View {
        DMapSubPage(title: "久坐提醒") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapToggleRow(icon: "figure.walk", tint: .green, title: "久坐开关", isOn: $enabled)
                            DMapRowDivider()
                            HStack(spacing: 12) {
                                Image(systemName: "timer").foregroundColor(.orange).frame(width: 24)
                                Text("久坐提醒时间").font(.system(size: 15)).foregroundColor(DMapTheme.textDark)
                                Spacer()
                                Stepper("", value: $interval, in: 30...180, step: 15)
                                    .labelsHidden()
                                Text("\(interval) 分")
                                    .font(.system(size: 13))
                                    .foregroundColor(DMapTheme.brandBlue)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                        }
                    }
                    Button(action: {
                        viewModel.bluetoothManager.setSedentary(enabled: enabled, intervalMinutes: UInt8(min(interval, 255)))
                    }) {
                        Text("保存到手表")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(DMapTheme.brandBlue)
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 8)
                    .disabled(!viewModel.bluetoothManager.isConnected)

                    Text("久坐提醒帧来自 APK 逆向，尚未在真表上单独验证。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                }
                .padding(.top, 12)
            }
        }
        .onAppear {
            enabled = viewModel.sedentarySettings.isEnabled
            interval = viewModel.sedentarySettings.intervalMinutes
        }
    }
}

// MARK: - 应用消息提醒页
struct NotificationPage: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var settings = NotificationSettings()

    var body: some View {
        DMapSubPage(title: "应用消息提醒") {
            ScrollView {
                VStack(spacing: 12) {
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapToggleRow(icon: "phone.fill", tint: .blue, title: "来电提醒", isOn: $settings.callEnabled)
                            DMapRowDivider()
                            DMapToggleRow(icon: "message.fill", tint: .green, title: "短信提醒", isOn: $settings.smsEnabled)
                            DMapRowDivider()
                            DMapToggleRow(icon: "bubble.left.fill", tint: .green, title: "微信通知", isOn: $settings.wechatEnabled)
                            DMapRowDivider()
                            DMapToggleRow(icon: "bubble.left.and.bubble.right.fill", tint: .blue, title: "QQ 通知", isOn: $settings.qqEnabled)
                            DMapRowDivider()
                            DMapToggleRow(icon: "app.badge.fill", tint: .orange, title: "其他应用", isOn: $settings.otherAppsEnabled)
                        }
                    }
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapRow(icon: "paperplane.fill", tint: .blue, title: "发送测试通知到手表",
                                    action: { viewModel.bluetoothManager.sendNotification(type: .otherApp) })
                            DMapRowDivider()
                            DMapRow(icon: "phone.down.fill", tint: .red, title: "测试来电提醒",
                                    action: { viewModel.bluetoothManager.sendNotification(type: .call) })
                        }
                    }
                    Text("iOS 系统限制：第三方应用无法直接读取来电与短信内容，自动推送无法像安卓那样实现。这里的开关仅记录本机偏好。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                }
                .padding(.top, 12)
            }
        }
        .onAppear { settings = viewModel.notificationSettings }
    }
}

#Preview {
    MineView()
        .environmentObject(DeviceViewModel())
}
