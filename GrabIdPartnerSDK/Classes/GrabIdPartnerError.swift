/**
 * Copyright (c) Grab Taxi Holdings PTE LTD (GRAB)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import Foundation

public enum GrabIdPartnerErrorDomain: Int {
    case serviceDiscovery
    case loadConfiguration
    case authorization
    case exchangeToken
    case getIdTokenInfo
    case logout
    case protectedResource
    case customProtocolsService
}

public enum GrabIdPartnerErrorCode: Int {
    case grabIdServiceFailed
    case discoveryServiceFailed
    case idTokenInfoServiceFailed
    case exchangeTokenServiceFailed
    case authorizationInitializationFailure
    case securityValidationFailed
    case logoutFailed
    case invalidIdToken                 // The id token is invalid.
    case invalidNonce
    case invalidConfiguration           // Missing GrabIdPartnerSDK in plist/manifest
    case somethingWentWrong             // This error is unexpected or cannot be exposed.
    case network                        // There is an issue with network connectivity.
    case invalidClientId                // Invalid client id
    case invalidScope                   // Invalid scope
    case invalidRedirectUrl             // Invalid redirect url
    case invalidAuthorizationCode       // Invalid authorization code
    case invalidUrl                     // The authorize end point is invalid
    case invalidPartnerId               // Partner id is not set in AndroidManifest.
    case unAuthorized                   // Partner application is unauthorized.
    case authorizationFailed            // Authorization failed
    case serviceUnavailable             // The service was not available.
    case serviceError                   // The GrabId service is returning an error.
    case invalidAccessToken             // The access token is invalid.
    case invalidResponse                // Unexpected response from GrabId service
    case invalidServiceDiscoveryUrl     // Invalid service discovery url
    case invalidAppBundle               // Missing bundle
    case invalidCustomProtocolUrl       // Invalid custom protocol url to get the Grab app deeplinks.

    case partnerAppError = 10000               // app defined errors are 10000 and above
    // more to come ...
}

public struct GrabIdPartnerError: Error {
    public let code: GrabIdPartnerErrorCode
    public let localizedMessage: String?
    public let domain: GrabIdPartnerErrorDomain
    public let serviceError: Error?            // network or service error

    public init(code: GrabIdPartnerErrorCode, localizedMessage: String?, domain: GrabIdPartnerErrorDomain, serviceError: Error?) {
        self.code = code
        self.localizedMessage = localizedMessage
        self.domain = domain
        self.serviceError = serviceError
    }
}

public typealias Loc = Localization

public struct Localization {
    public static let invalidUrl = "Invalid Url."
    public static let securityValidationFailed = "Security validation failed."
    public static let invalidResponse = "Invalid response from GrabId Partner service."
    public static let authorizationInitializationFailure = "Authorization initialization failed."
    public static let logoutFailed = "Logout failed."
    public static let somethingWentWrong = "Unknown."
    public static let invalidIdToken = "Invalid idToken."
    public static let invalidNonce = "Invalid Nonce."
    public static let invalidConfiguration = "Configuration error."
    public static let invalidClientId = "Invalid client id."
    public static let invalidScope = "Invalid scope."
    public static let invalidRedirectUrl = "Invalid redirect url."
    public static let serviceError = "GrabId service error."
    public static let invalidAppBundle = "App bundle is invalid"
    public static let invalidCustomProtocolUrl = "Invalid custom protocol url"
}
