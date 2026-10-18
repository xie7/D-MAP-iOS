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

// MARK: - 设备详情视图

struct DeviceDetailView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        List {
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
                Button(action: { viewModel.syncTime() }) {
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
