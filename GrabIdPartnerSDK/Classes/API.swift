//
// Created by JimLai on 2020/2/10.
//

import Foundation

typealias P = Params
enum Params: String {
    case accessToken, idToken, tokenId, refreshToken, client_id, code_challenge, code_challenge_method, device_id
    case nonce, redirect_uri, response_type, state, scope, login_hint, id_token_hint, prompt, request, acr_values
    case auth_endpoint, authorization_endpoint, token_endpoint, id_token_verification_endpoint, client_public_info_endpoint
    case grant_type, code_verifier, code, access_token, refresh_token, token_type, id_token, expires_in
    case audience, expires_at, issue_at, issuer, notValidBefore, partnerId, partnerUserId, service
}

protocol Resource: class {
    var url: String { get set }
    var success: ((JSON) -> ())? { get set }
    var fail: ((GrabIdPartnerError) -> ())? { get set }
    func onSuccess(_ cb: @escaping (JSON) -> ()) -> Self
    func onFailure(_ cb: @escaping (GrabIdPartnerError) -> ()) -> Self
    func dataTask(_ req: URLRequest) -> URLSessionTask
    func preError()
    func post(urlParams: [Params: String]) -> Self
    func get() -> Self
}

extension Resource {
    @discardableResult
    func onSuccess(_ cb: @escaping (JSON) -> ()) -> Self {
        success = cb
        return self
    }

    @discardableResult
    func onFailure(_ cb: @escaping (GrabIdPartnerError) -> ()) -> Self {
        fail = cb
        return self
    }

    func get() -> Self {
        guard let url = URL(string: self.url) else {
            preError()
            return self
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let task = dataTask(req)
        task.resume()
        return self
    }
    func percentEncodedGet(urlParams: [Params: String]) -> Self {
        guard var urlComponents = URLComponents(string: url) else {
            preError()
            return self
        }
        urlComponents.queryItems = urlParams.map { (kv) in
            URLQueryItem(name: kv.key.rawValue, value: kv.value)
        }
        urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let encoded = urlComponents.url else {
            preError()
            return self
        }
        var urlRequest = URLRequest(url: encoded)
        urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.httpMethod = "GET"
        let task = dataTask(urlRequest)
        task.resume()
        return self
    }

    func post(urlParams: [Params: String]) -> Self {
        guard var urlComponents = URLComponents(string: url) else {
            preError()
            return self
        }
        urlComponents.queryItems = urlParams.map { (kv) in
            URLQueryItem(name: kv.key.rawValue, value: kv.value)
        }
        guard let encoded = urlComponents.url else {
            preError()
            return self
        }
        var req = URLRequest(url: encoded)
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpMethod = "POST"
        let task = dataTask(req)
        task.resume()
        return self
    }

    func preError() {
        DispatchQueue.main.async { [weak self] in
            let e = GrabIdPartnerError(code: .grabIdServiceFailed,
                    localizedMessage: Loc.invalidUrl,
                    domain: .serviceDiscovery,
                    serviceError: nil)
            self?.fail?(e)
        }
    }

    func dataTask(_ req: URLRequest) -> URLSessionTask {
        let task = URLSession.shared.dataTask(with: req) { (data, response, error) in
            guard error == nil else {
                let e = GrabIdPartnerError(code: .grabIdServiceFailed,
                        localizedMessage: Loc.invalidResponse,
                        domain: .serviceDiscovery,
                        serviceError: error)
                DispatchQueue.main.async {
                    self.fail?(e)
                }
                return
            }
            guard let resp = response as? HTTPURLResponse, (200...299 ~= resp.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode
                let e = GrabIdPartnerError(code: .discoveryServiceFailed,
                        localizedMessage: "\(code ?? 0)",
                        domain: .serviceDiscovery,
                        serviceError: nil)
                DispatchQueue.main.async {
                    self.fail?(e)
                }
                return
            }

            guard let data = data else {
                let e = GrabIdPartnerError(code: .grabIdServiceFailed,
                        localizedMessage: Loc.invalidResponse,
                        domain: .serviceDiscovery,
                        serviceError: error)
                DispatchQueue.main.async {
                    self.fail?(e)
                }
                return
            }
            DispatchQueue.main.async {
                self.success?(JSON(data))
            }

        }
        return task
    }
}

final class Json: Resource {
    var fail: ((GrabIdPartnerError) -> ())?

    var url: String

    var success: ((JSON) -> ())?

    init(_ url: String) {
        self.url = url
    }
}

public extension Dictionary where Key: RawRepresentable, Key.RawValue == String {
    func toStringKey() -> [String: Any] {
        var d = [String: Any]()
        for k in self.keys {
            let v = self[k]!
            if let x = v as? [Key: Any] {
                d[k.rawValue] = x.toStringKey()
            }
            else {
                d[k.rawValue] = v
            }
        }
        return d
    }
}


public indirect enum JSON {
    case arr([Any]), dict([String: Any]), json(JSON), raw(Any), null
    public init<T>(_ pd: [T: Any]) where T: RawRepresentable, T.RawValue == String {
        self.init(pd.toStringKey())
    }

    public init(_ any: Any?) {
        guard let any = any else {
            self = .null
            return
        }
        switch any {
        case let x as [Any]:
            self = .arr(x)
        case let x as [String: Any]:
            self = .dict(x)
        case let x as JSON:
            self = .json(x)
        case let x as Data:
            guard let json = try? JSONSerialization.jsonObject(with: x) else {
                self = .null
                return
            }
            switch json {
            case let x as [String: Any]:
                self = .dict(x)
            case let x as [Any]:
                self = .arr(x)
            default:
                self = .null
            }
        default:
            self = .raw(any)
        }
    }
}

public extension JSON {
     subscript<T>(_ rs: T) -> JSON where T: RawRepresentable, T.RawValue == String {
        switch self {
        case .dict(let d):
            return JSON(d[rs.rawValue])
        default:
            return .null
        }
    }
    subscript(_ i: Int) -> JSON {
        switch self {
        case .arr(let arr):
            guard 0..<arr.count ~= i else {
                return .null
            }
            return JSON(arr[i])
        default:
            return .null
        }
    }
    var stringValue: String {
        switch self {
        case .raw(let x):
            return String(describing: x)
        default:
            return ""
        }
    }

    var string: String? {
        switch self {
        case .raw(let x):
            return x as? String
        default:
            return ""
        }
    }
    var intValue: Int {
        switch self {
        case .raw(let x):
            return x as? Int ?? 0
        default:
            return 0
        }
    }
}