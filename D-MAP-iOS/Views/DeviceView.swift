import SwiftUI

// MARK: - 我的一天（安卓原版首页：连接状态 + 今日运动数据）

struct DayView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        DMapPage(title: "我的一天") {
            ScrollView {
                VStack(spacing: 12) {
                    // 连接状态条
                    ConnectionBanner()

                    // 今日总步数（圆环 + 目标）
                    DMapCard {
                        VStack(spacing: 14) {
                            Text("今日总步数")
                                .font(.system(size: 14))
                                .foregroundColor(DMapTheme.textGray)
                            ZStack {
                                Circle()
                                    .stroke(DMapTheme.divider, lineWidth: 12)
                                    .frame(width: 150, height: 150)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(DMapTheme.brandBlue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(-90))
                                VStack(spacing: 2) {
                                    Text("\(viewModel.todaySteps)")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(DMapTheme.textDark)
                                    Text("目标 \(viewModel.stepGoal) 步")
                                        .font(.system(size: 12))
                                        .foregroundColor(DMapTheme.textGray)
                                }
                            }
                            Text(viewModel.bluetoothManager.isConnected ? "数据由手表同步" : "暂无历史数据")
                                .font(.system(size: 12))
                                .foregroundColor(DMapTheme.textGray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }

                    // 三项指标
                    HStack(spacing: 8) {
                        DayMetricCard(icon: "flame.fill", tint: .orange,
                                      title: "卡路里消耗", value: viewModel.todayCalories, unit: "千卡")
                        DayMetricCard(icon: "figure.walk", tint: .green,
                                      title: "活动时间", value: viewModel.todayActiveMinutes, unit: "分")
                        DayMetricCard(icon: "bed.double.fill", tint: .purple,
                                      title: "睡眠时长", value: viewModel.todaySleepMinutes, unit: "分")
                    }
                    .padding(.horizontal, 8)

                    // 运动完成度 / 设备信息
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapRow(icon: "chart.pie.fill", tint: .blue, title: "运动完成度",
                                    detail: "查看运动完成度", showArrow: false)
                            DMapRowDivider()
                            DMapRow(icon: "battery.75percent", tint: .green, title: "手表电量",
                                    detail: viewModel.bluetoothManager.isConnected ? "\(viewModel.bluetoothManager.batteryLevel)%" : "未连接",
                                    showArrow: false)
                            DMapRowDivider()
                            DMapRow(icon: "info.circle.fill", tint: .blue, title: "设备固件版本",
                                    detail: viewModel.bluetoothManager.firmwareVersion, showArrow: false)
                        }
                    }

                    // 同步数据按钮（安卓：同步数据成功/失败）
                    Button(action: { viewModel.bluetoothManager.queryVersionAndPower() }) {
                        Text("同步数据")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(DMapTheme.brandBlue)
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 8)
                    .disabled(!viewModel.bluetoothManager.isConnected)
                    .opacity(viewModel.bluetoothManager.isConnected ? 1 : 0.5)

                    Text("说明：步数 / 睡眠 / 心率等历史数据依赖手表主动上报，本版本未接入该协议，故显示占位。校时、闹钟、智能提醒等已验证功能可正常使用。")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                }
                .padding(.top, 12)
            }
        }
    }

    private var progress: CGFloat {
        guard viewModel.stepGoal > 0 else { return 0 }
        return min(CGFloat(viewModel.todaySteps) / CGFloat(viewModel.stepGoal), 1.0)
    }
}

// MARK: - 连接状态横幅
struct ConnectionBanner: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.bluetoothManager.isConnected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(.white)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.bluetoothManager.isConnected ? "设备已经连接" : "设备未连接")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(viewModel.bluetoothManager.isConnected
                     ? (viewModel.bluetoothManager.connectedDevice?.name ?? "D-MAP")
                     : "请先连接手表")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            NavigationLink(destination: DeviceConnectPage()) {
                Text(viewModel.bluetoothManager.isConnected ? "设备详情" : "去连接")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.22))
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(viewModel.bluetoothManager.isConnected ? DMapTheme.brandBlue : Color(red: 0.55, green: 0.62, blue: 0.68))
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
}

// MARK: - 单项指标卡
struct DayMetricCard: View {
    let icon: String
    let tint: Color
    let title: String
    let value: Int
    let unit: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(tint)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(DMapTheme.textGray)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DMapTheme.textDark)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(DMapTheme.textGray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(DMapTheme.cardBg)
        .cornerRadius(6)
    }
}

// MARK: - 分析（安卓原版：周/月切换 + 步数/睡眠柱状图）

struct AnalysisView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var period: Int = 0   // 0=周 1=月
    @State private var metric: Int = 0   // 0=步数 1=睡眠

    private let weekLabels = ["一", "二", "三", "四", "五", "六", "日"]
    private let monthLabels = ["1", "5", "10", "15", "20", "25", "30"]

    var body: some View {
        DMapPage(title: "分析") {
            ScrollView {
                VStack(spacing: 12) {
                    // 周 / 月 分段
                    Picker("", selection: $period) {
                        Text("周").tag(0)
                        Text("月").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 8)

                    // 步数 / 睡眠 分段
                    Picker("", selection: $metric) {
                        Text("运动步数").tag(0)
                        Text("睡眠数据").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 8)

                    // 柱状图卡片
                    DMapCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(metric == 0 ? "运动步数" : "睡眠数据")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DMapTheme.textDark)
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(0..<7, id: \.self) { i in
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(DMapTheme.brandBlue.opacity(0.35))
                                            .frame(height: 12)
                                        Text(period == 0 ? weekLabels[i] : monthLabels[i])
                                            .font(.system(size: 10))
                                            .foregroundColor(DMapTheme.textGray)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 130)
                            DMapEmptyHint(text: "暂无历史数据")
                        }
                        .padding(14)
                    }

                    // 统计卡
                    DMapCard {
                        VStack(spacing: 0) {
                            DMapRow(icon: "figure.walk", tint: .blue, title: "日均步数",
                                    detail: "0 步", showArrow: false)
                            DMapRowDivider()
                            DMapRow(icon: "bed.double.fill", tint: .purple, title: "日均睡眠时长",
                                    detail: "0 分", showArrow: false)
                            DMapRowDivider()
                            DMapRow(icon: "chart.bar.fill", tint: .green, title: "全天步数",
                                    detail: "0 步", showArrow: false)
                        }
                    }

                    Text("运动与睡眠历史数据需手表上报，当前版本暂未接入。")
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

// MARK: - 设备连接页（安卓「附近的设备 / 设备详情」）

struct DeviceConnectPage: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        DMapSubPage(title: viewModel.bluetoothManager.isConnected ? "设备详情" : "附近的设备") {
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.bluetoothManager.isConnected {
                        PairingGuideView()
                            .padding(.horizontal, 8)

                        DMapCard {
                            VStack(spacing: 0) {
                                DMapRow(icon: "battery.75percent", tint: .green, title: "设备电量",
                                        detail: "\(viewModel.bluetoothManager.batteryLevel)%", showArrow: false)
                                DMapRowDivider()
                                DMapRow(icon: "info.circle.fill", tint: .blue, title: "设备固件版本号",
                                        detail: viewModel.bluetoothManager.firmwareVersion, showArrow: false)
                                DMapRowDivider()
                                DMapRow(icon: "clock.arrow.circlepath", tint: .blue, title: "同步手机时间到手表",
                                        action: { viewModel.manualSyncTime() })
                                DMapRowDivider()
                                DMapRow(icon: "location.fill.viewfinder", tint: .orange, title: "查找手表",
                                        action: { viewModel.findWatch() })
                                DMapRowDivider()
                                DMapRow(icon: "arrow.clockwise", tint: .blue, title: "刷新状态",
                                        action: { viewModel.bluetoothManager.queryVersionAndPower() })
                            }
                        }

                        Button(action: { viewModel.bluetoothManager.disconnect() }) {
                            Text("断开连接")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red.opacity(0.85))
                                .cornerRadius(6)
                        }
                        .padding(.horizontal, 8)
                    } else {
                        BluetoothStatusView()
                        DeviceScanView()
                    }
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - 扫描视图（安卓「附近的设备」列表）
struct DeviceScanView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                if isScanning {
                    viewModel.bluetoothManager.stopScan()
                    isScanning = false
                } else {
                    viewModel.bluetoothManager.startScan()
                    isScanning = true
                }
            }) {
                HStack {
                    Image(systemName: isScanning ? "stop.circle.fill" : "magnifyingglass")
                        .font(.system(size: 17))
                    Text(isScanning ? "停止扫描" : "搜索设备")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isScanning ? Color.red.opacity(0.8) : DMapTheme.brandBlue)
                .cornerRadius(6)
            }
            .padding(.horizontal, 8)

            if viewModel.bluetoothManager.discoveredDevices.isEmpty {
                DMapCard {
                    VStack(spacing: 12) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 40))
                            .foregroundColor(DMapTheme.tabNormal)
                        Text(isScanning ? "正在搜索 D-MAP 手表…" : "长按手表侧键开蓝牙后，点击搜索设备")
                            .font(.system(size: 13))
                            .foregroundColor(DMapTheme.textGray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                DMapCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.bluetoothManager.discoveredDevices.enumerated()), id: \.element.id) { idx, device in
                            DeviceRow(device: device) {
                                connectToDevice(device)
                            }
                            if idx < viewModel.bluetoothManager.discoveredDevices.count - 1 {
                                DMapRowDivider()
                            }
                        }
                    }
                }
            }
        }
        .onDisappear { if isScanning { viewModel.bluetoothManager.stopScan() } }
    }

    private func connectToDevice(_ device: DiscoveredDevice) {
        isScanning = false
        viewModel.bluetoothManager.stopScan()
        Task {
            do { try await viewModel.bluetoothManager.connect(to: device) }
            catch { print("连接失败: \(error)") }
        }
    }
}

// MARK: - 设备行（安卓：信号图标 + RSSI + 名称）
struct DeviceRow: View {
    let device: DiscoveredDevice
    let onConnect: () -> Void

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 12) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 17))
                    .foregroundColor(DMapTheme.brandBlue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 15))
                        .foregroundColor(DMapTheme.textDark)
                    Text("\(device.rssi) dBm")
                        .font(.system(size: 11))
                        .foregroundColor(DMapTheme.textGray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(DMapTheme.tabNormal)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 蓝牙状态
struct BluetoothStatusView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 12))
                .foregroundColor(DMapTheme.textGray)
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private var statusColor: Color {
        switch viewModel.bluetoothManager.bluetoothState {
        case .poweredOn: return .green
        case .poweredOff: return .red
        case .unsupported: return .orange
        default: return .gray
        }
    }
    private var statusText: String {
        switch viewModel.bluetoothManager.bluetoothState {
        case .poweredOn: return "蓝牙已开启"
        case .poweredOff: return "蓝牙已关闭"
        case .unsupported: return "设备不支持蓝牙"
        case .unauthorized: return "未授权蓝牙权限"
        default: return "蓝牙状态未知"
        }
    }
}

// MARK: - 配对引导（真表验证流程，保留上一版逻辑，改安卓配色）
struct PairingGuideView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        DMapCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: statusIcon)
                        .font(.system(size: 18))
                        .foregroundColor(statusColor)
                    Text(statusTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(statusColor)
                    Spacer()
                    if case .synced = viewModel.pairingState {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
                Text(statusDetail)
                    .font(.system(size: 12))
                    .foregroundColor(DMapTheme.textGray)
                    .fixedSize(horizontal: false, vertical: true)

                if case .waitingButton = viewModel.pairingState {
                    Button(action: { viewModel.confirmSideButtonPressed() }) {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                            Text("我已按手表侧键，开始校时")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.orange)
                        .cornerRadius(6)
                    }
                }
                if case .syncing = viewModel.pairingState {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("正在校时，请观察手表指针快速追针…")
                            .font(.system(size: 12))
                            .foregroundColor(DMapTheme.textGray)
                    }
                }
                if case .synced = viewModel.pairingState {
                    Button(action: { viewModel.manualSyncTime() }) {
                        Text("重新校时")
                            .font(.system(size: 13))
                            .foregroundColor(DMapTheme.brandBlue)
                    }
                }
                DisclosureGroup("如何开蓝牙 / 按键位置") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. 长按手表侧键约 3 秒，直到 12 点位置红灯闪 2 秒，松开。")
                        Text("2. 手表震动后，短按一下侧键确认（配对步骤，不可跳过）。")
                        Text("3. 若表盘停走/红灯常亮/一直振动：用卡针捅后盖 7 点方向 RST 小孔 2–3 秒复位，再重试。")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(DMapTheme.textGray)
                    .padding(.top, 4)
                }
                .font(.system(size: 13))
                .foregroundColor(DMapTheme.textDark)
            }
            .padding(14)
        }
    }

    private var statusIcon: String {
        switch viewModel.pairingState {
        case .idle: return "questionmark.circle"
        case .handshaking: return "wave.3.right"
        case .waitingButton: return "hand.tap"
        case .syncing: return "clock.arrow.circlepath"
        case .synced: return "checkmark.circle"
        }
    }
    private var statusColor: Color {
        switch viewModel.pairingState {
        case .idle: return .gray
        case .handshaking, .waitingButton: return .orange
        case .syncing: return DMapTheme.brandBlue
        case .synced: return .green
        }
    }
    private var statusTitle: String {
        switch viewModel.pairingState {
        case .idle: return "等待连接"
        case .handshaking: return "正在与手表握手…"
        case .waitingButton: return "请按一下手表侧键确认"
        case .syncing: return "正在校时"
        case .synced: return "校时成功"
        }
    }
    private var statusDetail: String {
        switch viewModel.pairingState {
        case .idle: return "连接手表后，请长按手表键开蓝牙完成配对。"
        case .handshaking: return "已发送连接确认和授权，手表即将震动。"
        case .waitingButton: return "手表震动后请短按一下侧键，再点下方按钮开始校时。这一步不能跳过，否则校时会被忽略。"
        case .syncing: return "正在循环发送校时帧（含当前时分秒），请观察指针。收到手表确认帧后自动停止。"
        case .synced: return "手表时间已同步，指针已追到当前时间。可以正常使用其它功能。"
        }
    }
}

#Preview {
    DayView()
        .environmentObject(DeviceViewModel())
}
