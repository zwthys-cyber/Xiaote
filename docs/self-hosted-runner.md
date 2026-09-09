# Xiaote Mac GitHub Actions 编译机

当前工作流的 App Job 只匹配带 `xiaote-mac` 标签的 Apple Silicon 自托管
Runner。`main` push 和手动运行会生成 Actions Artifact；推送 `v*` tag 还会把
IPA 与 SHA-256 校验文件上传到同名 GitHub Release。

## 1. Mac 一次性准备

建议创建一个只用于编译的标准 macOS 用户，不要在该账户保存个人 SSH 私钥、
浏览器登录、Apple ID 或签名证书。Runner 会执行仓库代码，不应使用日常管理员账户。

安装 Xcode 后执行：

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
xcodebuild -downloadPlatform watchOS
xcodebuild -version
```

在 **系统设置 → 节能** 中启用“显示器关闭时防止自动进入睡眠”；Mac 必须开机、
联网且编译用户已登录。建议预留至少 50 GB 空间。

## 2. 注册 Runner

打开仓库：

**Settings → Actions → Runners → New self-hosted runner → macOS → ARM64**

在编译用户的终端中逐行执行 GitHub 页面当时显示的下载、校验和解压命令。注册时：

- Runner 名称可填 `xiaote-mac`；
- Additional labels 填 `xiaote-mac`；
- Work folder 接受默认 `_work`；
- 不要把页面中的短期注册 Token 写入仓库或截图。

注册成功后，在 Runner 目录执行：

```sh
./svc.sh install
./svc.sh start
./svc.sh status
```

回到 GitHub 页面，确认状态为 **Idle**，标签包含 `self-hosted`、`macOS`、
`ARM64`、`xiaote-mac`。macOS 的服务由当前登录用户的 `launchd` 管理；升级
Xcode 或重启后可用 `./svc.sh status` 检查。

## 3. 触发、下载和发布

- 开发包：进入 **Actions → Build and verify Xiaote → Run workflow**。完成后从
  本次运行的 Artifacts 下载 `Xiaote-iOS17-TrollStore`，解压得到
  `Xiaote-unsigned.ipa`。
- 正式包：先让 `project.yml` 中 `MARKETING_VERSION` 与 tag 一致，再执行
  `git tag v3.2.1 && git push origin v3.2.1`。工作流会创建/更新 `v3.2.1`
  Release，手机可直接下载 IPA 后用 TrollStore 打开。
- 下载后可在 Mac 校验：

  ```sh
  shasum -a 256 -c Xiaote-unsigned.ipa.sha256
  ```

## 4. 依赖与编译缓存

工作流把固定版本 XcodeGen、Swift Package 源码和 DerivedData 保存在
`RUNNER_TOOL_CACHE/xiaote`，仓库 checkout 不会删除它们。构建命令不执行
`clean`，因此同一台 Mac 的后续构建会复用已解析依赖和增量编译结果。

依赖仍由 `project.yml` 的精确 Git revision 锁定；缓存只加速，不改变依赖版本。
升级 Xcode 或缓存异常时，停止 Runner 后只需删除
`RUNNER_TOOL_CACHE/xiaote/DerivedData`；不必删除 `SourcePackages`。该路径的实际
值会显示在每次 Actions Job 的 Runner 环境信息中。

## 5. 安全边界

这个仓库是公开仓库。自托管 Job 明确不响应 `pull_request`，只响应仓库维护者
push、tag 与手动触发；不要改成在自托管 Mac 上执行外部 PR。发布仅使用 Job
临时生成、限于本仓库的 `GITHUB_TOKEN`，不需要 PAT、Apple 证书或密码。

如果 GitHub 设置允许，请把 Runner 放入仅允许 `zwthys-cyber/Xiaote` 使用的
Runner Group。真机 Tesla/BLE/NFC 操作仍必须人工验证，CI 无法替代。

## 6. 常见故障

- 一直 `Waiting for a runner`：检查服务、四个标签及 Mac 是否睡眠。
- 找不到 iOS/watchOS SDK：重新执行对应 `xcodebuild -downloadPlatform`。
- 模拟器无法启动：保持编译用户图形登录，执行 `xcrun simctl list` 检查运行时。
- 磁盘不足：先删除旧 Actions 工作目录和 DerivedData；保留 `SourcePackages`。
- Release 上传 403：仓库 **Settings → Actions → General → Workflow permissions**
  需允许工作流获得写权限；工作流本身已把发布 Job 限为 `contents: write`。
