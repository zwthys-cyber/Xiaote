# 无感钥匙体验复核（2026-09-08）

## 结论

让车辆验证门把手挑战并决定解锁、让车辆原生逻辑负责离车落锁，是当前项目应继续采用的方案。但现有实现不能称为“最佳”或承诺锁屏、后台始终成功。本次发现并修复了本地密钥保护级别与后台读取矛盾、读取超时终止共享消息流、初始化吞掉第一条认证挑战、监听停止后仍显示在线的问题。

## 离车落锁

- `VehicleController` 的断连处理没有调用 `lock()`；“离车”场景是手动场景，不是断连自动化。
- 发现车辆时的 RSSI 距离没有参与落锁或解锁。不要把人体遮挡、无线干扰或瞬时断连当成用户已经离车。
- 用户需要在车机「控制 → 车锁」开启离车后自动上锁。排除家、其他钥匙留在车内、门或行李厢未关等情况会影响落锁；车型/固件以对应车主手册为准。
- 拉远信号或 App 断开不能作为已锁车证据。界面的门锁状态仍应以车辆回读和更新时间为依据。

依据：[Tesla Model 3 车主手册 — Walk-Away Door Lock](https://www.tesla.com/ownersmanual/model3/en_us/GUID-7A32EC01-A17E-42CC-A15B-2E0A39FD07AB.html)。

## 拉门把手认证

已检查项目锁定的 TeslaBLEKeyKit `d5da62c003ac6e2e0d8695f910957dd5708c82d7` 和 App 的 `LegacyVCSECClient`、`PassiveKeyLifecycle`、`VehicleController`。

- 主动控制与被动钥匙各有独立连接，避免两个消费者抢同一个门把手挑战。
- 进入后台释放主动控制连接，保留可恢复的钥匙连接；后台不依赖每隔几秒运行一次的 App 定时器。
- 认证响应绑定车辆发来的 token，校验 token 长度、目标密钥（若提供）和认证等级。发送响应不等于车辆已经接受或门已打开。
- 原实现 `WhenUnlockedThisDeviceOnly` 会阻止锁屏后的密钥重新读取。本次改为 `AfterFirstUnlockThisDeviceOnly`，旧密钥在成功读取后原地迁移，不删除、不重新配对，也不通过 iCloud 同步。重启后仍必须先解锁一次手机；升级后需在解锁状态打开 App 完成迁移。
- 原实现通过取消 `AsyncStream.next()` 实现超时，会连带终止共享流。本次使用单消费者消息收件箱：超时只移除等待请求，后来的挑战仍可接收。
- 初始化读取的第一条回复可能本身就是认证挑战；现在会即时处理，避免需要第二次拉门。
- 监听自然结束或响应失败时，会撤销在线状态并恢复原连接对象上的会话，避免“页面在线、实际无人响应”。

依据：[Apple Core Bluetooth 后台与状态恢复说明](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)、[Apple 钥匙串首次解锁后的设备级保护](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly)。

## 验收范围

自动化覆盖密钥迁移保持原密钥、保护属性、缺失密钥不自动替换、请求超时后继续接收挑战、取消等待后继续接收、连续消息顺序。模拟器无法证明射频距离、后台唤醒延迟或真车落锁成功率。

发布后的真车检查应记录：

1. 前台、锁屏 5 分钟、锁屏 30 分钟后，首次拉门是否成功及等待时间。
2. 离开蓝牙范围再返回，是否无需打开 App 即可恢复；蓝牙关闭再开启后是否恢复。
3. 另一把钥匙留车内、车门未关、排除家开启时，落锁行为是否符合车机设置。
4. 重启手机首次解锁前后、用户强制退出 App 后的行为，不能承诺这些情况下始终无感。
5. 连续多轮记录首次拉门成功率、从拉门到解锁的时间和离车落锁时间；没有这些数据就不能声称优于 Tesla 官方手机钥匙。

旧协议 `estimatedDistance` 缺失在不同车辆上的确切语义，仍缺少真车证据。本次不猜测单位或填入虚构距离。
