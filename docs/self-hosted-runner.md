# Xiaote 构建机

默认工作流现使用 GitHub 托管的 `macos-26`（Apple Silicon）和 Xcode 26.2，不依赖个人电脑在线。云端执行后端、协议、App 和模拟器 UI 测试，并保留 UI 截图与测试结果；通过后生成 IPA。

手动运行 **Build and verify Xiaote** 时勾选 `build_on_mac`，即可将 iOS 构建和模拟器测试交给带有 `xiaote-mac` 标签的本地 Mac。后端和协议测试继续使用云端。Mac 使用 `xcode-select -p` 选中的 Xcode；默认云端配置保持 Xcode 26.2。

## 恢复已有 Mac 的连接

在安装 runner 的目录执行 `./run.sh`，保持终端窗口打开。看到 `Listening for Jobs` 表示可以接单。如果忘记目录，在 Mac 终端查找：

```sh
find "$HOME" -maxdepth 5 -type f -name run.sh 2>/dev/null
```

进入同时包含 `config.sh`、`.runner` 和 `run.sh` 的 runner 目录后再启动；不要假定它一定安装在 `~/actions-runner`。如果没有找到，按下方步骤重新安装。GitHub 中的离线注册记录不代表当前电脑仍保留安装文件。

# Xiaote Mac GitHub Actions runner

An optional self-hosted Apple Silicon Mac should carry the custom
`xiaote-mac` label. Only workflows targeting that label require it to be online.

## One-time setup

1. In GitHub, open **Settings → Actions → Runners → New self-hosted runner**.
2. Select **macOS** and **ARM64**, then run GitHub's displayed download and
   configuration commands on the Mac.
3. When prompted for additional labels, enter `xiaote-mac`.
4. Install the runner as a background service using the `svc.sh` command shown
   by GitHub.
5. Select Xcode and complete its one-time setup:

   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

The workflow downloads its pinned XcodeGen version and configures Go itself.
The runner account must be able to use Xcode's iOS Simulator and write to its
own DerivedData directory. Keep repository secrets out of the runner folder.
For security, workflows reject pull requests originating from forks; untrusted
code must never execute on the self-hosted Mac.

## Verification

Open **Settings → Actions → Runners** and confirm the runner is **Idle** and
shows all four labels: `self-hosted`, `macOS`, `ARM64`, and `xiaote-mac`.
Then manually start **Build and verify Xiaote** with `build_on_mac` enabled.
