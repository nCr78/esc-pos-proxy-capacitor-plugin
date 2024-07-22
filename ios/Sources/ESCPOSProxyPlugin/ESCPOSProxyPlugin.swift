import Foundation
import Capacitor

@objc(ESCPOSProxyPlugin)
public class ESCPOSProxyPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ESCPOSProxyPlugin"
    public let jsName = "ESCPOSProxy"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "print", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = ESCPOSProxy()

    @objc func print(_ call: CAPPluginCall) {
        guard let ip = call.getString("ip") else {
            call.reject("IP address is required")
            return
        }

        let port = call.getInt("port") ?? 9100

        guard let jsObject = call.getObject("message") else {
            call.reject("Data object is null")
            return
        }

        guard let data = convertToData(jsObject: jsObject) else {
            call.reject("Couldn't parse message")
            return
        }

        implementation.sendEscPosCommand(ip: ip, port: port, message: data) { success in
            if success {
                call.resolve(["status": "printed"]);
            } else {
                call.reject("Failed to send ESC/POS command")
            }
        }
    }

    private func convertToData(jsObject: JSObject) -> Data? {
        var byteArray = [UInt8]()
        for key in jsObject.keys.sorted(by: { Int($0)! < Int($1)! }) {
            if let value = jsObject[key] as? NSNumber {
                byteArray.append(UInt8(truncating: value))
            } else {
                return nil
            }
        }
        return Data(byteArray)
    }
}
