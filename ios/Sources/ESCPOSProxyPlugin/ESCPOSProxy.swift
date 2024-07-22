import Foundation
import Network

@objc public class ESCPOSProxy: NSObject {
    @objc public func sendEscPosCommand(ip: String, port: Int, message: Data, completion: @escaping (Bool) -> Void) {
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)), using: .tcp)

        connection.stateUpdateHandler = { (newState) in
            switch (newState) {
            case .ready:
                print("Connected to \(ip):\(port)")
                connection.send(content: message, completion: .contentProcessed({ (error) in
                    if let error = error {
                        print("Failed to send message: \(error)")
                        completion(false)
                    } else {
                        print("Message sent successfully")
                        completion(true)
                    }
                    connection.cancel()
                }))
            case .failed(let error):
                print("Failed to connect: \(error)")
                completion(false)
                connection.cancel()
            default:
                break
            }
        }

        let queue = DispatchQueue(label: "escpos-proxy")
        connection.start(queue: queue)
    }
}
