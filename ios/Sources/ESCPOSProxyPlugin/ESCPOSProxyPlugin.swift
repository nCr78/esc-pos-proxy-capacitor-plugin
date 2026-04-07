import Foundation
import Capacitor

@objc(ESCPOSProxyPlugin)
public class ESCPOSProxyPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ESCPOSProxyPlugin"
    public let jsName = "ESCPOSProxy"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "print", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "ping", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "discover", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = ESCPOSProxy()

    @objc func print(_ call: CAPPluginCall) {
        guard let ip = call.getString("ip"), !ip.isEmpty else {
            call.reject("IP address is required")
            return
        }

        let port = call.getInt("port") ?? 9100

        guard let base64Message = call.getString("message") else {
            call.reject("message is required (base64-encoded ESC/POS bytes)")
            return
        }

        guard let data = Data(base64Encoded: base64Message) else {
            call.reject("message is not valid base64")
            return
        }

        implementation.sendEscPosCommand(ip: ip, port: port, message: data) { success in
            if success {
                call.resolve(["status": "printed"])
            } else {
                call.reject("Failed to send ESC/POS command")
            }
        }
    }

    @objc func ping(_ call: CAPPluginCall) {
        guard let ip = call.getString("ip") else {
            call.reject("IP address is required")
            return
        }
        let port = call.getInt("port") ?? 9100

        implementation.ping(ip: ip, port: port) { online, rtt in
            var response: [String: Any] = ["online": online]
            if let rtt = rtt, online {
                response["rtt"] = rtt
            }
            call.resolve(response)
        }
    }

    @objc func discover(_ call: CAPPluginCall) {
        let ports = call.getArray("ports", Int.self) ?? [9100, 9101, 9102]
        let timeout = call.getInt("timeout") ?? 10000

        implementation.discoverPrinters(ports: ports, timeout: timeout) { printers in
            call.resolve(["printers": printers])
        }
    }
}
