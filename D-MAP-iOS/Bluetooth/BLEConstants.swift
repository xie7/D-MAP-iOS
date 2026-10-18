import CoreBluetooth

/// BLE UUID 常量 — 从 Android 版 D-MAP (smartmovt 方案) 逆向提取
enum BLEConstants {
    // 主服务
    static let mainServiceUUID = CBUUID(string: "0000a800-0000-1000-8000-00805f9b34fb")

    // 特征值
    static let writeCodeCharacteristicUUID = CBUUID(string: "0000a801-0000-1000-8000-00805f9b34fb")  // 写命令
    static let writeDataCharacteristicUUID = CBUUID(string: "0000a802-0000-1000-8000-00805f9b34fb")  // 写数据
    static let notifyCharacteristicUUID    = CBUUID(string: "0000a803-0000-1000-8000-00805f9b34fb")  // 通知(接收)

    // OTA 相关 (本项目不使用)
    static let otaCharacteristicUUID  = CBUUID(string: "0000a804-0000-1000-8000-00805f9b34fb")
    static let bleOtaCharacteristicUUID = CBUUID(string: "0000a805-0000-1000-8000-00805f9b34fb")

    // 标准服务
    static let batteryServiceUUID = CBUUID(string: "0000180f-0000-1000-8000-00805f9b34fb")
    static let batteryLevelCharacteristicUUID = CBUUID(string: "00002a19-0000-1000-8000-00805f9b34fb")

    static let deviceInfoServiceUUID = CBUUID(string: "0000180a-0000-1000-8000-00805f9b34fb")
    static let firmwareVersionCharacteristicUUID = CBUUID(string: "00002a26-0000-1000-8000-00805f9b34fb")
    static let manufacturerCharacteristicUUID = CBUUID(string: "00002a29-0000-1000-8000-00805f9b34fb")

    // 标准描述符
    static let clientCharacteristicConfigUUID = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
}

/// 协议命令字 (byte[3])
/// 注意: 同一 cmd 可能有不同 sub 命令 (byte[5])，通过参数区分
enum BLECommand: UInt8 {
    case notify           = 0x02  // 通知推送
    case cameraOrFind     = 0x03  // 拍照模式(sub=0x02) / 查找手表(sub=0x04)
    case timeSync         = 0x04  // 时间同步
    case alarm            = 0x09  // 闹钟
    case sedentaryOrUV    = 0x0A  // 久坐提醒(sub=0x04) / UV(sub=0x02)
    case versionPower     = 0x0C  // 版本和电量查询
    case ota              = 0x07  // OTA
    case steps            = 0x46  // 当日步数 (70)
}

/// 通知类型 (byte[6])
enum BLENotifyType: UInt8 {
    case qq       = 0x01
    case otherApp = 0x02
    case call     = 0x04  // 来电/微博共用
    case sms      = 0x08
    case wechat   = 0x10
    case facebook = 0x20
    case twitter  = 0x40
    case whatsapp = 0x80
}

/// 接收数据的命令字 (手表 -> 手机)
/// 注意: 部分命令字复用，需结合数据长度和内容区分
enum BLEReceiveCommand: UInt8 {
    case authSuccess      = 19    // 0x13 授权成功
    case timeSyncOrAuth   = 20    // 0x14 时间同步成功 / 授权失败
    case sedentaryResult  = 21    // 0x15 久坐提醒返回
    case findPhone        = 0x01  // 查找手机 (sub type)
    case takePhoto        = 0x02  // 遥控拍照 (sub type)
    case endCall          = 0x03  // 挂断电话 (sub type)
}
