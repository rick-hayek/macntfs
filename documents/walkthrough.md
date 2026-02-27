# MacNTFS 开发全流程验收报告

本项目旨在使用最新的 macOS 框架结合 Swift，基于 FUSE-T + NTFS-3G，开发一款无需进入恢复模式的 NTFS 挂载辅助工具。

## ✅ 已完成的开发架构
1. **统一 SwiftUI 前端**：采用 `MacNTFSApp` 统一纳管，包含可以在菜单栏常驻的 `MenuBarExtra`（用于展示快速选项），以及管理各个磁盘策略的 `SettingsView` 设置面板。
2. **AppGroup 数据共享**：配置了 `group.com.macntfs` 的 UserDefaults 以作为微型数据库，实现 UI 与 DiskMonitorAgent 以及特权进程在同一数据域内沟通磁盘是否该被设定为读写模式。
3. **特权辅助后台方案 (SMAppService)**：构建了 `MacNTFSHelper` 独立可执行文件，通过预置 `Info.plist` 与 `.entitlements` 完成 XPC 本地双向信任签名，实现了无弹窗环境下的静默执行 `diskutil unmount force` 及 FUSE-T 命令。
4. **原生磁盘监听**：`DiskMonitorDaemon` 集成了 macOS 底层的 `DiskArbitration (DASession)`，实时并主动过滤拦截 `Windows_NTFS` 格式宗卷的连接事件。

## 🚀 编译与测试指令

项目工程为标准 Swift SPM 包。

为了正确的运行模拟跨越系统权限沙盒的 XPC 提权调用，请必须使用工程目录下我配备的专用编译证书签发脚本：

```bash
cd /Users/rick/src/macntfs
./test_xpc.sh
```

**一步到位测试启动**：
现在，启动应用无需命令行 sudo。您直接运行构建好的主 App：
```bash
.build/debug/MacNTFS.app/Contents/MacOS/MacNTFS
```

## 📸 运行效果截图示意
1. 运行主 App 后，您可以在 Mac 右上角菜单栏看到一个带感叹号的硬盘小图标。
2. 点击 *Preferences...* (或快捷键 `Cmd + ,`)打开偏好设置管理界面。您会在其中看到 **Helper Daemon Status** (后台守护进城状态面板)。
3. 如果显示为“未安装”，点击 **"Install Helper"** 按钮。系统会弹出一个原生窗口请求管理员密码，或使用 Touch ID。一旦授权，特权服务将作为 LaunchDaemon 静默加载，此后不再弹窗。
4. 当你在此状态下插入真正的 NTFS U 盘时，终端会输出命中回调并向 XPC 高权限请求的交互日志（前提是系统已经安装了 FUSE-T 和 ntfs-3g 环境）。
