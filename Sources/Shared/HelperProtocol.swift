import Foundation

@objc(HelperProtocol)
public protocol HelperProtocol {
    /// Remounts a disk as read/write
    /// - Parameters:
    ///   - deviceNode: The device node, e.g., "/dev/disk2s1"
    ///   - volumeName: The name of the volume to recreate at /Volumes/
    ///   - reply: Completion handler returning success status and optional error message
    func remountAsReadWrite(deviceNode: String, volumeName: String, reply: @escaping (Bool, String?) -> Void)
    
    /// Get the current version of the helper
    func getVersion(reply: @escaping (String) -> Void)
}
