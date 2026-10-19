import Foundation

/// 闹钟模型
struct Alarm: Identifiable, Codable, Equatable {
    var id = UUID()
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var isRepeat: Bool
    var repeatDays: Set<Weekday>  // 重复的星期

    /// 重复日期位掩码 (bit0=周一 ... bit6=周日)
    var repeatMask: UInt8 {
        var mask: UInt8 = 0
        for day in repeatDays {
            mask |= (UInt8(1) << day.rawValue)
        }
        return mask
    }

    /// 时间显示字符串
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// 重复描述
    var repeatDescription: String {
        if !isRepeat { return "仅一次" }
        if repeatDays.count == 7 { return "每天" }
        if repeatDays.isEmpty { return "仅一次" }
        let sorted = repeatDays.sorted { $0.rawValue < $1.rawValue }
        return sorted.map { $0.shortName }.joined(separator: " ")
    }

    static let `default` = Alarm(hour: 7, minute: 0, isEnabled: false,
                                  isRepeat: true, repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday])
}

/// 星期
enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case monday = 0
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .monday: return "一"
        case .tuesday: return "二"
        case .wednesday: return "三"
        case .thursday: return "四"
        case .friday: return "五"
        case .saturday: return "六"
        case .sunday: return "日"
        }
    }

    var fullName: String {
        switch self {
        case .monday: return "周一"
        case .tuesday: return "周二"
        case .wednesday: return "周三"
        case .thursday: return "周四"
        case .friday: return "周五"
        case .saturday: return "周六"
        case .sunday: return "周日"
        }
    }
}

/// 久坐提醒设置
struct SedentarySettings: Codable, Equatable {
    var isEnabled: Bool
    var intervalMinutes: Int  // 提醒间隔 (分钟)
    var startHour: Int        // 开始时间 (时)
    var startMinute: Int      // 开始时间 (分)
    var endHour: Int          // 结束时间 (时)
    var endMinute: Int        // 结束时间 (分)
    var breakDuration: Int    // 休息时长 (分钟)

    static let `default` = SedentarySettings(
        isEnabled: false,
        intervalMinutes: 60,
        startHour: 9, startMinute: 0,
        endHour: 18, endMinute: 0,
        breakDuration: 5
    )
}

/// 通知同步设置
struct NotificationSettings: Codable, Equatable {
    var callEnabled: Bool = true
    var smsEnabled: Bool = true
    var wechatEnabled: Bool = true
    var qqEnabled: Bool = false
    var otherAppsEnabled: Bool = true
}

/// 手表设备信息
struct WatchInfo: Equatable {
    var name: String
    var firmwareVersion: String
    var batteryLevel: Int
    var isConnected: Bool
}
