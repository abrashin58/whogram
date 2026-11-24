import Foundation
import class TDLibKit.TDLibClientManager
import protocol TDLibKit.TdQuery

private struct Command: TdQuery {
    let name: String

    func make(with extra: String?) throws -> Data {
        var json = ["@type": name]
        if let extra { json["@extra"] = extra }
        return try JSONSerialization.data(withJSONObject: json)
    }
}

private func object(from data: Data) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
}

private func waitFor(_ milestone: DispatchSemaphore, _ name: String) {
    guard milestone.wait(timeout: .now() + 20) == .success else {
        fatalError("TDLib smoke timed out: \(name)")
    }
}

private func exercise(_ transport: TDLibClientManager) throws -> Int32 {
    let parameters = DispatchSemaphore(value: 0)
    let echoed = DispatchSemaphore(value: 0)
    let closed = DispatchSemaphore(value: 0)
    let client = transport.createClient { data, _ in
        let json = object(from: data)
        guard json["@type"] as? String == "updateAuthorizationState",
              let state = json["authorization_state"] as? [String: Any] else { return }
        switch state["@type"] as? String {
        case "authorizationStateWaitTdlibParameters": parameters.signal()
        case "authorizationStateClosed": closed.signal()
        default: break
        }
    }
    waitFor(parameters, "initial WaitTdlibParameters update")
    try client.send(query: Command(name: "getAuthorizationState")) { data in
        precondition(object(from: data)["@type"] as? String == "authorizationStateWaitTdlibParameters")
        echoed.signal()
    }
    waitFor(echoed, "correlated getAuthorizationState response")
    // Stop before sending setTdlibParameters; do not open a database or send an auth request.
    try client.send(query: Command(name: "close"), completion: nil)
    waitFor(closed, "Closed update")
    return client.id
}

private let transport = TDLibClientManager()
private let first = try exercise(transport)
private let second = try exercise(transport)
precondition(first != second, "Closing a TDLib client must release its ID before app-level reconstruction")
print("OK: real TDLib WaitTdlibParameters -> Closed, request correlation and distinct client IDs")
