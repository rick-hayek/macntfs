import SwiftUI
import Shared
import ServiceManagement

struct SettingsView: View {
    @State private var configuredDisks: [String: DiskConfig] = [:]
    @State private var defaultMode: MountMode = AppConfiguration.shared.defaultMountMode
    
    // Timer to poll for updates (since UserDefaults isn't natively @Published across processes without more setup)
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            HeaderView()
            
            Divider()
            
            DaemonManagementSection()
            
            Divider()
            
            GlobalSettingsSection(defaultMode: $defaultMode)
            
            Divider()
            
            DisksListSection(configuredDisks: $configuredDisks)
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 450)
        .onAppear(perform: loadData)
        .onReceive(timer) { _ in
            loadData()
        }
    }
    
    private func loadData() {
        self.configuredDisks = AppConfiguration.shared.getConfiguredDisks()
    }
}

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text("MacNTFS Configuration")
                    .font(.title)
                    .bold()
                Text("Manage your external Windows NTFS drives.")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct GlobalSettingsSection: View {
    @Binding var defaultMode: MountMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Global Settings")
                .font(.headline)
            
            HStack {
                Text("Default action for new NTFS disks:")
                Picker("", selection: Binding(
                    get: { self.defaultMode },
                    set: { newValue in
                        self.defaultMode = newValue
                        AppConfiguration.shared.defaultMountMode = newValue
                    }
                )) {
                    Text("Remount as Read/Write").tag(MountMode.readWrite)
                    Text("Leave as Read-Only").tag(MountMode.readOnly)
                    Text("Ignore").tag(MountMode.ignore)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
            }
        }
    }
}

struct DisksListSection: View {
    @Binding var configuredDisks: [String: DiskConfig]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Known Disks")
                .font(.headline)
            
            if configuredDisks.isEmpty {
                Text("No NTFS disks have been connected yet.")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else {
                List(Array(configuredDisks.values.sorted(by: { $0.lastConnected > $1.lastConnected })), id: \.uuid) { disk in
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(disk.name)
                                .font(.body)
                                .bold()
                            Text("UUID: \(disk.uuid)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { disk.mode },
                            set: { newMode in
                                AppConfiguration.shared.registerDisk(uuid: disk.uuid, name: disk.name, mode: newMode)
                                // Data will reload on the next timer tick
                            }
                        )) {
                            Text("Read/Write").tag(MountMode.readWrite)
                            Text("Read-Only").tag(MountMode.readOnly)
                            Text("Ignore").tag(MountMode.ignore)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    .padding(.vertical, 4)
                }
                // Background needed for older macOS List styles sometimes, but usually fine in modern SwiftUI
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
}

struct DaemonManagementSection: View {
    @ObservedObject var daemonManager = DaemonManager.shared
    
    var statusText: String {
        switch daemonManager.currentStatus {
        case .notRegistered:
            return "Not Installed (NTFS drives will mount as Read-Only)"
        case .enabled:
            return "Running (Active and Monitoring)"
        case .requiresApproval:
            return "Requires Approval in System Settings -> Login Items"
        case .notFound:
            return "Helper Executable Not Found"
        default:
            return "Unknown Status"
        }
    }
    
    var statusColor: Color {
        switch daemonManager.currentStatus {
        case .enabled: return .green
        case .notRegistered: return .orange
        case .requiresApproval: return .yellow
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Helper Daemon Status")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                Text(statusText)
                    .font(.subheadline)
                
                Spacer()
                
                if daemonManager.currentStatus == .notRegistered || daemonManager.currentStatus == .notFound {
                    Button("Install Helper") {
                        daemonManager.installDaemon()
                    }
                } else {
                    Button("Uninstall Helper") {
                        daemonManager.uninstallDaemon()
                    }
                }
            }
            
            if let errorMsg = daemonManager.errorMessage {
                Text(errorMsg)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Text("The daemon is required to securely perform the actual read/write mounting process in the background without constantly prompting for your password.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            daemonManager.refreshStatus()
        }
    }
}
