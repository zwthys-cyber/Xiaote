# TeslaBLEKeyKit 本地版本

源代码与 LICENSE 来自 `misakatao/TeslaBLEKeyKit` 的提交 `d5da62c003ac6e2e0d8695f910957dd5708c82d7`（原项目锁定的同一份源码）。原 `zwthys-cyber/TeslaBLEKeyKit` 地址已不可访问，因此纳入仓库，使 App 和协议测试可以从同一份版本构建。

小特的本地改动位于 `Sources/TeslaBLEKeyKitBLE/BLEConnection.swift`：

- iOS 恢复用的连接在断开或连接失败时立即向 CoreBluetooth 重新提交连接请求；`close()` 后停止提交。
- 物理连接断开、接收帧错误时清理分帧和消息流，避免下一次会话使用已终止的数据流。
- 在 BLE 链接仍然可用但 VCSEC 会话失败时，可以单独重建消息流，再做一次有界恢复尝试。
- 暴露接收事件，便于 App 在钥匙会话未就绪时利用车辆新消息触发恢复。

此处保留上游 MIT 许可。升级库时必须重新审查恢复标识、待连接请求与消息流状态，并在真车上验证后台离车返回。
