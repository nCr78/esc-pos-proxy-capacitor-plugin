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

        guard let dataObject = call.getObject("message") else {
            call.reject("Data object is null")
            return
        }

        guard let data = extractByteArrayFromJSON(dataObject) else {
            call.reject("Failed to read data array")
            return
        }
        guard let ret = implementation.print(ip, port, data) else {
            call.reject("Failed to send ESC/POS command")
            return
        }
        call.resolve(["status": ret])
    }

    private func extractByteArrayFromJSON(_ dataObject: JSObject) -> Data? {
        var data = Data()
        for key in dataObject.keys.sorted() {
            if let value = dataObject[key] as? Int {
                data.append(UInt8(value))
            } else {
                return nil
            }
        }
        return data
    }
}
