# macOS NTFS 磁盘管理软件架构设计方案

> **开发进度状态**: 🚧 阶段 2: 特权后台进程模型 (Privileged Helper) 开发中...
> *(已完成: 阶段 1 - 架构设计与项目初始化)*

作为一个高级架构师，在构建 macOS 平台 NTFS 磁盘监测与挂载管理软件时，我们需要重点考虑 **macOS 底层权限限制**、**守护进程模型**以及**用户无感知的自动化体验**。

以下是该系统的详细架构设计。

## 1. 核心挑战与技术选型

### 1.1 背景与技术限制
从 macOS Ventura (13.0) 开始，苹果彻底移除了系统中内置的（原本隐藏的） `mount_ntfs` 读写支持核心代码。这意味着早些年通过修改 `/etc/fstab` 或使用原生命令挂载 NTFS 为读写模式（如 Mounty 早期的做法）已不再可行。

当前在 macOS 上实现 NTFS 读写的开源可靠方案是依赖 **FUSE-T** (或类似的新一代 KEXT-less FUSE 实现) 和 **NTFS-3G** 驱动。本架构将基于该方案进行设计，软件本身作为一个优雅的包装器（Wrapper）和自动化环境管理工具。如果您有商业化需求，也可考虑获得 Tuxera 或 Paragon 的闭源驱动授权，但架构层面的交互类似。

### 1.2 核心技术栈说明
- **前端应用 UI**: SwiftUI (针对 macOS 12+ 优化)，提供现代化界面。
- **磁盘事件监听**: `DiskArbitration` 框架 和 `IOKit`。
- **虚拟文件系统 (VFS)**: **FUSE-T**。与传统的 macFUSE 不同，FUSE-T 使用本地 NFSv4 服务器来挂载文件系统，**完全不需要内核扩展 (KEXT)**，因此在 Apple Silicon (M1/M2/M3) 等设备上**无需用户进入恢复模式降低安全启动级别**，极大提升了用户体验。
- **NTFS 驱动**: **NTFS-3G** (编译链接到 FUSE-T)。
- **特权操作机制**: `ServiceManagement` (`SMAppService`) 提供 Root 权限的后台 Helper，避免每次挂载都弹窗索要管理员密码。
- **进程间通信**: `NSXPCConnection`，保障应用与特权服务之间的安全数据交换。

---

## 2. 系统核心模块设计

该软件从逻辑上分为三大核心组件模块：**前端交互层**、**后台监控进程**、**特权服务层**。

### 2.1 架构图示 (Mermaid)
```mermaid
graph TD
    UI[App 前端界面 - 菜单栏/设置窗] <-->|用户配置/状态展示| XPC(XPC 安全通信通道)
    Agent[后台监控 Agent Daemon] <-->|DiskArbitration 监听磁盘插入/拔出| UI
    Agent <-->|读取/保存配置策略| DB[(本地配置存储 SQLite/UserDefaults)]
    Agent <-->|发送挂载/卸载指令| XPC
    XPC <-->|受信调用| Helper[Privileged Helper Tool 特权进程]
    Helper -->|执行 Root 权限命令| Shell((Shell / diskutil 操作))
    Shell -->|1. 强制卸载 macOS 原生只读挂载| System{macOS 系统层}
    Shell -->|2. 调用 ntfs-3g 执行读写挂载| FUSE[FUSE-T (NFSv4) 虚拟文件系统]
```

---

## 3. 各模块详细职责与实现细节

### 3.1 模块 A：前端交互应用 (Main App - Menu Bar & Settings)
**职责**: 这是用户唯一直接接触的程序组件。
- **Menu Bar 状态栏**: 常驻后台，图标动态反映当前是否有 NTFS 磁盘连接。下拉菜单列出所有检测到的磁盘及它们当前的挂载状态（只读 / 读写模式）。
- **设置面板 (Preferences)**:
  - 提供环境自检：检测系统是否安装了 `FUSE-T` 以及 `ntfs-3g`，如果缺失则引导用户进行安装（可考虑内嵌安装包一键静默安装，因为 FUSE-T 不需要内核扩展，完全可以在用户态静默部署）。
  - 全局设置：默认新磁盘接入时是执行“只读”还是“强制读写”。
  - 磁盘清单管理：针对特定硬盘（通过 Volume UUID 或 Serial Number）记住用户的独立挂载策略。

### 3.2 模块 B：磁盘监控守护进程 (Disk Monitor Agent)
**职责**: 无 UI 后台服务，负责设备生命周期管理。
- **监听挂载事件**: 使用 `DiskArbitration` 注册回调函数（`DADiskAppearedCallback`, `DADiskMountApprovalCallback`）。
- **拦截与识别**: 
  - 当有新磁盘事件时，通过 `DADiskGetDescription` 获取文件系统格式（`Windows_NTFS`）和 Volume UUID。
  - macOS 默认会抢占式地将 NTFS 挂载为"只读"。在大多数 macOS 版本中，阻止系统默认挂载常常会引起不可控的竞争条件，因此**最佳实践架构**为：允许系统挂载完成 -> Agent 捕获到挂载路径 -> 触发配置策略判定 -> 指示 Helper Tool 卸载并在原路径重新以 Read-Write 挂载。
- **策略判定逻辑**: 读取本地配置库，如果该 UUID 用户设定为“只读”则不干预；如果设定为“读写”，则通过 XPC 唤醒 Helper。

### 3.3 模块 C：特权辅助进程 (Privileged Helper Tool)
**职责**: 隔离具有 Root 权限的破坏性系统调用。
- **机制**: 在用户首次运行软件时，通过 `SMAppService.daemon(named:)` 注册系统级后台进程（macOS 13+ 新 API，兼容旧版需使用 `SMJobBless`）。这会弹出一次系统的安全认证授权。
- **安全性**: 该 Helper 必须进行严格的证书签名和 Team ID 校验。通过 XPC 暴露的暴露接口必须极度克制，防止被恶意软件利用进行系统破坏。
- **执行命令序列**:
  ```swift
  // XPC 接收到的伪代码逻辑：Remount_RW_Disk(UUID)
  1. diskutil unmount /dev/diskXsY         // 卸载系统的只读挂载
  2. mkdir -p /Volumes/<Disk Name>         // 确保挂载点存在
  3. /usr/local/bin/ntfs-3g /dev/diskXsY /Volumes/<Disk Name> -o local,allow_other,volname=<Disk Name>
  ```

---

## 4. 存储与数据流设计

使用 `UserDefaults` (`SuiteName` 指定为 App Group 使得 UI 和 Agent 可以共享) 保存磁盘偏好。由于数据量小，JSON 或者 PropertyList 是最佳选择。

**数据结构示例**:
```json
{
  "Disks": {
    "UUID-XXXX-XXXX": {
      "Name": "My Work Drive",
      "Mode": "ReadWrite",    // 枚举: ReadWrite, ReadOnly, Ignore
      "AutoMount": true,
      "LastConnected": "2026-02-21T10:00:00Z"
    }
  },
  "GlobalSettings": {
    "DefaultMode": "ReadOnly",
    "LaunchAtLogin": true
  }
}
```

---

## 5. 潜在技术风险与用户体验 (UX) 考量

1. **取代内核扩展 (KEXT)**：
   - 传统方案（如 macFUSE）因为需要内核扩展，要求 Apple Silicon 设备进入恢复模式。本架构彻底放弃 KEXT，转向 **FUSE-T** (基于用户态的 NFS 桥接)，成功规避了这一最大的 UX 灾难，实现与原生 App 几乎一致的无缝安装和使用体验。
2. **开源分发策略 (Open Source Distribution)**：
   - 带有特权服务 (`SMAppService`) 和底层磁盘控制 (`DiskArbitration`) 的应用完全无法满足 Mac App Store 的严格沙盒化要求。鉴于本软件定位于**开源项目**，直接通过 GitHub Releases 或 Homebrew 等渠道分发即可，用户下载后可直接运行（建议仍需进行 Apple Developer ID 签名和 Notarization 苹果公证，以避免 gatekeeper 拦截报错，这不影响开源性质）。
3. **性能评估 (NFSv4 vs 原生内核驱动)**：
   - 虽然 FUSE-T 解决了安装痛点，但基于 NFSv4 over localhost 的中转，其大文件连续 I/O 和海量小文件的吞吐量不可避免会低于内核级商业驱动（如 Paragon NTFS）。在进行文件拷贝时，软件可以通过合理的缓存机制和 UI 明确的进度展示来缓解感官上的等待焦虑。

---

## 6. 驱动选型对比分析 (自研 vs 现有驱动)

作为架构师，在决定底层核心的读写驱动时，我们需要进行严谨的权衡：

### 方案 A：纯自研 NTFS 读写驱动 (如基于 AppleFSKit 或直接解析 MFT)
| 维度 | 评价与详解 |
|------|-----------|
| **架构风险** | **极高**。NTFS (New Technology File System) 是微软闭源的私有系统，具有极其复杂的设计（MFT 主文件表记录、B+ 树目录结构、日志重放机制、大量的无文件流/ADS）。稍微一点解析逻辑的 Bug，或者在写入时中断，**都会直接导致用户的整个磁盘结构损坏（Corrupted**），造成严重的数据灾难。 |
| **开发成本** | **极高**。从零实现一个生产级别的可用文件系统，通常需要专业的文件系统内核团队耗费数年时间进行开发和天量的边界模糊测试。开源项目几乎不可能承担这种时间与精力成本。 |
| **性能上限** | **极高**。理论上，纯手写原生代码去操作 I/O 可以实现媲美原生 APFS 的性能。 |

### 方案 B：使用成熟开源组合 (FUSE-T + NTFS-3G)
| 维度 | 评价与详解 |
|------|-----------|
| **架构优势** | **快速落地，经过检验。** `NTFS-3G` 是久经考验的开源项目，已经被无数 Linux 发行版作为默认的 NTFS 挂载器使用十余年。它已经处理了 99.9% 的 NTFS 恶劣边界情况，能够非常稳定地工作。通过 `FUSE-T` 桥接，我们的应用只需专注于极致的 UI 和交互体验，底层脏活累活都交给久经考验的二进制。 |
| **安全性** | **高**。FUSE 架构天然就是在“用户态（User Space）”而不是“内核态”运行的。这意味着就算 `ntfs-3g` 服务发生崩溃，也只会导致当前挂载断开，绝大部分情况下不会导致 macOS 系统陷入 Kernel Panic (内核崩溃/死机重启)。并且，ntfs-3g 在写入机制上趋于保守，尽量保证文件结构的安全。 |
| **性能短板** | **中低**。作为用户空间的文件系统，每次 I/O 请求都要经历 `App -> Kernel -> NFS Server (FUSE-T) -> ntfs-3g 用户空间 -> 磁盘` 的冗长路径。在小碎文件（例如数万个几 KB 的照片）拷贝时，速度会明显慢于系统原生支持。但这对于绝大多数 U 盘/移动硬盘日常拷贝电影、办公文档的场景来说是完全可以接受的体验妥协。 |


---
## 最终评审确认

根据您的反馈，本开源项目将采用 **FUSE-T + NTFS-3G** 作为底层驱动解决方案，重点打磨 SwiftUI 前端与守护进程带来的“插上即用”的顺滑无感体验。

如果您认同目前梳理的项目边界、选型架构与安全评估，我们可以开始执行第一个技术 Milestone：**构建基于 SMAppService 的特权后台进程模型**。
