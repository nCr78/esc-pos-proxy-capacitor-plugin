import Foundation

@objc public class ESCPOSProxy: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
