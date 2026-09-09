# 构建与发布

## 环境

- iOS deployment target：17.0
- watchOS deployment target：10.0
- GitHub Runner：带有 `xiaote-mac` 标签的自托管 Apple Silicon Mac
- Xcode：本机 `/Applications/Xcode.app`（当前验证版本见构建日志）
- Swift Package Manager：解析 `project.yml` 中固定 revision
- 工程生成器：XcodeGen

## 本机构建

```bash
brew install xcodegen
xcodegen generate
open Xiaote.xcodeproj
```

默认 Bundle ID 为 `com.local.teslablekey`。真车 BLE 与 NFC 钥匙卡授权无法在模拟器验证。

## GitHub Actions

`.github/workflows/build.yml` 在 `main` push、`v*` tag、Pull Request 和手动触发时运行。后端与协议测试使用 GitHub 托管 Mac；App 编译仅在非 PR 事件使用带 `xiaote-mac` 标签的自托管 Apple Silicon Mac：

1. `Fleet API backend tests` 执行 `go test ./...` 与 `go vet ./...`。
2. `Tesla protocol tests` 检出 `zwthys-cyber/TeslaBLEKeyKit` 的固定提交并执行 `swift test`。
3. `Build unsigned TrollStore IPA` 生成 Xcode 工程、解析固定依赖、以禁用代码签名的 Release 配置编译真实 iPhone 目标，并打包 `Payload/Xiaote.app`。

主 App 嵌入 watchOS 配套应用。无 Apple Watch 时不影响 iPhone 功能；TrollStore 对嵌入式 Watch App 的安装取决于系统和配对状态，CI 只验证编译与嵌入结构。

Artifact 名称为 `Xiaote-iOS17-TrollStore`，包含 `Xiaote-unsigned.ipa` 和 SHA-256 文件并保留 30 天。推送 `v*` tag 时，这两个文件也会上传到同名 GitHub Release。自托管 Mac 在 Runner tool cache 中持续保留固定 XcodeGen、Swift Package 源码和 DerivedData，并通过禁用 `clean` 复用增量编译缓存。

## 发布检查

- `project.yml` 的 `MARKETING_VERSION` 与 Release tag 一致。
- README、架构文档与依赖 revision 一致。
- 协议测试和无签名 iPhone Release 构建全部通过。
- 下载 Actions artifact 并记录 SHA-256。
- TrollStore 真机安装后验证配对、重连、门锁、媒体同步和后台恢复；CI 不能替代真车测试。
