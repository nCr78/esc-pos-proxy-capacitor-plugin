import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(ESCPOSProxyPlugin)
public class ESCPOSProxyPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ESCPOSProxyPlugin"
    public let jsName = "ESCPOSProxy"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "echo", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = ESCPOSProxy()

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }
}
