import Foundation

@objc public class ESCPOSProxy: NSObject {
    @objc public func print(ip: String, port: Int, data: Data?) -> String {
        sendEscPosCommand(ip: ip, port: port, message: data) { success in
            if success {
                return "printed";
            } else {
                return nil
            }
        }
    }

    private func sendEscPosCommand(ip: String, port: Int, message: Data, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            var success = false

            let host = CFHostCreateWithName(nil, ip as CFString).takeRetainedValue()
            var resolved: DarwinBoolean = false
            if CFHostStartInfoResolution(host, .addresses, nil) {
                var successResolution = DarwinBoolean(false)
                let addresses = CFHostGetAddressing(host, &successResolution)?.takeUnretainedValue() as NSArray?
                if let addresses = addresses as? [Data], let address = addresses.first {
                    var writeStream: Unmanaged<CFWriteStream>?
                    address.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                        let sockaddrPointer = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self)
                        CFStreamCreatePairWithSocketToAddress(nil, sockaddrPointer, nil, &writeStream)
                    }

                    if let writeStream = writeStream {
                        let outputStream = writeStream.takeRetainedValue()

                        outputStream.open()

                        let bytesWritten = message.withUnsafeBytes {
                            outputStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: message.count)
                        }

                        if bytesWritten == message.count {
                            success = true
                        }

                        outputStream.close()
                    }
                }
            }

            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
