import Foundation
import DiskArbitration
import Shared

@main
struct MacNTFS {
    static func main() {
        print("Starting MacNTFS Daemon...")
        
        let session = DASessionCreate(kCFAllocatorDefault)
        guard let session = session else {
            print("Failed to create DASession")
            return
        }
        
        // Callback function for when a disk appears
        let diskAppearedCallback: DADiskAppearedCallback = { disk, context in
            guard let diskDesc = DADiskCopyDescription(disk) as? [String: Any],
                  let mediaName = diskDesc[kDADiskDescriptionMediaNameKey as String] as? String else {
                return
            }
            
            let isNTFS = (diskDesc[kDADiskDescriptionMediaContentKey as String] as? String) == "Windows_NTFS"
            
            print("Disk Appeared: \(mediaName)")
            if isNTFS {
                let uuid = diskDesc[kDADiskDescriptionMediaUUIDKey as String] as? UUID
                // Retrieve the UNIX device node (e.g., /dev/disk2s1)
                let bsdNamePtr = DADiskGetBSDName(disk)
                let bsdName = bsdNamePtr.map { String(cString: $0) } ?? "unknown"
                
                let uuidString = uuid?.uuidString ?? "UnknownUUID"
                print("🚨 NTFS Volume Detected! UUID: \(uuidString), BSD Name: \(bsdName)")
                
                if bsdName != "unknown" {
                    // 1. Fetch the user's configuration for this specific disk
                    let configMode = AppConfiguration.shared.getMode(forDiskUUID: uuidString)
                    
                    // 2. We always register it so the future UI can see it was plugged in
                    AppConfiguration.shared.registerDisk(uuid: uuidString, name: mediaName, mode: configMode)
                    
                    print("Disk configured mode is: \(configMode.rawValue)")
                    
                    switch configMode {
                    case .readWrite:
                        print("Initiating XPC call to Helper to remount /dev/\(bsdName) as Read/Write...")
                        HelperClient.shared.remountAsReadWrite(deviceNode: "/dev/\(bsdName)", volumeName: mediaName) { success, error in
                            if success {
                                print("✅ Successfully remounted \(mediaName) as Read/Write via FUSE-T/NTFS-3G!")
                            } else {
                                print("❌ Failed to remount: \(error ?? "Unknown error")")
                            }
                        }
                    case .readOnly:
                        print("Disk is configured as ReadOnly. Leaving macOS default mount intact.")
                    case .ignore:
                        print("Disk is configured to be ignored. Doing nothing.")
                    }
                }
            }
        }
        
        // Register the callback
        DARegisterDiskAppearedCallback(session, nil, diskAppearedCallback, nil)
        
        // Schedule the session on the current run loop
        DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        print("Daemon is running and listening for disk events. Press Ctrl+C to stop.")
        
        // Start the run loop to keep the daemon alive
        RunLoop.current.run()
    }
}
