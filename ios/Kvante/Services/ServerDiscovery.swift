import Foundation
import Network

@Observable
final class ServerDiscovery {
    var serverURL: URL?
    var isSearching = false
    var errorMessage: String?

    private var browser: NWBrowser?

    func startSearching() {
        isSearching = true
        errorMessage = nil

        let params = NWParameters()
        params.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: "_kvante._tcp", domain: nil), using: params)

        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .failed(let error):
                    self?.errorMessage = "Søgning fejlede: \(error.localizedDescription)"
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            for result in results {
                if case .service(let name, let type, let domain, _) = result.endpoint {
                    self.resolveService(name: name, type: type, domain: domain)
                    return
                }
            }
        }

        browser?.start(queue: .main)
    }

    func stopSearching() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func resolveService(name: String, type: String, domain: String) {
        let connection = NWConnection(
            to: .service(name: name, type: type, domain: domain, interface: nil),
            using: .tcp
        )
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    DispatchQueue.main.async {
                        let hostStr: String
                        switch host {
                        case .ipv4(let addr):
                            hostStr = "\(addr)"
                        case .ipv6(let addr):
                            hostStr = "[\(addr)]"
                        case .name(let name, _):
                            hostStr = name
                        @unknown default:
                            hostStr = "localhost"
                        }
                        self?.serverURL = URL(string: "http://\(hostStr):\(port)")
                        self?.isSearching = false
                        connection.cancel()
                    }
                }
            }
        }
        connection.start(queue: .main)
    }

    /// Manual fallback for when Bonjour doesn't work
    func setManualURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            serverURL = url
            errorMessage = nil
        }
    }
}
