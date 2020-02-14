/**
 * Copyright (c) Grab Taxi Holdings PTE LTD (GRAB)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import Foundation

public struct IdTokenInfo: Codable {
    public var audience: String? = nil       // audience
    public var service: String? = nil        // service
    public var notValidBefore: Date? = nil   // token valid start date
    public var expiration: Date? = nil       // expiration
    public var issueDate: Date? = nil        // issue date
    public var issuer: String? = nil         // issuer
    public var tokenId: String? = nil        // idToken
    public var partnerId: String? = nil      // partner Id
    public var partnerUserId: String? = nil  // partner user Id
    public var nonce: String? = nil          // nonce

}

