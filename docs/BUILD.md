# 构建、安装与发布

本文对应 v3.3.2（332）及当前主线。构建配置以 `project.yml` 和 `.github/workflows/build.yml` 为准。

## 环境

- 最低系统：iOS 17.0；Watch 配套应用为 watchOS 10.0。最低要求不是产品名称或已验证系统清单。
- 当前 CI：GitHub 托管 `macos-26` Runner，Xcode 26.2（`/Applications/Xcode_26.2.app/Contents/Developer`）。
- XcodeGen 固定为 2.46.0；Swift Package 依赖由 `project.yml` 固定 revision，TeslaBLEKeyKit 使用仓库内源码。
- 当前工作流不要求自托管 Mac。自行配置说明见 [可选自托管 Runner](self-hosted-runner.md)。

## 本机开发

安装 Xcode 26.2、iOS/watchOS SDK 和 XcodeGen，然后运行：

```sh
xcodegen generate
open Xiaote.xcodeproj
```

默认主 App Bundle ID 为 `com.local.teslablekey`。修改它时，应同步 Watch companion 标识和 OAuth 回调配置。真车 BLE、刷卡授权和锁屏后台表现不能用模拟器证明。

## CI 与下载产物

工作流 **Build and verify Xiaote** 响应 `main` push、`v*` tag、Pull Request 和手动触发。三个 Job 均使用 GitHub 托管 Mac：

1. **Fleet API backend tests**：`go test ./...` 和 `go vet ./...`。
2. **Tesla protocol tests**：在 `Vendor/TeslaBLEKeyKit` 运行 `swift test`。
3. **Build unsigned IPA**：非 PR 事件下生成工程、解析依赖、准备模拟器并执行 App/UI 回归测试，再编译无签名 iPhone Release、嵌入 Watch 应用并打包。

| Artifact | 内容 | 保留时间 |
| --- | --- | --- |
| `Xiaote-IPA` | `Xiaote-unsigned.ipa` 与 `.sha256` | 30 天 |
| `Xiaote-UI-Screenshots` | UI 测试截图 | 14 天 |
| `Xiaote-Simulator-Results` | 测试结果包和截图 | 7 天 |

旧构建页面的 IPA 产物名称可能仍带旧的系统或安装工具后缀，不代表只能在某一系统安装。正式包优先从 [Releases](https://github.com/zwthys-cyber/Xiaote/releases/latest) 下载；Actions 产物过期后需重新构建。截图和模拟器结果不是安装包。

```sh
shasum -a 256 -c Xiaote-unsigned.ipa.sha256
```

## 安装

Release 中的 IPA 未签名。普通安装需要有效证书与匹配描述文件，可使用全能签等工具签名；安装、后台权限和 Watch 部署仍取决于签名配置及设备系统。TrollStore 只适用于其自身支持的设备系统，不是所有系统通用的安装方式。

首次使用允许蓝牙权限，并携带已授权的实体钥匙卡在车内完成配对。先验证扫描、配对、手动锁车/解锁，再测试锁屏及离开后返回的无感钥匙表现。iPhone 17 Pro Max / iOS 27.0.1 尚不能仅凭 CI 成功宣称已经实测兼容。

## 发布流程

1. 同步主 App 和 Watch 的 `MARKETING_VERSION`、`CURRENT_PROJECT_VERSION`，更新 `CHANGELOG.md`。
2. 构建并通过后端、协议与 App/UI 检查，检查包内版本、Watch 嵌入结构和 SHA-256。
3. 常规方式是推送与 App 版本一致的 `v*` tag，工作流会上传 IPA 到同名 Release。也可将已验证同一源码内容的构建产物手动附到对应版本 Release，并填写更新说明。
4. 真车验证配对、重连、门锁、媒体和后台恢复；未进行的设备测试应注明，不把构建成功写成兼容性承诺。

## 常见问题

- Runner 排队：查看 GitHub 的容量提示；当前无需启动个人 Mac。
- 付款或额度拦截：检查 GitHub Actions 的 Billing 与组织策略，公开仓库仍可能受特定 Runner 或账号限制影响。
- 工具链不匹配：核对 Runner 镜像、`DEVELOPER_DIR` 和 Xcode 实际版本。
- 模拟器不可用：检查 `scripts/prepare-ios-simulators.py` 结果；当前工作流要求模拟器验证，不会静默跳过后发布。
- Release 上传失败：检查 tag、Job 的 `contents: write` 与仓库策略。
