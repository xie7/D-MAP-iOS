import SwiftUI

/// 设备视图 - 扫描、连接、显示设备状态
struct DeviceView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var showScanAlert = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.bluetoothManager.isConnected {
                    DeviceDetailView()
                } else {
                    DeviceScanView()
                }
            }
            .navigationTitle("D-MAP")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 扫描视图

struct DeviceScanView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 20) {
            // 蓝牙状态指示
            BluetoothStatusView()

            // 扫描按钮
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
                    Image(systemName: isScanning ? "stop.circle.fill" : "magnifyingglass.circle.fill")
                        .font(.title2)
                    Text(isScanning ? "停止扫描" : "扫描设备")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isScanning ? Color.red.opacity(0.8) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)

            // 设备列表
            List {
                if viewModel.bluetoothManager.discoveredDevices.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "applewatch")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text(isScanning ? "正在搜索附近的智能手表..." : "点击上方按钮开始扫描")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                    }
                } else {
                    Section("发现的设备") {
                        ForEach(viewModel.bluetoothManager.discoveredDevices) { device in
                            DeviceRow(device: device) {
                                connectToDevice(device)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .onDisappear {
            if isScanning {
                viewModel.bluetoothManager.stopScan()
            }
        }
    }

    private func connectToDevice(_ device: DiscoveredDevice) {
        isScanning = false
        viewModel.bluetoothManager.stopScan()
        Task {
            do {
                try await viewModel.bluetoothManager.connect(to: device)
            } catch {
                print("连接失败: \(error)")
            }
        }
    }
}

// MARK: - 设备行

struct DeviceRow: View {
    let device: DiscoveredDevice
    let onConnect: () -> Void

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 12) {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("信号: \(device.rssi) dBm")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 蓝牙状态

struct BluetoothStatusView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
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

// MARK: - 配对引导视图（真表验证流程）

struct PairingGuideView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(statusColor)
                Spacer()
                if case .synced = viewModel.pairingState {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Text(statusDetail)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 等待按侧键时，提供「我已按键」按钮启动校时；也支持手表按键事件自动触发
            if case .waitingButton = viewModel.pairingState {
                Button(action: { viewModel.confirmSideButtonPressed() }) {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                        Text("我已按手表侧键，开始校时")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }

            if case .syncing = viewModel.pairingState {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在校时，请观察手表指针快速追针…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 校时完成或过程中都可手动重校
            if case .synced = viewModel.pairingState {
                Button(action: { viewModel.manualSyncTime() }) {
                    Label("重新校时", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                }
            }

            // 操作提示（折叠显示）
            DisclosureGroup("如何开蓝牙 / 按键位置") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. 长按手表侧键约 3 秒，直到 12 点位置红灯闪 2 秒，松开。")
                    Text("2. 手表震动后，短按一下侧键确认（配对步骤，不可跳过）。")
                    Text("3. 若表盘停走/红灯常亮/一直振动：用卡针捅后盖 7 点方向 RST 小孔 2–3 秒复位，再重试。")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 8)
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
        case .syncing: return .blue
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
        case .idle:
            return "连接手表后，请长按手表键开蓝牙完成配对。"
        case .handshaking:
            return "已发送连接确认和授权，手表即将震动。"
        case .waitingButton:
            return "手表现在应该已震动。请短按一下侧键，然后点下方按钮（或等手表自动上报按键）开始校时。这一步不能跳过，否则校时会被忽略。"
        case .syncing:
            return "正在循环发送校时帧（含当前时分秒），请观察指针。收到手表确认帧后自动停止。"
        case .synced:
            return "手表时间已同步，指针已追到当前时间。可以正常使用其它功能。"
        }
    }
}

// MARK: - 设备详情视图

struct DeviceDetailView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        List {
            // 配对引导卡片（真表必须：长按开蓝牙→震动→按侧键→校时）
            Section {
                PairingGuideView()
            }

            // 设备状态卡片
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text(viewModel.bluetoothManager.connectedDevice?.name ?? "智能手表")
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 30) {
                        VStack {
                            Text("\(viewModel.bluetoothManager.batteryLevel)%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(batteryColor)
                            Text("电量")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        VStack {
                            Text(viewModel.bluetoothManager.firmwareVersion)
                                .font(.title)
                                .fontWeight(.bold)
                            Text("固件版本")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            // 快捷操作
            Section("快捷操作") {
                Button(action: { viewModel.manualSyncTime() }) {
                    Label("同步时间", systemImage: "clock.arrow.circlepath")
                }

                Button(action: { viewModel.findWatch() }) {
                    Label("查找手表", systemImage: "location.fill.viewfinder")
                }

                Button(action: { viewModel.bluetoothManager.queryVersionAndPower() }) {
                    Label("刷新状态", systemImage: "arrow.clockwise")
                }
            }

            // 断开连接
            Section {
                Button(role: .destructive, action: {
                    viewModel.bluetoothManager.disconnect()
                }) {
                    HStack {
                        Spacer()
                        Text("断开连接")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var batteryColor: Color {
        let level = viewModel.bluetoothManager.batteryLevel
        if level > 50 { return .green }
        if level > 20 { return .orange }
        return .red
    }
}

#Preview {
    DeviceView()
        .environmentObject(DeviceViewModel())
}
