import Foundation
import ServiceManagement
import os.log

public final class DaemonManager: ObservableObject, @unchecked Sendable {
    public static let shared = DaemonManager()
    private let logger = OSLog(subsystem: "com.macntfs.App", category: "DaemonManager")
    
    // The identifier must match the Info.plist CFBundleIdentifier of the helper
    private let helperIdentifier = "com.macntfs.Helper"
    
    @Published public var currentStatus: SMAppService.Status = .notRegistered
    @Published public var errorMessage: String?
    
    // Lazy initialize the service object
    private lazy var helperService: SMAppService = {
        return SMAppService.daemon(plistName: "com.macntfs.Helper.plist")
    }()
    
    private init() {
        refreshStatus()
    }
    
    /// Checks the current registration status of the daemon
    public func refreshStatus() {
        DispatchQueue.main.async {
            self.currentStatus = self.helperService.status
            os_log("Daemon status refreshed: %{public}ld", log: self.logger, type: .info, self.currentStatus.rawValue)
        }
    }
    
    /// Registers and starts the daemon. Prompts user for admin privileges.
    public func installDaemon() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.helperService.register()
                os_log("Successfully registered daemon.", log: self.logger, type: .info)
                self.refreshStatus()
            } catch {
                let errorStr = "Failed to install daemon: \(error.localizedDescription)"
                os_log("%{public}s", log: self.logger, type: .error, errorStr)
                DispatchQueue.main.async {
                    self.errorMessage = errorStr
                    self.refreshStatus()
                }
            }
        }
    }
    
    /// Unregisters and stops the daemon. Prompts user for admin privileges.
    public func uninstallDaemon() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.helperService.unregister()
                os_log("Successfully unregistered daemon.", log: self.logger, type: .info)
                self.refreshStatus()
            } catch {
                let errorStr = "Failed to uninstall daemon: \(error.localizedDescription)"
                os_log("%{public}s", log: self.logger, type: .error, errorStr)
                DispatchQueue.main.async {
                    self.errorMessage = errorStr
                    self.refreshStatus()
                }
            }
        }
    }
}
