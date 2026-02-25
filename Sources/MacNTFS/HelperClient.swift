import Foundation
import Shared
import os.log

nonisolated(unsafe) let logger = OSLog(subsystem: "com.macntfs.App", category: "Client")

public final class HelperClient: @unchecked Sendable {
    public static let shared = HelperClient()
    
    // We connect to the Mach service registered by HelperMain
    private lazy var connection: NSXPCConnection = {
        let connection = NSXPCConnection(machServiceName: "com.macntfs.Helper", options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        
        connection.interruptionHandler = {
            os_log("XPC Connection Interrupted", log: logger, type: .error)
        }
        
        connection.invalidationHandler = {
            os_log("XPC Connection Invalidated", log: logger, type: .error)
        }
        
        connection.resume()
        return connection
    }()
    
    private func getHelper() -> HelperProtocol? {
        return connection.remoteObjectProxyWithErrorHandler { error in
            os_log("Failed to get remote object proxy: %{public}s", log: logger, type: .error, error.localizedDescription)
        } as? HelperProtocol
    }
    
    func remountAsReadWrite(deviceNode: String, volumeName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let helper = getHelper() else {
            completion(false, "Failed to establish proxy connection to helper")
            return
        }
        
        helper.remountAsReadWrite(deviceNode: deviceNode, volumeName: volumeName) { success, errorMsg in
            completion(success, errorMsg)
        }
    }
    
    func checkHelperVersion(completion: @escaping (String?) -> Void) {
        guard let helper = getHelper() else {
            completion(nil)
            return
        }
        helper.getVersion { version in
            completion(version)
        }
    }
}
