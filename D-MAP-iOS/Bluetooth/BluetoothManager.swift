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

    // MARK: - 私有属性

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var writeDataCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    private var versionCharacteristic: CBCharacteristic?

    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var writeQueue: DispatchQueue = DispatchQueue(label: "com.dmap.ble.write", qos: .userInitiated)

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
        peripheral = nil
        writeCharacteristic = nil
        writeDataCharacteristic = nil
        notifyCharacteristic = nil
        batteryCharacteristic = nil
        versionCharacteristic = nil
        isConnected = false
        connectedDevice = nil
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
                peripheral.discoverCharacteristics([
                    BLEConstants.writeCodeCharacteristicUUID,
                    BLEConstants.writeDataCharacteristicUUID,
                    BLEConstants.notifyCharacteristicUUID
                ], for: service)
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
            switch char.uuid {
            case BLEConstants.writeCodeCharacteristicUUID:
                writeCharacteristic = char
            case BLEConstants.writeDataCharacteristicUUID:
                writeDataCharacteristic = char
            case BLEConstants.notifyCharacteristicUUID:
                notifyCharacteristic = char
                // 开启通知
                peripheral.setNotifyValue(true, for: char)
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

        // 所有特征值发现后，发送时间同步和版本查询
        if writeCharacteristic != nil, notifyCharacteristic != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.syncTime()
                self?.queryVersionAndPower()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case BLEConstants.notifyCharacteristicUUID:
            handleNotifyData(data)
        case BLEConstants.batteryLevelCharacteristicUUID:
            if let byte = data.first {
                batteryLevel = Int(byte)
            }
        case BLEConstants.firmwareVersionCharacteristicUUID:
            if let version = String(data: data, encoding: .utf8) {
                firmwareVersion = version
            }
        default:
            break
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

        switch result {
        case .takePhoto:
            DispatchQueue.main.async {
                self.takePhotoTriggered = true
                // 重置标志供下次触发
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.takePhotoTriggered = false
                }
            }
        case .findPhone:
            // 可以触发手机震动/响铃
            break
        case .versionAndPower(let version, let power):
            DispatchQueue.main.async {
                self.firmwareVersion = version
                self.batteryLevel = power
            }
        case .timeSyncSuccess:
            break
        case .authSuccess:
            break
        case .sedentaryResult(let minutes):
            break
        case .endCall:
            break
        case .raw, .invalid:
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
