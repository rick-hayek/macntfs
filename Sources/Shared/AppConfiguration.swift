import Foundation
import os.log

public enum MountMode: String, Codable {
    case readWrite = "ReadWrite"
    case readOnly = "ReadOnly"
    case ignore = "Ignore"
}

public struct DiskConfig: Codable {
    public let uuid: String
    public var name: String
    public var mode: MountMode
    public var lastConnected: Date
    
    public init(uuid: String, name: String, mode: MountMode, lastConnected: Date) {
        self.uuid = uuid
        self.name = name
        self.mode = mode
        self.lastConnected = lastConnected
    }
}

public final class AppConfiguration: @unchecked Sendable {
    public static let shared = AppConfiguration()
    
    private let defaults: UserDefaults?
    private let logger = OSLog(subsystem: "com.macntfs.Shared", category: "Config")
    
    // The App Group identifier must match the one in our entitlements
    private let appGroupIdentifier = "group.com.macntfs"
    private let disksKey = "ConfiguredDisks"
    private let defaultModeKey = "DefaultMountMode"
    
    private init() {
        self.defaults = UserDefaults(suiteName: appGroupIdentifier)
        if self.defaults == nil {
            os_log("Warning: Failed to initialize UserDefaults with suiteName %{public}s. Falling back to standard.", log: self.logger, type: .error, appGroupIdentifier)
        }
    }
    
    private var actualDefaults: UserDefaults {
        return defaults ?? UserDefaults.standard
    }
    
    /// The default mount mode when a totally new disk is inserted
    public var defaultMountMode: MountMode {
        get {
            guard let raw = actualDefaults.string(forKey: defaultModeKey),
                  let mode = MountMode(rawValue: raw) else {
                return .readWrite // Assume users want R/W by default for a tool like this
            }
            return mode
        }
        set {
            actualDefaults.set(newValue.rawValue, forKey: defaultModeKey)
        }
    }
    
    /// Fetch all configured disks
    public func getConfiguredDisks() -> [String: DiskConfig] {
        guard let data = actualDefaults.data(forKey: disksKey),
              let disks = try? JSONDecoder().decode([String: DiskConfig].self, from: data) else {
            return [:]
        }
        return disks
    }
    
    /// Save all disks
    private func saveConfiguredDisks(_ disks: [String: DiskConfig]) {
        if let encoded = try? JSONEncoder().encode(disks) {
            actualDefaults.set(encoded, forKey: disksKey)
        }
    }
    
    /// Get the mode for a specific disk UUID, returning the default mode if not explicitly mapped
    public func getMode(forDiskUUID uuid: String) -> MountMode {
        let disks = getConfiguredDisks()
        if let config = disks[uuid] {
            return config.mode
        }
        return defaultMountMode
    }
    
    /// Register or update a seen disk
    public func registerDisk(uuid: String, name: String, mode: MountMode? = nil) {
        var disks = getConfiguredDisks()
        
        let targetMode = mode ?? (disks[uuid]?.mode ?? defaultMountMode)
        
        let config = DiskConfig(uuid: uuid, name: name, mode: targetMode, lastConnected: Date())
        disks[uuid] = config
        saveConfiguredDisks(disks)
        
        os_log("Registered disk state: %{public}s (%{public}s) -> %{public}s", log: logger, type: .info, name, uuid, targetMode.rawValue)
    }
}
