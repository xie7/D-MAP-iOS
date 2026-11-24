import CoreBluetooth
import Combine

/// 蓝牙管理器 - 负责扫描、连接、读写智能手表
final class BluetoothManager: NSObject, ObservableObject {

    // MARK: - 发布状态

    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDevice: DiscoveredDevice?
    @Published var isConnected = false
    @Published var batteryLevel: Int = 0
    @Published var firmwareVersion: String = "未知"
    @Published var lastError: String?
    @Published var takePhotoTriggered = false  // 手表触发拍照

    /// 配对/校时状态机 —— 真表必须先「握手→按键确认→校时」，见 PairingState
    @Published var pairingState: PairingState = .idle

    // MARK: - 私有属性

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var writeDataCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    private var versionCharacteristic: CBCharacteristic?
    /// 真表在 A801~A805 多个特征上都可能回包，全部订阅
    private var notifyCharacteristics: [CBCharacteristic] = []

    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var writeQueue: DispatchQueue = DispatchQueue(label: "com.dmap.ble.write", qos: .userInitiated)
    private var syncRetryTask: Task<Void, Never>?
    private var didBeginPairing = false

    // MARK: - 配对状态机

    enum PairingState: Equatable {
        case idle
        case handshaking   // 已发连接确认+授权，等待手表震动
        case waitingButton // 手表已震动，等待用户按侧键确认
        case syncing       // 正在循环重发校时帧
        case synced        // 校时成功（收到 0x0D 确认帧）
    }

    // MARK: - 初始化

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - 扫描

    func startScan() {
        guard centralManager.state == .poweredOn else {
            lastError = "蓝牙未开启"
            return
        }
        discoveredDevices.removeAll()
        isScanning = true
        // 扫描所有设备，不过滤服务 UUID（因为手表可能未广播服务 UUID）
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    // MARK: - 连接

    func connect(to device: DiscoveredDevice) async throws {
        stopScan()
        peripheral = device.peripheral
        peripheral?.delegate = self

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectionContinuation = cont
            centralManager.connect(device.peripheral, options: nil)
        }
    }

    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanup()
    }

    private func cleanup() {
        syncRetryTask?.cancel()
        syncRetryTask = nil
        didBeginPairing = false
        notifyCharacteristics.removeAll()
        peripheral = nil
        writeCharacteristic = nil
        writeDataCharacteristic = nil
        notifyCharacteristic = nil
        batteryCharacteristic = nil
        versionCharacteristic = nil
        isConnected = false
        connectedDevice = nil
        pairingState = .idle
    }

    // MARK: - 配对流程（真表验证版）

    /// 连接成功后由 BLE 层自动调用：发连接确认 + 授权，让手表震动
    private func beginPairing() {
        guard !didBeginPairing, writeCharacteristic != nil else { return }
        didBeginPairing = true
        pairingState = .handshaking
        // 真表实测：连接确认(0x0A/0x02) → 授权(0x0A/0x03)，写 A801
        sendCommand(BLEProtocol.connectionConfirm())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self, self.pairingState == .handshaking else { return }
            self.sendCommand(BLEProtocol.authorization())
            self.pairingState = .waitingButton
            // 兜底：真表脚本实测是等待固定时间后无条件循环发校时帧。
            // 若 8 秒内用户没点「我已按键」也没收到按键回包，自动开始校时循环，
            // 保证不因按键事件未回传而卡死（用户仍可在此期间手动按侧键）。
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
                guard let self = self, self.pairingState == .waitingButton else { return }
                self.startSyncLoop()
            }
        }
    }

    /// 用户按了手表侧键后调用（UI 有按钮，也可由手表按键事件自动触发）
    func confirmSideButtonPressed() {
        guard isConnected else { return }
        startSyncLoop()
    }

    /// 校时：按实测循环重发校时帧，直到收到 0x0D 校时成功帧
    private func startSyncLoop() {
        syncRetryTask?.cancel()
        pairingState = .syncing
        syncRetryTask = Task { [weak self] in
            guard let self = self else { return }
            for _ in 0..<7 {
                if Task.isCancelled { return }
                // 每次都用当前时间，避免追针过程中时间漂移
                self.sendCommand(BLEProtocol.timeSync())
                try? await Task.sleep(nanoseconds: 4_000_000_000)  // 4 秒
            }
        }
    }

    /// 手动重新校时（已配对状态下从 UI 触发）
    func manualSyncTime() {
        guard isConnected else { return }
        startSyncLoop()
    }

    // MARK: - 发送数据

    func sendCommand(_ bytes: [UInt8]) {
        guard let peripheral = peripheral,
              let writeChar = writeCharacteristic else {
            lastError = "设备未连接或特征值未发现"
            return
        }
        let data = Data(bytes)
        writeQueue.async { [weak self] in
            peripheral.writeValue(data, for: writeChar, type: .withResponse)
        }
    }

    func sendData(_ bytes: [UInt8]) {
        guard let peripheral = peripheral,
              let writeDataChar = writeDataCharacteristic else {
            // 降级到 write characteristic
            sendCommand(bytes)
            return
        }
        let data = Data(bytes)
        writeQueue.async { [weak self] in
            peripheral.writeValue(data, for: writeDataChar, type: .withResponse)
        }
    }

    // MARK: - 便捷命令

    func syncTime() {
        sendCommand(BLEProtocol.timeSync())
    }

    func setAlarm(hour: UInt8, minute: UInt8, repeatMask: UInt8,
                  isRepeat: Bool, index: UInt8, enabled: Bool) {
        sendCommand(BLEProtocol.setAlarm(hour: hour, minute: minute, repeatMask: repeatMask,
                                          isRepeat: isRepeat, index: index, enabled: enabled))
    }

    func setSedentary(enabled: Bool, intervalMinutes: UInt8) {
        if enabled {
            sendCommand(BLEProtocol.setSedentary(intervalMinutes: intervalMinutes))
        } else {
            sendCommand(BLEProtocol.disableSedentary())
        }
    }

    func sendNotification(type: BLENotifyType) {
        sendCommand(BLEProtocol.sendNotify(type: type))
    }

    func enterCameraMode() {
        sendCommand(BLEProtocol.setCameraMode(enter: true))
    }

    func exitCameraMode() {
        sendCommand(BLEProtocol.setCameraMode(enter: false))
    }

    func findWatch() {
        sendCommand(BLEProtocol.findWatch())
    }

    func queryVersionAndPower() {
        sendCommand(BLEProtocol.queryVersionAndPower())
    }

    func readBattery() {
        guard let peripheral = peripheral,
              let batteryChar = batteryCharacteristic else { return }
        peripheral.readValue(for: batteryChar)
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn {
            lastError = nil
        } else {
            lastError = "蓝牙状态: \(central.state.rawValue)"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // 过滤掉无名称设备和已知设备
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        guard !name.isEmpty else { return }

        // 去重
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let device = DiscoveredDevice(peripheral: peripheral, name: name, rssi: RSSI.intValue)
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectedDevice = DiscoveredDevice(peripheral: peripheral,
                                           name: peripheral.name ?? "未知设备",
                                           rssi: 0)
        // 发现服务
        peripheral.discoverServices([
            BLEConstants.mainServiceUUID,
            BLEConstants.batteryServiceUUID,
            BLEConstants.deviceInfoServiceUUID
        ])
        connectionContinuation?.resume()
        connectionContinuation = nil
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionContinuation?.resume(throwing: error ?? BLEError.connectionFailed)
        connectionContinuation = nil
        lastError = "连接失败: \(error?.localizedDescription ?? "未知错误")"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cleanup()
        lastError = "设备已断开"
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            switch service.uuid {
            case BLEConstants.mainServiceUUID:
                // 发现 A800 服务下全部特征（A801~A805），真表回包不止在一个特征上
                peripheral.discoverCharacteristics(nil, for: service)
            case BLEConstants.batteryServiceUUID:
                peripheral.discoverCharacteristics([BLEConstants.batteryLevelCharacteristicUUID], for: service)
            case BLEConstants.deviceInfoServiceUUID:
                peripheral.discoverCharacteristics([
                    BLEConstants.firmwareVersionCharacteristicUUID,
                    BLEConstants.manufacturerCharacteristicUUID
                ], for: service)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for char in characteristics {
            let uuid = char.uuid.uuidString.uppercased()

            // ---- A800 服务：A801~A805 ----
            if uuid.contains("A801") {
                writeCharacteristic = char            // 命令写入 A801（真表实测）
            } else if uuid.contains("A802") {
                writeDataCharacteristic = char        // 数据写 / 也回包
            }
            // 真表在 A802/A803/A804/A805 上都可能发回包，订阅所有带 notify/indicate 的 A80x 特征
            if uuid.contains("A80"), char.properties.contains(.notify) || char.properties.contains(.indicate) {
                notifyCharacteristics.append(char)
                peripheral.setNotifyValue(true, for: char)
            }
            if uuid.contains("A803") {
                notifyCharacteristic = char           // 兼容旧逻辑
            }

            // ---- 标准服务 ----
            switch char.uuid {
            case BLEConstants.batteryLevelCharacteristicUUID:
                batteryCharacteristic = char
                peripheral.readValue(for: char)
            case BLEConstants.firmwareVersionCharacteristicUUID:
                versionCharacteristic = char
                peripheral.readValue(for: char)
            default:
                break
            }
        }

        // 特征发现完成 → 启动真表配对握手（连接确认+授权→等待按侧键→校时），不再一连接就校时
        if writeCharacteristic != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.beginPairing()
                self?.queryVersionAndPower()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case BLEConstants.batteryLevelCharacteristicUUID:
            if let byte = data.first { batteryLevel = Int(byte) }
        case BLEConstants.firmwareVersionCharacteristicUUID:
            if let version = String(data: data, encoding: .utf8) { firmwareVersion = version }
        default:
            // 真表在 A801~A805 任一特征都可能回包；A80x 一律交给协议解析
            let uuid = characteristic.uuid.uuidString.uppercased()
            if uuid.contains("A80") {
                handleNotifyData(data)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            lastError = "写入失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 处理接收数据

    private func handleNotifyData(_ data: Data) {
        let result = BLEProtocol.parseReceiveData(data)
        print("[D-MAP] 回包 \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")

        switch result {
        case .takePhoto:
            DispatchQueue.main.async {
                self.takePhotoTriggered = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.takePhotoTriggered = false
                }
            }
        case .findPhone:
            break
        case .versionAndPower(let version, let power):
            DispatchQueue.main.async {
                self.firmwareVersion = version
                self.batteryLevel = power
            }
        case .timeSyncSuccess:
            // 校时成功帧 0x0D → 停止重发循环，标记完成
            DispatchQueue.main.async {
                self.syncRetryTask?.cancel()
                self.syncRetryTask = nil
                if self.pairingState == .syncing { self.pairingState = .synced }
            }
        case .watchStatus(let power, _):
            // 完整状态包，电量在 byte[9]
            DispatchQueue.main.async { self.batteryLevel = power }
        case .handshakeAck(let param, _):
            // cmd=0x0A 短应答（如 param=0x14），说明握手被接收
            print("[D-MAP] 握手应答 param=0x\(String(format: "%02x", param))")
        case .buttonEvent(let param, _):
            // 手表按键事件：若正在等待按侧键，自动进入校时
            DispatchQueue.main.async {
                if self.pairingState == .waitingButton || self.pairingState == .handshaking {
                    self.startSyncLoop()
                }
                print("[D-MAP] 按键事件 param=0x\(String(format: "%02x", param))")
            }
        case .authSuccess, .sedentaryResult, .endCall, .raw, .invalid:
            break
        }
    }
}

// MARK: - 错误类型

enum BLEError: Error {
    case connectionFailed
    case serviceNotFound
    case characteristicNotFound
    case writeFailed
}

// MARK: - 发现的设备模型

struct DiscoveredDevice: Identifiable, Hashable {
    let id = UUID()
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.peripheral.identifier == rhs.peripheral.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(peripheral.identifier)
    }
}
