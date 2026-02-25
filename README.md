# MacNTFS

> A native, fast, and KEXT-less NTFS mounting utility for macOS (Supports Apple Silicon & Ventura/Sonoma+).

MacNTFS is an open-source menubar application designed to bring seamless read and write functionality to Windows NTFS external drives on modern macOS systems. Starting from macOS 13 (Ventura), Apple completely removed the hidden native kernel support for mounting NTFS drives in read-write mode. This project solves that problem elegantly by combining the power of **FUSE-T** (User-Space NFSv4 bridge) and **ntfs-3g**, managed by a native Swift/SwiftUI frontend.

## 🌟 Key Features

* **No Kernel Extensions (KEXT-less):** Built on FUSE-T. You do **not** need to reboot your Mac into Recovery Mode to lower security settings (a requirement for traditional macFUSE on Apple Silicon M1/M2/M3).
* **Automated Mounting:** Connect your NTFS drive, and MacNTFS will automatically intercept the system's read-only mount and remount it with full read/write permissions in the background.
* **Per-Disk Configuration:** Remember your preferences! Use the sleek SwiftUI preferences window to configure specific NTFS volumes to always mount as Read/Write, strictly Read-Only, or Ignore them completely.
* **Secure Privileged Helper:** Utilizes modern macOS `SMAppService` to install a dedicated XPC helper tool. This means you only ever enter your administrator password or Touch ID **once** during installation, never again when plugging in drives.

## ⚙️ Architecture

The app is built using modern Swift concurrency and consists of three core components communicating securely:

1. **Frontend App (`MacNTFSApp`)**: The status-bar menu extra and the SwiftUI Settings Window.
2. **Disk Monitor Daemon (`DiskMonitorDaemon`)**: A background listener utilizing `DiskArbitration` to detect `Windows_NTFS` volume mount events natively.
3. **Privileged Helper Tool (`MacNTFSHelper`)**: A lightweight root daemon installed securely via `ServiceManagement`. It receives validated XPC requests from the frontend to execute safe `diskutil unmount force` and `ntfs-3g` mounting commands.

> For a deep dive into the technical design, see the [Architecture Implementation Plan](documents/implementation_plan.md) and the [Walkthrough Report](documents/walkthrough.md).

## 🛠 Prerequisites & Dependencies

Before running or building the app, your Mac must have the underlying binary tools installed:

1. **Homebrew** (Optional but recommended for installing dependencies)
2. **FUSE-T**: The modern macOS FUSE replacement.
   ```bash
   brew tap macos-fuse-t/homebrew-cask
   brew install fuse-t
   ```
3. **NTFS-3G**: The open-source user-space NTFS driver.
   ```bash
   brew install ntfs-3g-mac
   ```

*Note: In the future, MacNTFS aims to bundle or auto-install these binaries for a pure 1-click end-user experience.*

## 🚀 Building & Running Locally

Because MacNTFS utilizes XPC and `SMAppService` to communicate with a root-level daemon, the binaries must be properly signed and structured into a specific `.app` bundle hierarchy, even for local debugging.

We have provided a convenient Bash script `test_xpc.sh` that compiles the Swift code and packages it correctly:

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/macntfs.git
   cd macntfs
   ```
2. Build and sign the binaries:
   ```bash
   ./test_xpc.sh
   ```
3. Launch the App:
   ```bash
   .build/debug/MacNTFS.app/Contents/MacOS/MacNTFS
   ```
4. Look for the external drive icon in your Mac's top-right menu bar.
5. Click **Preferences**, then click **Install Helper** to register the background service with macOS.

## 🤝 Contributing
Contributions are absolutely welcome! Whether you want to improve the Swift XPC security validation, refine the SwiftUI interface, or help build the `.dmg` packaging pipelines, please feel free to open a Pull Request.

## 📝 License
This project is open-source and licensed under the MIT License.