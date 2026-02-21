import Foundation
import Shared
import os.log

nonisolated(unsafe) let logger = OSLog(subsystem: "com.macntfs.Helper", category: "Daemon")

class MacNTFSHelper: NSObject, HelperProtocol {
    func remountAsReadWrite(deviceNode: String, volumeName: String, reply: @escaping (Bool, String?) -> Void) {
        os_log("Received request to remount %{public}s at %{public}s", log: logger, type: .info, deviceNode, volumeName)
        
        // 1. Unmount the existing readonly mount
        let unmountTask = Process()
        unmountTask.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        unmountTask.arguments = ["unmount", "force", deviceNode]
        
        do {
            try unmountTask.run()
            unmountTask.waitUntilExit()
            
            if unmountTask.terminationStatus != 0 {
                let errorMsg = "Failed to unmount \(deviceNode)"
                os_log("%{public}s", log: logger, type: .error, errorMsg)
                reply(false, errorMsg)
                return
            }
            
            // 2. We need to create the directory
            let mountPoint = "/Volumes/\(volumeName)"
            let mkdirTask = Process()
            mkdirTask.executableURL = URL(fileURLWithPath: "/bin/mkdir")
            mkdirTask.arguments = ["-p", mountPoint]
            
            try mkdirTask.run()
            mkdirTask.waitUntilExit()
            
            // 3. Mount using ntfs-3g and fuse-t
            let mountTask = Process()
            mountTask.executableURL = URL(fileURLWithPath: "/usr/local/bin/ntfs-3g")
            // These arguments depend on how FUSE-T handles NTFS-3G; typical are:
            mountTask.arguments = [deviceNode, mountPoint, "-o", "local,allow_other,volname=\(volumeName)"]
            
            try mountTask.run()
            mountTask.waitUntilExit()
            
            if mountTask.terminationStatus == 0 {
                os_log("Successfully remounted %{public}s", log: logger, type: .info, volumeName)
                reply(true, nil)
            } else {
                let errorMsg = "ntfs-3g failed with status \(mountTask.terminationStatus)"
                os_log("%{public}s", log: logger, type: .error, errorMsg)
                reply(false, errorMsg)
            }
        } catch {
            let errorMsg = "Execution error: \(error.localizedDescription)"
            os_log("%{public}s", log: logger, type: .error, errorMsg)
            reply(false, errorMsg)
        }
    }
    
    func getVersion(reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }
}

class MacNTFSHelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = MacNTFSHelper()
        newConnection.resume()
        return true
    }
}

@main
struct HelperMain {
    static func main() {
        os_log("MacNTFS Helper Daemon starting up...", log: logger, type: .info)
        let delegate = MacNTFSHelperDelegate()
        let listener = NSXPCListener(machServiceName: "com.macntfs.Helper")
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}
