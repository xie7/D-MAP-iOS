import Foundation

/// BLE 协议帧封装与解析
///
/// 帧格式: [0x24][len][0x02][cmd][sub][params...][checksum]
/// - byte[0] = 0x24 ('$') 帧头
/// - byte[1] = len 数据长度 (从 byte[2] 到最后一个参数 = 3 + params.count)
/// - byte[2] = 0x02 固定命令类型
/// - byte[3] = cmd 命令字
/// - byte[4] = sub 子命令
/// - byte[5..N] = params 参数
/// - byte[N+1] = checksum 校验和 (sum(byte[3..<N+1]) & 0xFF)
///
/// 从 Android 版 D-MAP (smartmovt 方案) SimpleBleUtils.java 逆向提取
struct BLEProtocol {

    static let frameHeader: UInt8 = 0x24
    static let commandType: UInt8 = 0x02

    /// 计算校验和: 从 byte[3] 累加到校验位之前
    static func checksum(_ bytes: [UInt8]) -> UInt8 {
        guard bytes.count >= 4 else { return 0 }
        var sum: UInt8 = 0
        for i in 3..<(bytes.count - 1) {
            sum = sum &+ bytes[i]
        }
        return sum
    }

    /// 构建完整帧
    /// - Parameters:
    ///   - cmd: 命令字 (byte[3])
    ///   - sub: 子命令 (byte[4])
    ///   - params: 参数数据 (从 byte[5] 开始)
    /// - Returns: 完整的帧字节数组
    static func buildFrame(cmd: UInt8, sub: UInt8, params: [UInt8]) -> [UInt8] {
        // 帧: header + len + type + cmd + sub + params + checksum
        let totalLen = 2 + 3 + params.count + 1  // 2(header+len) + 3(type+cmd+sub) + params + 1(checksum)
        var frame = [UInt8](repeating: 0, count: totalLen)
        frame[0] = frameHeader
        frame[1] = UInt8(3 + params.count)  // type + cmd + sub + params
        frame[2] = commandType
        frame[3] = cmd
        frame[4] = sub
        for (i, p) in params.enumerated() {
            frame[5 + i] = p
        }
        frame[totalLen - 1] = checksum(frame)
        return frame
    }

    // MARK: - 具体命令构建

    /// 时间同步 / 追针 (cmd=0x05, sub=0x03, params=[hh,mm,ss])
    /// 真表实测帧: 24 06 02 05 03 hh mm ss chk
    /// 对应 Android: toUpdateWatchTime(B,B,B) —— 只带时分秒，不带年月日星期
    /// - Important: 必须在「连接确认 + 授权 + 用户按侧键确认」之后发送，否则手表只回 aa ab 通用应答并忽略校时
    static func timeSync(date: Date = Date()) -> [UInt8] {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = UInt8(comps.hour ?? 0)
        let minute = UInt8(comps.minute ?? 0)
        let second = UInt8(comps.second ?? 0)
        return buildFrame(cmd: 0x05, sub: 0x03, params: [hour, minute, second])
    }

    /// 连接确认帧: 24 04 02 0a 01 02 0d
    /// 对应 Android: connSuccee —— 写入 A801 后手表震动
    static func connectionConfirm() -> [UInt8] {
        return buildFrame(cmd: 0x0A, sub: 0x01, params: [0x02])
    }

    /// 授权帧: 24 04 02 0a 01 03 0e
    /// 对应 Android: authorization —— 配合连接确认，手表震动后等待用户按侧键确认
    static func authorization() -> [UInt8] {
        return buildFrame(cmd: 0x0A, sub: 0x01, params: [0x03])
    }

    /// 闹钟设置 (cmd=0x09, sub=0x01)
    /// 对应 Android: setAlarmEventToWatch()
    /// - Parameters:
    ///   - hour: 小时 (0-23)
    ///   - minute: 分钟 (0-59)
    ///   - repeatMask: 重复日期位掩码 (bit0=周一 ... bit6=周日)
    ///   - isRepeat: 是否重复
    ///   - index: 闹钟序号 (0-4, 对应手表 1-5)
    ///   - enabled: 是否开启
    static func setAlarm(hour: UInt8, minute: UInt8, repeatMask: UInt8,
                         isRepeat: Bool, index: UInt8, enabled: Bool) -> [UInt8] {
        let params: [UInt8] = [
            hour,
            minute,
            repeatMask,
            isRepeat ? 1 : 0,
            index + 1,
            enabled ? 1 : 0
        ]
        return buildFrame(cmd: 0x09, sub: 0x01, params: params)
    }

    /// 久坐提醒设置 (cmd=0x0A, sub=0x01)
    /// 对应 Android: setSitToWatch()
    /// - Parameters:
    ///   - intervalMinutes: 久坐提醒间隔 (分钟)
    /// - Note: Android 源码中 sitMode 参数未写入帧，固定 byte[5]=0x05
    static func setSedentary(intervalMinutes: UInt8) -> [UInt8] {
        let params: [UInt8] = [0x05, intervalMinutes]
        return buildFrame(cmd: 0x0A, sub: 0x01, params: params)
    }

    /// 关闭久坐提醒
    /// 发送间隔为 0 表示关闭
    static func disableSedentary() -> [UInt8] {
        let params: [UInt8] = [0x05, 0x00]
        return buildFrame(cmd: 0x0A, sub: 0x01, params: params)
    }

    /// 通知推送 (cmd=0x02)
    /// 对应 Android: getNotiflyByte()
    /// - Parameters:
    ///   - type: 通知类型
    ///   - isUnread: 是否未读 (true=未读推送, false=已读清除)
    static func sendNotify(type: BLENotifyType, isUnread: Bool = true) -> [UInt8] {
        // Android: getNotiflyByte 返回 [0x24, 5, 0x02, 0x02, 1/2, 0, type, checksum]
        let params: [UInt8] = [isUnread ? 1 : 2, 0x00, type.rawValue]
        return buildFrame(cmd: 0x02, sub: 0x01, params: params)
    }

    /// 进入/退出拍照模式 (cmd=0x03, sub=0x02)
    /// 对应 Android: setCameraActivity()
    static func setCameraMode(enter: Bool) -> [UInt8] {
        let params: [UInt8] = [enter ? 1 : 2]
        return buildFrame(cmd: 0x03, sub: 0x02, params: params)
    }

    /// 查找手表 (cmd=0x03, sub=0x01)
    /// 对应 Android: findTheWatch()
    static func findWatch() -> [UInt8] {
        return buildFrame(cmd: 0x03, sub: 0x01, params: [])
    }

    /// 查询版本和电量 (cmd=0x0C, sub=0x01)
    /// 对应 Android: getFWversionAndFWPower()
    static func queryVersionAndPower() -> [UInt8] {
        let params: [UInt8] = [0x01]
        return buildFrame(cmd: 0x0C, sub: 0x01, params: params)
    }

    /// 防丢提醒设置 (cmd=0x03, sub=0x04)
    /// 对应 Android: setPhoneLostType()
    static func setPhoneLostNotify(enabled: Bool) -> [UInt8] {
        let params: [UInt8] = [enabled ? 1 : 2]
        return buildFrame(cmd: 0x03, sub: 0x04, params: params)
    }

    // MARK: - 接收数据解析

    /// 解析接收到的数据
    /// - Parameter data: 从 notify 特征值收到的原始数据
    /// - Returns: 解析结果
    ///
    /// 真表实测回包格式与旧逆向不同：命令字在 **byte[3]**（不是 byte[2]）。
    /// 例: 24 04 02 0d 01 01 0f  → cmd=0x0D 校时成功
    ///     24 04 02 0a 01 14 1f  → cmd=0x0A 状态/授权应答
    ///     24 11 02 0a 01 13 ...  → cmd=0x0A 完整状态包(含电量/时间)
    static func parseReceiveData(_ data: Data) -> BLEParseResult {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, bytes[0] == frameHeader, bytes[2] == commandType else {
            return .invalid
        }

        // 校验和: sum(byte[3..<count-1]) & 0xFF，须匹配最后一位
        let expected = checksum(bytes)
        guard expected == bytes[bytes.count - 1] else {
            return .raw(bytes)  // 校验不符，仍返回原始供调试
        }

        let command = bytes[3]
        let sub = bytes[4]

        switch command {
        case 0x0D: // 校时成功确认: 24 04 02 0d 01 01 0f
            return .timeSyncSuccess

        case 0x0A: // 状态/授权应答
            if bytes.count >= 16, sub == 0x01 {
                // 完整状态包: cmd=0x0A sub=0x01 后带电量等数据
                // 实测 24 11 02 0a 01 13 30 ff ff 10 27 ... 电量=0x27(39%)
                let power = bytes[9]
                return .watchStatus(power: Int(power), raw: bytes)
            }
            if bytes.count >= 6 {
                // 短应答 24 04 02 0a 01 xx xx，参数在 byte[5]
                return .handshakeAck(param: bytes[5], raw: bytes)
            }
            return .raw(bytes)

        case 0x1A: // 按键/应答事件: 24 04 02 1a 01 02 1d
            if bytes.count >= 6 {
                return .buttonEvent(param: bytes[5], raw: bytes)
            }

        case 0x0C: // 版本/电量返回
            if bytes.count >= 8 {
                let version = String(format: "%d.%d", bytes[5], bytes[6])
                let power = Int(bytes[7])
                return .versionAndPower(version: version, power: power)
            }

        case 0x03: // 手表按键事件 (cmd=0x03)
            if bytes.count >= 6 {
                switch bytes[5] {
                case 0x01: return .findPhone
                case 0x02: return .takePhoto
                case 0x03: return .endCall
                default: break
                }
            }

        case 0x15: // 21 - 久坐提醒返回
            if bytes.count >= 7 {
                return .sedentaryResult(minutes: bytes[6])
            }

        case 0x13: // 19 - 授权成功（旧逆向保留兼容）
            return .authSuccess

        case 0x14: // 20 - 时间同步成功（旧逆向保留兼容）
            return .timeSyncSuccess

        default:
            break
        }

        return .raw(bytes)
    }
}

/// 解析结果枚举
enum BLEParseResult {
    case invalid
    case timeSyncSuccess
    case authSuccess
    case handshakeAck(param: UInt8, raw: [UInt8])  // cmd=0x0A 短应答
    case watchStatus(power: Int, raw: [UInt8])      // cmd=0x0A 完整状态包
    case buttonEvent(param: UInt8, raw: [UInt8])    // cmd=0x1A 按键事件
    case sedentaryResult(minutes: UInt8)
    case findPhone
    case takePhoto
    case endCall
    case versionAndPower(version: String, power: Int)
    case raw([UInt8])
}
