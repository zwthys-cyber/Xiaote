# 项目文档

当前正式版为 **v3.3.2（332）**。产品名称为“小特蓝牙钥匙”；最低系统要求放在构建与安装说明中，不作为名称后缀。

## 当前使用与开发

- [项目首页](../README.md)：功能、安装入口、配对与使用限制。
- [架构与协议](ARCHITECTURE.md)：本地 BLE、可选 Fleet API、被动钥匙与 Watch 中继。
- [构建、安装与发布](BUILD.md)：工具链、CI、产物、签名安装与版本发布。
- [隐私说明](PRIVACY.md)：本地密钥、云端授权、联网请求及系统权限。
- [后端说明](../backend/README.md)：OAuth、远程 API、配置与验证。
- [版本记录](../CHANGELOG.md)：已发布版本的用户可见变化。
- [可选自托管 Runner](self-hosted-runner.md)：自行改用 Mac 编译机时的参考，当前默认使用 GitHub 托管 Runner。

## 专题与历史评审

以下记录保留原版本背景，不视为最新发布说明。当前行为以代码及上面的架构、隐私和构建文档为准。

- [后台 Phone Key 技术评审](PASSIVE_PHONE_KEY_BACKGROUND.md)：v2.3.2 时的评审基线。
- [Gemini 评审复核](GEMINI_PASSIVE_KEY_REVIEW_RESPONSE.md)：针对上述基线的历史讨论。
- [RSSI 距离稳定性](RSSI_DISTANCE_STABILITY.md)：v2.3.2 时的算法说明和验收思路。
- [无感钥匙体验复核](PHONE_KEY_REVIEW_2026-09.md)：2026-09 的问题、修复及真车验收条件。
- [可靠性与体验升级](RELIABILITY_UPGRADE.md)：v3.2.0 的状态回读、串行执行和 Watch 回执变化。

## 素材来源

- [Highland 线稿来源](HIGHLAND_ARTWORK_CREDITS.md)。
- [设计参考来源](../design-previews/highland-source/SOURCE-CREDITS.md)。
- [Beautiful UI 许可](../Xiaote/Resources/BeautifulUI-LICENSE.txt)。

第三方源码和素材的原始说明、署名与许可证应保留；它们不代表本项目当前安装要求或功能承诺。
