/**
 * Copyright (c) Grab Taxi Holdings PTE LTD (GRAB)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import XCTest
import GrabIdPartnerSDK
import SafariServices

typealias J = JsonKey
enum JsonKey: String {
    typealias RawValue = String
    case test, nested
}

class GrabIdPartnerSDKTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // do setup
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }


    func testJSON() {
        var j = JSON([J.test: [J.nested: 100]])
        print(j[J.test])
        assert(j[J.test][J.nested].stringValue == "100")
    }


}

