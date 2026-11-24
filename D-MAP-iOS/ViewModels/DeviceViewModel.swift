import Foundation
import Combine
import UIKit

/// 设备 ViewModel - 管理设备连接和状态
final class DeviceViewModel: ObservableObject {

    @Published var bluetoothManager: BluetoothManager
    @Published var alarms: [Alarm] = []
    @Published var sedentarySettings: SedentarySettings = .default
    @Published var notificationSettings: NotificationSettings = .init()
    @Published var isCameraMode = false

    // 「我的一天」展示数据（手表历史数据上报协议未接入，保持占位）
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Int = 0
    @Published var todayActiveMinutes: Int = 0
    @Published var todaySleepMinutes: Int = 0
    @Published var stepGoal: Int = 10000

    private var cancellables = Set<AnyCancellable>()
    private let maxAlarms = 5

    init(bluetoothManager: BluetoothManager = BluetoothManager()) {
        self.bluetoothManager = bluetoothManager
        loadSettings()
        setupObservers()
    }

    private func setupObservers() {
        // 监听拍照触发
        bluetoothManager.$takePhotoTriggered
            .sink { [weak self] triggered in
                if triggered {
                    self?.handleTakePhoto()
                }
            }
            .store(in: &cancellables)

        // 连接本身不再自动校时：真表必须先「握手→按侧键→校时」。
        // 改监听配对状态，校时成功后再把闹钟/久坐等设置推给手表。
        bluetoothManager.$pairingState
            .sink { [weak self] state in
                if case .synced = state {
                    self?.syncSettingsAfterPairing()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 配对流程（真表验证版）

    var pairingState: BluetoothManager.PairingState {
        bluetoothManager.pairingState
    }

    /// 用户按了手表侧键后调用
    func confirmSideButtonPressed() {
        bluetoothManager.confirmSideButtonPressed()
    }

    /// 手动重新校时
    func manualSyncTime() {
        bluetoothManager.manualSyncTime()
    }

    // MARK: - 闹钟管理

    func addAlarm(_ alarm: Alarm) {
        guard alarms.count < maxAlarms else { return }
        alarms.append(alarm)
        saveSettings()
        syncAlarmToWatch(alarm, at: alarms.count - 1)
    }

    func updateAlarm(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = alarm
        saveSettings()
        syncAlarmToWatch(alarm, at: index)
    }

    func deleteAlarm(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        // 先关闭手表上的闹钟
        var disabled = alarm
        disabled.isEnabled = false
        syncAlarmToWatch(disabled, at: index)
        alarms.remove(at: index)
        saveSettings()
    }

    func toggleAlarm(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index].isEnabled.toggle()
        saveSettings()
        syncAlarmToWatch(alarms[index], at: index)
    }

    private func syncAlarmToWatch(_ alarm: Alarm, at index: Int) {
        guard bluetoothManager.isConnected else { return }
        bluetoothManager.setAlarm(
            hour: UInt8(alarm.hour),
            minute: UInt8(alarm.minute),
            repeatMask: alarm.repeatMask,
            isRepeat: alarm.isRepeat,
            index: UInt8(index),
            enabled: alarm.isEnabled
        )
    }

    // MARK: - 久坐提醒

    func updateSedentarySettings(_ settings: SedentarySettings) {
        sedentarySettings = settings
        saveSettings()
        syncSedentaryToWatch()
    }

    private func syncSedentaryToWatch() {
        guard bluetoothManager.isConnected else { return }
        bluetoothManager.setSedentary(
            enabled: sedentarySettings.isEnabled,
            intervalMinutes: UInt8(sedentarySettings.intervalMinutes)
        )
    }

    // MARK: - 时间同步

    func syncTime() {
        bluetoothManager.syncTime()
    }

    // MARK: - 拍照模式

    func enterCameraMode() {
        isCameraMode = true
        bluetoothManager.enterCameraMode()
    }

    func exitCameraMode() {
        isCameraMode = false
        bluetoothManager.exitCameraMode()
    }

    private func handleTakePhoto() {
        // 手表触发拍照 - 这里可以调用系统相机
        // 在实际 App 中可以通过 AVFoundation 拍照
        NotificationCenter.default.post(name: .takePhoto, object: nil)
    }

    // MARK: - 通知推送 (测试用)

    func sendTestNotification(type: BLENotifyType) {
        bluetoothManager.sendNotification(type: type)
    }

    // MARK: - 查找手表

    func findWatch() {
        bluetoothManager.findWatch()
    }

    // MARK: - 配对成功后同步其余设置到手表（校时已由配对流程完成）

    private func syncSettingsAfterPairing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            for (index, alarm) in self.alarms.enumerated() {
                self.syncAlarmToWatch(alarm, at: index)
            }
            self.syncSedentaryToWatch()
        }
    }

    // MARK: - 清除本机历史数据（安卓「设备设置 → 清除历史数据」）

    func clearLocalHistory() {
        alarms.removeAll()
        sedentarySettings = .default
        notificationSettings = .init()
        todaySteps = 0
        todayCalories = 0
        todayActiveMinutes = 0
        todaySleepMinutes = 0
        [alarmsKey, sedentaryKey, notificationKey].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }

    // MARK: - 持久化

    private let alarmsKey = "dmap.alarms"
    private let sedentaryKey = "dmap.sedentary"
    private let notificationKey = "dmap.notifications"

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: alarmsKey)
        }
        if let data = try? JSONEncoder().encode(sedentarySettings) {
            UserDefaults.standard.set(data, forKey: sedentaryKey)
        }
        if let data = try? JSONEncoder().encode(notificationSettings) {
            UserDefaults.standard.set(data, forKey: notificationKey)
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: alarmsKey),
           let alarms = try? JSONDecoder().decode([Alarm].self, from: data) {
            self.alarms = alarms
        }
        if let data = UserDefaults.standard.data(forKey: sedentaryKey),
           let settings = try? JSONDecoder().decode(SedentarySettings.self, from: data) {
            self.sedentarySettings = settings
        }
        if let data = UserDefaults.standard.data(forKey: notificationKey),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            self.notificationSettings = settings
        }
    }
}

extension Notification.Name {
    static let takePhoto = Notification.Name("com.dmap.takePhoto")
}
