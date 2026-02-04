import Foundation
import Network
import Darwin

@objc public class ESCPOSProxy: NSObject {
    private var mdnsHelper: MdnsCollector?

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

    @objc public func ping(ip: String, port: Int, completion: @escaping (Bool, Double?) -> Void) {
        let start = DispatchTime.now()
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)), using: .tcp)
        let queue = DispatchQueue(label: "escpos-ping-\(ip)-\(port)")
        var finished = false

        let finish: (Bool) -> Void = { success in
            if finished {
                return
            }
            finished = true
            let elapsed = success ? Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0 : nil
            completion(success, elapsed)
            connection.cancel()
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true)
            case .failed(_), .cancelled:
                finish(false)
            default:
                break
            }
        }

        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + .seconds(3)) {
            finish(false)
        }
    }

    @objc public func discoverPrinters(ports: [Int], timeout: Int, completion: @escaping ([[String: Any]]) -> Void) {
        let targetPorts = ports.isEmpty ? [9100, 9101, 9102] : ports
        var collected = [[String: Any]]()
        var seen = Set<String>()
        let group = DispatchGroup()

        group.enter()
        mdnsHelper = MdnsCollector(resolver: { [weak self] data in
            return self?.ipv4String(from: data)
        }, completion: { [weak self] found in
            collected.append(contentsOf: found)
            self?.mdnsHelper = nil
            group.leave()
        })
        mdnsHelper?.start(types: ["_pdl-datastream._tcp.", "_printer._tcp."], timeoutMs: timeout)

        group.enter()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            if let scanResults = self?.scanSubnet(ports: targetPorts, timeoutMs: timeout) {
                collected.append(contentsOf: scanResults)
            }
            group.leave()
        }

        group.notify(queue: DispatchQueue.main) {
            let deduped = collected.filter { item in
                guard let ip = item["ip"] as? String, let port = item["port"] as? Int, let source = item["source"] as? String else {
                    return false
                }
                let key = "\(ip):\(port):\(source)"
                if seen.contains(key) {
                    return false
                }
                seen.insert(key)
                return true
            }
            completion(deduped)
        }
    }

    private func scanSubnet(ports: [Int], timeoutMs: Int) -> [[String: Any]] {
        guard let prefix = localPrefix() else {
            return []
        }

        let semaphore = DispatchSemaphore(value: 20)
        let group = DispatchGroup()
        var results = [[String: Any]]()
        let lock = NSLock()
        let perHostTimeout = max(200, min(1000, timeoutMs / 4))

        for host in 1...254 {
            let ip = "\(prefix).\(host)"
            semaphore.wait()
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                defer {
                    semaphore.signal()
                    group.leave()
                }
                for port in ports {
                    if self.checkPort(ip: ip, port: port, timeoutMs: perHostTimeout) {
                        lock.lock()
                        results.append(["ip": ip, "port": port, "source": "scan"])
                        lock.unlock()
                        break
                    }
                }
            }
        }

        group.wait()
        return results
    }

    private func checkPort(ip: String, port: Int, timeoutMs: Int) -> Bool {
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)), using: .tcp)
        let queue = DispatchQueue(label: "escpos-check-\(ip)-\(port)")
        let group = DispatchGroup()
        var reachable = false
        var finished = false

        let finish: (Bool) -> Void = { success in
            if finished {
                return
            }
            finished = true
            reachable = success
            connection.cancel()
            group.leave()
        }

        group.enter()
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true)
            case .failed(_), .cancelled:
                finish(false)
            default:
                break
            }
        }

        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) {
            finish(reachable)
        }

        group.wait()
        return reachable
    }

    private func localPrefix() -> String? {
        var addressList: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&addressList) == 0, let first = addressList else {
            return nil
        }
        defer { freeifaddrs(addressList) }

        var pointer = first
        while true {
            let interface = pointer.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("pdp_ip") || name.hasPrefix("wlan") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    let ipString = String(cString: hostname)
                    let components = ipString.split(separator: ".")
                    if components.count == 4 {
                        return components.dropLast().joined(separator: ".")
                    }
                }
            }
            if let next = interface.ifa_next {
                pointer = next
            } else {
                break
            }
        }
        return nil
    }

    private func ipv4String(from data: Data) -> String? {
        return data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> String? in
            guard let baseAddress = pointer.baseAddress else { return nil }
            let socketAddress = baseAddress.assumingMemoryBound(to: sockaddr.self)
            if socketAddress.pointee.sa_family == sa_family_t(AF_INET) {
                let addrIn = baseAddress.assumingMemoryBound(to: sockaddr_in.self)
                var addr = addrIn.pointee.sin_addr
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                let conversion = inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                if conversion != nil {
                    return String(cString: buffer)
                }
            }
            return nil
        }
    }

    private class MdnsCollector: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
        private var results = [[String: Any]]()
        private var seen = Set<String>()
        private var completion: (([[String: Any]]) -> Void)?
        private var pendingSearches = 0
        private var browsers: [NetServiceBrowser] = []
        private var services: [NetService] = []
        private let resolver: (Data) -> String?

        init(resolver: @escaping (Data) -> String?, completion: @escaping ([[String: Any]]) -> Void) {
            self.resolver = resolver
            self.completion = completion
        }

        func start(types: [String], timeoutMs: Int) {
            pendingSearches = types.count
            for type in types {
                let browser = NetServiceBrowser()
                browser.delegate = self
                browsers.append(browser)
                browser.searchForServices(ofType: type, inDomain: "local.")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) { [weak browser] in
                    browser?.stop()
                }
            }
        }

        func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
            services.append(service)
            service.delegate = self
            service.resolve(withTimeout: 5)
        }

        func netServiceDidResolveAddress(_ service: NetService) {
            let port = service.port
            guard port > 0 else { return }
            let ipCandidates = (service.addresses ?? []).compactMap { resolver($0) }
            guard let ip = ipCandidates.first else { return }
            let key = "\(ip):\(port)"
            if seen.insert(key).inserted {
                results.append(["ip": ip, "port": port, "source": "mdns"])
            }
        }

        func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
            finishSearch()
        }

        func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
            finishSearch()
        }

        private func finishSearch() {
            if pendingSearches > 0 {
                pendingSearches -= 1
            }
            if pendingSearches == 0 {
                completion?(results)
                completion = nil
            }
        }
    }
}
