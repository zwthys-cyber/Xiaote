# Xiaote 构建机

默认工作流现使用 GitHub 托管的 `macos-26`（Apple Silicon）和 Xcode 26.2，不依赖个人电脑在线。云端执行后端、协议、App 和模拟器 UI 测试，并保留 UI 截图与测试结果；通过后生成 IPA。

下面的本地 Mac runner 设置仅用于需要自行托管的环境。启用时需显式修改工作流的 `runs-on`，并按本机 Xcode 安装位置调整 `DEVELOPER_DIR`。

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
Then manually start the **Build and verify on Xiaote Mac** workflow.
