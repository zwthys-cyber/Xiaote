# 后台手机钥匙恢复：原因与验收

用户复现：把 App 留在后台，离车约 30 分钟，回来拉门无法解锁；划掉并重新打开 App 后可用。

## 发现的恢复空档

1. App 进入后台后取消自身的周期重连任务，以避免长时间运行和 iOS 后台限制；这一步本身正确。
2. 原蓝牙库在一次 `didFailToConnect` 后仅结束等待，没有重新向 CoreBluetooth 提交连接请求。原 App 在后台也不再定时提交请求，因此这次失败后可能一直没有新的系统唤醒事件。`didDisconnect` 同样把下一次请求推迟到 App 异步恢复流程中。
3. 连接上的分帧异常会结束消息流，但原库未将该流清空。后续恢复可能再次拿到已结束的流；没有新的断连/ready 事件时，会话无法自行恢复。
4. 被动钥匙会话此前固定等待最多三秒可选回复，耗费 iOS 给予蓝牙后台唤醒的短暂处理时间。门把手挑战如果早于会话资料到达，也可能被忽略。

## 改动

- 可恢复蓝牙链接保持显式连接意图。断开或连接失败的 CoreBluetooth 回调内立即重新提交 `connect` 请求；用户主动关闭链接时撤销意图。等待超时只结束调用方的等待，不撤销系统托管请求。
- 物理断连或帧解析失败时重置分帧与消息流。App 在钥匙未就绪时收到车辆新消息，也会再次建立会话。
- 如果物理链接已恢复、但后台 VCSEC 会话初始化失败，先丢弃旧消息流并立即再试一次；最多一次，避免后台无限循环。
- 门把手挑战监听器异常时只重建接收流，保留仍然健康的 BLE 物理连接，避免主动断开后又立即连接的竞争。
- 被动钥匙在发送会话认证后直接安装唯一的挑战监听器，不固定等待可选回复；过早到达的挑战暂存并在获得会话密钥后响应。
- 蓝牙库源码与许可纳入仓库，App 和协议测试共同引用本地同一份版本，避免已失效仓库地址造成未来构建失败。

## 真车验收

模拟器和单元测试可证明状态流转与 App 编译，不能模拟车辆射频、iOS 后台调度或验证车辆实际接受门把手认证。安装新版本后，保持 App 在后台且不强制退出，分别离开车辆 5 分钟、30 分钟、2 小时，回来后第一次拉门，连续记录至少三轮：是否一次成功、从触碰到解锁的时间、是否必须打开 App。若失败，在 App 的本地诊断中查看 `ble.passive.disconnected`、`ble.passive.restore.*`、`ble.passive.proximity.*` 与 `ble.passive.challenge.*` 的顺序，区分系统没有交付连接事件、会话恢复失败和车辆拒绝认证。

iOS 可以在用户未强制退出时暂停或回收 App；CoreBluetooth 状态恢复与待连接请求会提高恢复机会，但无法承诺任意时间、任意无线环境都必定成功。Apple 对后台蓝牙和状态恢复的说明：[Core Bluetooth Background Processing for iOS Apps](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)。
