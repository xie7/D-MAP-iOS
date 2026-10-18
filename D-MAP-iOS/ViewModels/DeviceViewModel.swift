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

        // 监听连接状态，连接成功后同步设置
        bluetoothManager.$isConnected
            .sink { [weak self] connected in
                if connected {
                    self?.syncAllSettingsToWatch()
                }
            }
            .store(in: &cancellables)
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

    // MARK: - 同步所有设置到手表

    private func syncAllSettingsToWatch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.syncTime()
            for (index, alarm) in self.alarms.enumerated() {
                self.syncAlarmToWatch(alarm, at: index)
            }
            self.syncSedentaryToWatch()
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
