/**
 * Copyright (c) Grab Taxi Holdings PTE LTD (GRAB)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import Foundation
import SafariServices

enum GrantType: String {
    case authorizationCode = "authorization_code"
    case refreshToken = "refresh_token"
}

struct Key {
    static let accessToken = "accessToken"
    static let idToken = "idToken"
    static let tokenId = "tokenId"
    static let refreshToken = "refreshToken"
    static let partnerUserId = "partnerUserId"
}

struct SecurityValue {
    var nonce = ""
    var state = ""
    var verifier = ""
    var codeChallenge = ""
}

struct Token {
    let accessToken: String
    let signedToken: String
    let unsignedToken: String
    let refreshToken: String
}


public final class SessionData: Codable {
    public var hint = ""
    public var idTokenHint = ""
    public var prompt = ""

    // setter internal, public get to GrabId Partner SDK
    public fileprivate(set) var code: String?
    public fileprivate(set) var codeVerifier: String?
    public fileprivate(set) var accessTokenExpiresAt: Date?
    public fileprivate(set) var state: String?
    public fileprivate(set) var tokenType: String?
    public fileprivate(set) var nonce: String?

    // don't store the tokens in user defaults, they are stored in the keychain

    public fileprivate(set) var serviceDiscoveryUrl = ""

    // end points
    fileprivate var authorizationEndpoint: String?
    fileprivate var tokenEndpoint: String?
    fileprivate var idTokenVerificationEndpoint: String?
    fileprivate var clientPublicInfoEndpoint: String?

    public init() {

    }
}

struct Config {
    let clientId: String
    let redirectUrl: String
    let scope: String
    let serviceDiscoveryUrl: String
    let request: String
    let acrValues: String
    let hint: String
    let idTokenHint: String
    let prompt: String

    init() {
        let bundle = Bundle.main
        var config = [String: String]()
        if let infoPlist = bundle.infoDictionary, let ip = infoPlist["GrabIdPartnerSDK"] as? [String: String] {
            config = ip
        }
        clientId = config["ClientId"] ?? ""
        redirectUrl = config["RedirectUrl"] ?? ""
        scope = config["Scope"] ?? ""
        serviceDiscoveryUrl = config["ServiceDiscoveryUrl"] ?? ""
        request = config["Request"] ?? ""
        acrValues = config["AcrValues"] ?? ""
        hint = config["Hint"] ?? ""
        idTokenHint = config["IdTokenHint"] ?? ""
        prompt = config["prompt"] ?? ""
    }
}

public final class GrabSDK {
    private let codeChallengeMethod = "S256"
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }
    private let authorization_grantType = "authorization_code"
    private let grantType = "refresh_token"
    private let responseType = "code"
    // internal to GrabId Partner SDK
    fileprivate var safariView: SFSafariViewController?
    fileprivate var codeChallenge: String?
    // Used by app for one time transactions scenario - base64 encoded jwt
    public var request: String?

    // The OpenID Connect ACR optional parameter to the authorize endpoint will be utilized to pass in
    // service id info and device ID
    public let acrValues = [String: String]()
    private let config = Config()
    public var sessionData = SessionData()
    public fileprivate(set) var accessToken = ""
    public fileprivate(set) var idToken = ""
    public fileprivate(set) var refreshToken = ""

    var baseURL = ""

    public static var shared: GrabSDK {
        GrabSDK()
    }

    var clientId: String {
        config.clientId
    }

    var scope: String {
        config.scope
    }

    var nonce: String {
        sessionData.nonce ?? ""
    }

    private var endpoints: JSON = .null {
        didSet {
            sessionData.authorizationEndpoint = endpoints[P.auth_endpoint].stringValue
            sessionData.tokenEndpoint = endpoints[P.token_endpoint].stringValue
            sessionData.idTokenVerificationEndpoint = endpoints[P.id_token_verification_endpoint].stringValue
            sessionData.clientPublicInfoEndpoint = endpoints[P.client_public_info_endpoint].string ?? "https://api.stg-myteksi.com/grabid/v1/oauth2/clients/{client_id}/public"
        }
    }

    func json(_ endpoint: String) -> Json {
        Json(baseURL + endpoint)
    }

    public func login(presentingViewController: UIViewController, completion: @escaping (GrabIdPartnerError?) -> Void) {
        // Restore sessionData if it is cached. If the refresh token is available, we will refresh the token
        // without going thru the web login flow. However, if refresh token failed, it will use web login flow
        // to get a new set of tokens.
        if accessToken == nil {
            // restore sessionData if the token is cached
            _ = restoreSessionData()
        }

        let now = Date()

        guard let expire = sessionData.accessTokenExpiresAt, !accessToken.isEmpty, expire > now else {
            completion(nil)
            return
        }
        getAuthenticateURL() { authUrl, loginWithGrabUrl, error in
            DispatchQueue.main.async { [weak self] in
                if let error = error {
                    completion(error)
                    return
                }

                if #available(iOS 10.0, *),
                   let loginWithGraburl = loginWithGrabUrl {
                    UIApplication.shared.open(loginWithGraburl, options: [:], completionHandler: { (success) in
                        if !success {
                            self?.webLogin(url: authUrl, presentingViewController: presentingViewController, completion: completion)
                        }
                    })
                } else {
                    self?.webLogin(url: authUrl, presentingViewController: presentingViewController, completion: completion)
                }
            }
        }
    }

    private func getLoginWithGrabDeepLink(loginWithGrabDict: [[String: String]]) -> String? {
        guard loginWithGrabDict.count > 0 else {
            return nil
        }

        if let preferredLoginWithGrabInfo = loginWithGrabDict.first {
            return preferredLoginWithGrabInfo["protocol_ios"]
        }
        return nil
    }

    private func getLoginWithGrabURLScheme(loginWithGrabDict: [[String: String]]) -> String? {
        guard loginWithGrabDict.count > 0 else {
            return nil
        }

        if let preferredLoginWithGrabInfo = loginWithGrabDict.first {
            return preferredLoginWithGrabInfo["protocol_pax_ios"]
        }
        return nil
    }

    private func schemeAvailable(urlScheme: String) -> Bool {
        if let url = URL(string: urlScheme) {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }

    private func launchDeeplink(deeplinkUrl: String) {
        if #available(iOS 10.0, *) {
            if let url = URL(string: deeplinkUrl) {
                UIApplication.shared.open(url, options: [:], completionHandler: { (success) in
                    debugPrint("Open \(deeplinkUrl): \(success)")
                })
            }
        } else {
            debugPrint("GrabIdPartnerSDK: launchDeeplink failed, minimum iOS version is 10.0.")
        }
    }

    private func loginWithGrabApp(loginUrl: URL) -> Bool {
        return false
    }

    private func webLogin(url: URL?, presentingViewController: UIViewController, completion: @escaping (GrabIdPartnerError?) -> Void) {
        guard let url = url else {
            let error = GrabIdPartnerError(code: .invalidUrl,
                    localizedMessage: sessionData.authorizationEndpoint ?? Loc.invalidUrl,
                    domain: .authorization,
                    serviceError: nil)
            completion(error)
            return
        }

        safariView = SFSafariViewController(url: url)
        if let safariView = safariView {
            presentingViewController.present(safariView, animated: true)
            completion(nil)
        }
    }

    public func exchangeToken(url: URL, completion: @escaping (GrabIdPartnerError?) -> Void) {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)

        let codeParam = urlComponents?.queryItems?.filter({ $0.name == "code" }).first
        let errorParam = urlComponents?.queryItems?.filter({ $0.name == "error" }).first
        let stateParam = urlComponents?.queryItems?.filter({ $0.name == "state" }).first

        guard errorParam?.value == nil else {
            let error = GrabIdPartnerError(code: .securityValidationFailed,
                    localizedMessage: Loc.securityValidationFailed,
                    domain: .exchangeToken,
                    serviceError: nil)
            DispatchQueue.main.async {
                completion(error)
            }
            return
        }

        guard let code = codeParam?.value,
              let state = stateParam?.value,
              state == sessionData.state else {
            let error = GrabIdPartnerError(code: .securityValidationFailed,
                    localizedMessage: Loc.securityValidationFailed,
                    domain: .exchangeToken,
                    serviceError: nil)
            DispatchQueue.main.async {
                completion(error)
            }
            return
        }

        // read token from keychain, return token from cache if it hasn't expired
        if restoreSessionData(),
           let accessTokenExpiresAt = sessionData.accessTokenExpiresAt,
           accessTokenExpiresAt > Date() {
            // cached sessionData contains valid access token.
            DispatchQueue.main.async {
                completion(nil)
            }
        } else {
            sessionData.code = code
            exchangeEndpoints.post(urlParams: exchangeParams).onSuccess { [weak self] json in
                completion(nil)
                self?.updateEndpoints(json)

            }.onFailure { [weak self] error in
                _ = self?.removeSessionData()
                completion(error)
            }
        }
    }

    func updateEndpoints(_ json: JSON) {
        let expiresIn = json[P.expires_in].intValue
        sessionData.accessTokenExpiresAt = Date(timeIntervalSinceNow: Double(expiresIn))
        accessToken = json[P.access_token].stringValue
        refreshToken = json[P.refresh_token].stringValue
        sessionData.tokenType = json[P.token_type].stringValue
        idToken = json[P.id_token].stringValue
        saveSessionData()
    }

    var exchangeParams: [Params: String] {
        var paramValues = [
            P.client_id: clientId,
            P.grant_type: GrantType.authorizationCode.rawValue
        ]

        // Only refresh token if client secret and refresh token are available.
        if !refreshToken.isEmpty {
            paramValues[P.refreshToken] = refreshToken
        } else {
            paramValues[P.redirect_uri] = config.redirectUrl
            paramValues[P.code_verifier] = sessionData.codeVerifier
            paramValues[P.code] = sessionData.code
        }
        return paramValues
    }

    var exchangeEndpoints: Json {
        json(sessionData.tokenEndpoint ?? "")
    }


    public func logout(completion: ((GrabIdPartnerError?) -> Void)? = nil) {
        accessToken = ""
        idToken = ""
        refreshToken = ""
        sessionData.authorizationEndpoint = ""
        sessionData.idTokenVerificationEndpoint = ""
        sessionData.tokenEndpoint = ""

        _ = loginCompleted()

        if removeSessionData(),
           let completion = completion {
            DispatchQueue.main.async {
                completion(nil)
            }
        } else {
            let error = GrabIdPartnerError(code: .logoutFailed, localizedMessage: Loc.logoutFailed,
                    domain: .logout, serviceError: nil)
            if let completion = completion {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    var resTokenInfo: Json?

    @Rx public var asyncTokenInfo: Result<IdTokenInfo, GrabIdPartnerError>?

    public func loadIdTokenInfo() {
        guard let idTokenVerificationEndpoint = sessionData.idTokenVerificationEndpoint else {
            let error = GrabIdPartnerError(code: .invalidIdToken, localizedMessage: Loc.invalidIdToken,
                    domain: .getIdTokenInfo, serviceError: nil)
            asyncTokenInfo = .failure(error)
            return
        }

        guard let nonce = sessionData.nonce else {
            let error = GrabIdPartnerError(code: .invalidNonce, localizedMessage: Loc.invalidNonce,
                    domain: .getIdTokenInfo, serviceError: nil)
            asyncTokenInfo = .failure(error)
            return
        }

        if let idTokenInfo = restoreIdToken(nonce),
           let expirationDate = idTokenInfo.expiration,
           expirationDate > Date() {
            // found valid idToken, return it
            self.asyncTokenInfo = .success(idTokenInfo)
            return
        } else {
            // delete the cache token and get a new one
            UserDefaults.standard.removeObject(forKey: nonce)
        }
        let paramValues = [
            P.client_id: clientId,
            P.id_token: idToken,
            P.nonce: nonce
        ]
        resTokenInfo = Json(idTokenVerificationEndpoint).percentEncodedGet(urlParams: paramValues).onFailure { error in
            self.asyncTokenInfo = .failure(error)
            _ = self.removeSessionData()
        }.onSuccess { json in
            guard let audienceIdValue = json[P.audience].string, !audienceIdValue.isEmpty,
                  let nonceValue = json[P.nonce].string, !nonceValue.isEmpty,
                  let serviceValue = json[P.service].string, !serviceValue.isEmpty,
                  let partnerIdValue = json[P.partnerId].string, !partnerIdValue.isEmpty,
                  let partnerUserIdValue = json[P.partnerUserId].string, !partnerUserIdValue.isEmpty,
                  let tokenIdValue = json[P.tokenId].string, !tokenIdValue.isEmpty else {
                let error = GrabIdPartnerError(code: .invalidNonce, localizedMessage: Loc.invalidNonce,
                        domain: .getIdTokenInfo, serviceError: nil)
                self.asyncTokenInfo = .failure(error)
                return
            }

            let idTokenInfo = IdTokenInfo(audience: audienceIdValue,
                    service: serviceValue,
                    notValidBefore: Date(timeIntervalSince1970: Double(json[P.notValidBefore].stringValue) ?? 0),
                    expiration: Date(timeIntervalSince1970: Double(json[P.expires_at].stringValue) ?? 0),
                    issueDate: Date(timeIntervalSince1970: Double(json[P.issue_at].stringValue) ?? 0),
                    issuer: json[P.issuer].stringValue,
                    tokenId: json[P.tokenId].stringValue,
                    partnerId: partnerIdValue,
                    partnerUserId: partnerUserIdValue,
                    nonce: nonceValue)

            self.saveIdTokenInfo(idTokenInfo)
            self.asyncTokenInfo = .success(idTokenInfo)
        }
    }


    public func loginCompleted(completion: (() -> Void)? = nil) -> Bool {
        guard let safariView = self.safariView else {
            if let dismissHandler = completion {
                DispatchQueue.main.async {
                    dismissHandler()
                }
            }
            return false
        }

        safariView.dismiss(animated: true) {
            if let dismissHandler = completion {
                DispatchQueue.main.async {
                    dismissHandler()
                }
                self.safariView = nil
            }
        }

        return true
    }


    // Helper to determine if the accessToken and idToken are valid and not expired.
    public var isValidAccessToken: Bool {
        let now = Date()
        guard !accessToken.isEmpty,
              let accessTokenExpired = sessionData.accessTokenExpiresAt,
              accessTokenExpired > now else {
            removeTokens()
            return false
        }

        return true
    }

    public func isValidIdToken(idTokenInfo: IdTokenInfo) -> Bool {
        guard let nonce = idTokenInfo.nonce else {
            return false
        }

        let now = Date()
        guard idTokenInfo.tokenId != nil,
              (idTokenInfo.expiration ?? now) > now,
              now >= (idTokenInfo.notValidBefore ?? Date()) else {
            UserDefaults.standard.removeObject(forKey: nonce)
            return false
        }
        return true
    }

    var userDefaultKey: String {
        let scopeArray = scope.lowercased().components(separatedBy: " ")
        let sortedScope = scopeArray.joined(separator: " ")
        guard !sortedScope.isEmpty else {
            return ""
        }

        return "\(clientId).\(sortedScope)"
    }


    // MARK: private functions
    private func loadTokens() -> Bool {
        let keyChain = KeychainTokenItem(service: clientId)

        // read token from keychain
        guard let accessToken = keyChain.readToken(id: Key.accessToken, scope: scope),
              let idToken = keyChain.readToken(id: Key.idToken, scope: scope),
              let refreshToken = keyChain.readToken(id: Key.refreshToken, scope: scope) else {
            _ = removeSessionData()
            return false
        }
        self.accessToken = accessToken
        self.idToken = idToken
        self.refreshToken = refreshToken
        return true
    }

    private func saveTokens() -> Bool {
        let keyChain = KeychainTokenItem(service: clientId)
        do {
            try keyChain.saveToken(id: Key.accessToken, scope: scope, token: accessToken)
            try keyChain.saveToken(id: Key.idToken, scope: scope, token: idToken)
            try keyChain.saveToken(id: Key.refreshToken, scope: scope, token: refreshToken)
            return true
        } catch {
            // delete the tokens from keychain == no caching
            _ = removeSessionData()
        }

        return false
    }

    // remove tokens from key chain
    fileprivate func removeTokens() {
        let keyChain = KeychainTokenItem(service: clientId)
        _ = try? keyChain.removeToken(id: Key.accessToken, scope: scope)
        _ = try? keyChain.removeToken(id: Key.refreshToken, scope: scope)
        _ = try? keyChain.removeToken(id: Key.idToken, scope: scope)

        accessToken = ""
        idToken = ""
        refreshToken = ""
    }

    private func saveSessionData() {
        guard saveTokens(), let encoded = try? JSONEncoder().encode(sessionData) else {
            return
        }
        UserDefaults.standard.set(encoded, forKey: userDefaultKey)
    }

    // If either idToken or accessToken have expired. We need to delete the cache sessionData
    // and return false and delete the cache login session.
    private func restoreSessionData() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: userDefaultKey),
              let sessionData = try? JSONDecoder().decode(SessionData.self, from: data),
              loadTokens() else {
            return false
        }
        // refresh token,access token, and idtoken are stored in the keychain and restored
        self.sessionData = sessionData
        return true
    }

    internal func removeSessionData() -> Bool {

        guard UserDefaults.standard.data(forKey: userDefaultKey) != nil else {
            return false
        }
        // delete token cache
        UserDefaults.standard.removeObject(forKey: userDefaultKey)
        removeTokens()
        return true
    }


    private func getSecurityValues() -> SecurityValue {
        guard let verifier = AuthorizationCodeGenerator.getCodeVerifier(), let codeChallenge = AuthorizationCodeGenerator.getCodeChallenge(verifier: verifier) else {
            return SecurityValue()
        }

        let nonce = NSUUID().uuidString.lowercased()
        let state = NSUUID().uuidString.lowercased()
        var v = SecurityValue()
        (v.nonce, v.state, v.verifier, v.codeChallenge) = (nonce, state, verifier, codeChallenge)
        return v
    }

    fileprivate static func getAcrValuesString(acrValues: [String: String]?) -> String? {
        var acrValueString: String? = nil
        if let acrValues = acrValues, acrValues.count > 0 {
            var acrValueArrays = [String]()
            for (key, value) in acrValues {
                if !key.isEmpty,
                   !value.isEmpty {
                    acrValueArrays.append("\(key):\(value)")
                }
            }
            acrValueString = acrValueArrays.joined(separator: " ")
        }

        return acrValueString
    }

    private func getLoginWithGrabDeeplinkDictionary(clientId: String, clientPublicInfoUri: String?, completion: @escaping ([[String: String]], GrabIdPartnerError?) -> Void) {
        if let clientPublicInfoUri = clientPublicInfoUri, !clientPublicInfoUri.isEmpty {
            let fullClientPublicInfoUri = clientPublicInfoUri.replacingOccurrences(of: "{client_id}", with: clientId, options: .literal, range: nil)
            GrabApi.fetchGrabAppDeeplinks(customProtocolUrl: fullClientPublicInfoUri) { (loginWithGrabDict, error) in
                completion(loginWithGrabDict, error)
            }
        } else {
            // service has no app registered to handle login with Grab
            completion([], nil)
        }
    }

    private func getLoginUrls(queryParams: [URLQueryItem],
                              completion: @escaping (URL?, URL?, GrabIdPartnerError?) -> Void) {
        guard let authEndpoint = sessionData.authorizationEndpoint, let authUrl = GrabApi.createUrl(baseUrl: authEndpoint, params: queryParams) else {
            let error = GrabIdPartnerError(code: .invalidUrl, localizedMessage: sessionData.authorizationEndpoint ?? Loc.invalidResponse,
                    domain: .authorization, serviceError: nil)
            completion(nil, nil, error)
            return
        }

        guard !queryParams.contains(where: { $0.name == "login_hint" || $0.name == "id_token_hint" || $0.name == "prompt" }) else {
            completion(authUrl, nil, nil)
            return
        }

        // get the login with grab deeplink (if any),
        var loginWithGrabAppUrl: URL? = nil

        getLoginWithGrabDeeplinkDictionary(clientId: clientId, clientPublicInfoUri: sessionData.clientPublicInfoEndpoint) { [weak self] loginWithGrabDict, error in
            if error == nil, let loginDeeplink = self?.getLoginWithGrabDeepLink(loginWithGrabDict: loginWithGrabDict) {
                var params = queryParams
                params.append(URLQueryItem(name: "auth_endpoint", value: authEndpoint))
                loginWithGrabAppUrl = GrabApi.createUrl(baseUrl: loginDeeplink, params: params)
            }

            DispatchQueue.main.async {
                let validateURLScheme = self?.getLoginWithGrabURLScheme(loginWithGrabDict: loginWithGrabDict) ?? ""
                if let deeplinkUrl = loginWithGrabAppUrl,
                   !(self?.schemeAvailable(urlScheme: validateURLScheme.isEmpty ? deeplinkUrl.absoluteString : validateURLScheme) ?? false) {
                    loginWithGrabAppUrl = nil
                }
                completion(authUrl, loginWithGrabAppUrl, nil)
            }
        }
    }

    var serviceDiscovery = Json("")

    private func getAuthenticateURL(completion: @escaping (URL?, URL?, GrabIdPartnerError?) -> Void) {
        let sv = getSecurityValues()
        sessionData.nonce = sv.nonce
        sessionData.state = sv.state
        sessionData.codeVerifier = sv.verifier
        codeChallenge = sv.codeChallenge

        var queryParams = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: codeChallengeMethod),
            URLQueryItem(name: "device_id", value: deviceId),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "redirect_uri", value: config.redirectUrl),
            URLQueryItem(name: "response_type", value: responseType),
            URLQueryItem(name: "state", value: sessionData.state),
            URLQueryItem(name: "scope", value: scope)
        ]

        if !sessionData.hint.isEmpty {
            queryParams.append(URLQueryItem(name: "login_hint", value: sessionData.hint))
        }

        if !sessionData.idTokenHint.isEmpty {
            queryParams.append(URLQueryItem(name: "id_token_hint", value: sessionData.idTokenHint))
        }

        if !sessionData.prompt.isEmpty {
            queryParams.append(URLQueryItem(name: "prompt", value: sessionData.prompt))
        }

        // handle optional parameters
        if let request = request,
           !request.isEmpty {
            queryParams.append(URLQueryItem(name: "request", value: request))
        }

        if let acrValueString = GrabSDK.getAcrValuesString(acrValues: acrValues),
           !acrValueString.isEmpty {
            queryParams.append(URLQueryItem(name: "acr_values", value: acrValueString))
        }

        if let authEndpoint = sessionData.authorizationEndpoint, !authEndpoint.isEmpty {
            getLoginUrls(queryParams: queryParams, completion: completion)
        } else {
            serviceDiscovery = Json(sessionData.serviceDiscoveryUrl)
            serviceDiscovery.get().onSuccess { [weak self] json in
                self?.endpoints = json
                self?.getLoginUrls(queryParams: queryParams, completion: completion)
            }.onFailure { error in
                completion(nil, nil, error)
            }
        }
    }

    func saveIdTokenInfo(_ idToken: IdTokenInfo) {
        guard saveTokenInfoToKeyChain(idToken), let encodedData = try? JSONEncoder().encode(idToken) else {
            return
        }
        UserDefaults.standard.set(encodedData, forKey: nonce)
    }

    func restoreIdToken(_ nounce: String) -> IdTokenInfo? {
        guard let data = UserDefaults.standard.data(forKey: nounce),
              let idTokenInfo = try? JSONDecoder().decode(IdTokenInfo.self, from: data),
              getTokenInfoFromKeyChain(idTokenInfo: idTokenInfo) else {
            return nil
        }
        return idTokenInfo
    }

    private func getTokenInfoFromKeyChain(idTokenInfo: IdTokenInfo) -> Bool {
        let keyChain = KeychainTokenItem(service: clientId)

        // read token from keychain
        guard let tokenId = keyChain.readToken(id: Key.tokenId, scope: scope),
              let partnerUserId = keyChain.readToken(id: Key.partnerUserId, scope: scope),
              tokenId != "",
              partnerUserId != "",
              idTokenInfo.tokenId == tokenId,
              idTokenInfo.partnerUserId == partnerUserId else {
            _ = removeSessionData()
            return false
        }
        return true
    }

    private func saveTokenInfoToKeyChain(_ token: IdTokenInfo) -> Bool {
        let keyChain = KeychainTokenItem(service: clientId)
        do {
            try keyChain.saveToken(id: Key.tokenId, scope: scope, token: token.tokenId ?? "")
            try keyChain.saveToken(id: Key.partnerUserId, scope: scope, token: token.partnerUserId ?? "")
            return true
        } catch {
            // delete the tokens from keychain == no caching
            _ = removeSessionData()
        }

        return false
    }
}
