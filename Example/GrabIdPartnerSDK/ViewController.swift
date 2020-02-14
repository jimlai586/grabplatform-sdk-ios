/**
 * Copyright (c) Grab Taxi Holdings PTE LTD (GRAB)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import UIKit
import GrabIdPartnerSDK

struct Configuration {
    static let clientId = "350c848f-2580-45ba-8879-69d51d54f2d3"
    static let redirectUri = "grabweblogin://open"
    static let scope = "gid_test_scope_1 gid_test_scope_2 gid_test_scope_3 openid"
}

class ViewController: UIViewController {
    // show different mode using the SDK to create sd
    private let usesdkSDKConfigs = true

    private let noCache = false

    private var sd: SessionData {
        sdk.sessionData
    }

    @IBOutlet weak var grabSignInButton: UIButton!
    @IBOutlet weak var grabSignOutButton: UIButton!
    @IBOutlet weak var getIdTokenInfo: UIButton!
    @IBOutlet weak var testProtectedResourceButton: UIButton!
    @IBOutlet weak var messageScrollView: UIScrollView!
    @IBOutlet weak var messageLabel: UILabel!

    var sdk: GrabSDK {
        GrabSDK.shared
    }

    private func setupUI() {
        grabSignInButton.isEnabled = true
        grabSignInButton.backgroundColor = Constants.Styles.grabGreenColor

        if !sdk.accessToken.isEmpty {
            getIdTokenInfo.isEnabled = true
            getIdTokenInfo.backgroundColor = Constants.Styles.grabGreenColor
        } else {
            getIdTokenInfo.isEnabled = false
            getIdTokenInfo.backgroundColor = Constants.Styles.lightGray
        }

        if getIdTokenInfo.isEnabled {
            testProtectedResourceButton.isEnabled = true
            testProtectedResourceButton.backgroundColor = Constants.Styles.grabGreenColor
        } else {
            testProtectedResourceButton.isEnabled = false
            testProtectedResourceButton.backgroundColor = Constants.Styles.lightGray
        }
    }

    private func login() {
        logMessage(message: "Calling login API ->\r", isBold: true)
        sdk.login(presentingViewController: self) { [weak self] (error) in
            if let error = error {
                self?.logMessage(message: error.localizedMessage ?? "Grab SignIn failed!!!")
            } else {
                self?.loginHander()
            }
            self?.setupUI()
        }
    }

    private func loginHander() {
        if !sdk.accessToken.isEmpty {
            logMessage(message: "Obtained sd from cache")
            printsd()
        }
    }

    private func signInWithLoginConfig() {
        login()
    }

    private func signIn() {
        let url = URL(string: Configuration.redirectUri)
        if url != nil {
            login()
        }
    }

    @IBAction func didGrabSignIn(_ sender: Any) {
        if usesdkSDKConfigs {
            // sign in using configurations in plist.
            signInWithLoginConfig()
        } else {
            signIn()
        }
    }

    @IBAction func didGrabSignOut(_ sender: Any) {
        sdk.logout() { [weak self] (error) in
            if let error = error {
                self?.logMessage(message: "logout failed - error \(error.localizedMessage ?? "unknown")")
            } else {
                self?.clearLogMessage()
            }
        }
        setupUI()
    }

    @IBAction func didGetIdTokenInfo(_ sender: Any) {
        sdk.loadIdTokenInfo() { [weak self] (idTokenInfo, error) in

            if let error = error {
                self?.logMessage(message: error.localizedMessage ?? "Failed to retreive idToken Info!!!")
            } else if let idTokenInfo = idTokenInfo {
                self?.logMessage(message: "Grab Verify idToken success:")
                self?.printIdTokenInfo(idTokenInfo: idTokenInfo)
            } else {
                self?.logMessage(message: "Failed to retreive idToken Info!!!")
            }
        }
    }

    @IBAction func didAccessTestRes(_ sender: Any) {
        logMessage(message: "Testing access to protect resource -->")

        if Constants.ProtectedResource.testResourceUri.isEmpty {
            if let infoPlist = Bundle.main.infoDictionary,
               let config = infoPlist["sdkSDK"] as? Dictionary<String, AnyObject> {
                Constants.ProtectedResource.testResourceUri = config["TestProtectedResourceUrl"] as? String ?? ""
            }
        }

        guard let url = createUrl(baseUrl: Constants.ProtectedResource.testResourceUri) else {
            logMessage(message: "Invalid URL \(Constants.ProtectedResource.testResourceUri) provided to fetchProtectedResource")
            return
        }

        // make sure the token has not expired
        guard sdk.isValidAccessToken else {
            // TODO
            // call login to refresh the token
            logMessage(message: "Invalid URL provided to fetchProtectedResource")
            return
        }
        let accessToken = sdk.accessToken
        fetchProtectedResource(url: url, accessToken: accessToken) { [weak self] (results, error) in
            guard let results = results else {
                self?.logMessage(message: "Unexpected results from service \(Constants.ProtectedResource.testResourceUri)")
                return
            }

            if let error = error {
                // Retry failed request - if error is auth related, it should call login and retry
                if error.code == .authorizationFailed {


                } else {
                    self?.logMessage(message: error.localizedMessage ?? "Service \(Constants.ProtectedResource.testResourceUri) failed!!!")
                    self?.logMessage(message: "Retrying fetchProtectedResource on error")

                    self?.retryfetchProtectedResource(url: url)
                }

                return
            }

            self?.onFetchProtectedResourceSuccess(results: results)
        }
    }

    private func retryfetchProtectedResource(url: URL) {
        self.fetchProtectedResource(url: url, accessToken: sdk.accessToken) { [weak self] (results, error) in
            if let error = error {
                self?.logMessage(message: "Retry failed with error: \(error.localizedMessage ?? Loc.somethingWentWrong)")
                return
            }

            self?.onFetchProtectedResourceSuccess(results: results)
        }
    }

    private func onFetchProtectedResourceSuccess(results: [String: Any]?) {
        guard let results = results else {
            return
        }
        logMessage(message: "Access \(Constants.ProtectedResource.testResourceUri) success:")

        logMessage(message: "Results:")
        guard let authMethod = results["authMethod"] else {
            logMessage(message: "failed to get authMethod")
            return
        }
        logMessage(message: "authMethod: \(authMethod)")

        guard let serviceID = results["serviceID"] else {
            logMessage(message: "failed to get serviceID")
            return
        }
        logMessage(message: "serviceID: \(serviceID)")

        guard let userID = results["userID"] else {
            logMessage(message: "failed to get userID")
            return
        }
        logMessage(message: "userId: \(userID)")

        guard let serviceUserID = results["serviceUserID"] else {
            logMessage(message: "failed to get serviceUserID")
            return
        }
        logMessage(message: "serviceUserID: \(serviceUserID)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        messageLabel.bounds.size.width = messageScrollView.bounds.width
        messageScrollView.contentSize.width = messageScrollView.bounds.width

        logMessage(message: "Starting sdkSDK Example:\r")

        messageScrollView.contentSize.height = messageLabel.bounds.size.height
        messageScrollView.setNeedsLayout()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func exchangeToken(url: URL) {
        logMessage(message: "\rCalling exchangeToken API ->\r", isBold: true)
        logMessage(message: "Redirect Url:")
        logMessage(message: "\(url.absoluteString)")
        sdk.exchangeToken(url: url) { (error) in
            DispatchQueue.main.async { [weak self] in
                if let error = error {
                    self?.logMessage(message: error.localizedMessage ?? "exchangeToken failed!!!")
                } else {
                    self?.printsd()
                }
                _ = self?.sdk.loginCompleted() {
                    self?.logMessage(message: error?.localizedMessage ?? "loginCompleted!!!")
                }

                self?.setupUI()
            }
        }
    }

    func logMessage(message: String, isBold: Bool = false, isItalic: Bool = false) {
        var font: [NSAttributedString.Key: Any]?
        if isBold {
            font = [.font: UIFont.boldSystemFont(ofSize: 12.0)]
        } else if isItalic {
            font = [.font: UIFont.italicSystemFont(ofSize: 12.0)]
        } else {
            font = [.font: UIFont.systemFont(ofSize: 12.0)]
        }

        let attributedString = NSMutableAttributedString(string: "\(message)\r", attributes: font)
        var logMessage: NSMutableAttributedString?
        if let labelAttributedText = messageLabel.attributedText {
            logMessage = NSMutableAttributedString(attributedString: labelAttributedText)
            logMessage?.append(attributedString)
        }
        if let logMessage = logMessage {
            messageLabel.attributedText = logMessage
        }
        messageLabel.sizeToFit()

        if messageLabel.bounds.size.height > messageScrollView.bounds.size.height {
            let bottomOffset = CGPoint(x: 0, y: messageLabel.bounds.size.height - messageScrollView.bounds.size.height)
            messageScrollView.setContentOffset(bottomOffset, animated: true)
        }
    }

    func createUrl(baseUrl: String, params: [NSURLQueryItem]? = nil) -> URL? {
        let urlComponents = NSURLComponents(string: baseUrl)

        if let paramsValues = params {
            urlComponents?.queryItems = paramsValues as [URLQueryItem]
        }

        return urlComponents?.url
    }

    // this method is to demonstrate calling Grab API with the access token. it is not part of the Grab Id Partner SDK.
    private func fetchProtectedResource(url: URL, accessToken: String = "", completion: @escaping ([String: Any]?, GrabIdPartnerError?) -> Void) {
        guard !url.absoluteString.isEmpty else {
            let error = GrabIdPartnerError(code: .somethingWentWrong,
                    localizedMessage: "invalid url",
                    domain: .protectedResource,
                    serviceError: nil)
            completion(nil, error)
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("BEARER \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.httpMethod = "GET"
        // urlRequest.timeoutInterval = ???
        let session = URLSession.shared
        let task = session.dataTask(with: urlRequest) { (data, response, error) in
            var results: [String: Any]? = nil
            var gradIdPartnerError: GrabIdPartnerError? = nil
            if let error = error {
                gradIdPartnerError = GrabIdPartnerError(code: .serviceError,
                        localizedMessage: Constants.Localize.testResServiceFailed,
                        domain: .protectedResource,
                        serviceError: error)
            } else {
                if let response = response as? HTTPURLResponse,
                   !(200...299 ~= response.statusCode) {
                    let error = GrabIdPartnerError(code: .idTokenInfoServiceFailed,
                            localizedMessage: "\(response.statusCode)",
                            domain: .protectedResource,
                            serviceError: nil)
                    completion(nil, error)
                    return
                }

                guard let data = data else {
                    let error = GrabIdPartnerError(code: .somethingWentWrong,
                            localizedMessage: "Response did not return valid JSON",
                            domain: .protectedResource,
                            serviceError: error)
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let authMethod = json["authMethod"],
                       let serviceID = json["serviceID"],
                       let userID = json["userID"],
                       let serviceUserID = json["serviceUserID"] {
                        results = ["authMethod": authMethod,
                                   "serviceID": serviceID,
                                   "userID": userID,
                                   "serviceUserID": serviceUserID]
                    } else {
                        gradIdPartnerError = GrabIdPartnerError(code: .serviceError,
                                localizedMessage: Constants.Localize.invalidServiceResponse,
                                domain: .protectedResource,
                                serviceError: error)
                    }
                } catch let parseError {
                    gradIdPartnerError = GrabIdPartnerError(code: .serviceError,
                            localizedMessage: parseError.localizedDescription,
                            domain: .protectedResource,
                            serviceError: parseError)
                }

                // Dispatch the result to the UI thread. logMessage and setupUI must be called from UI thread.
                DispatchQueue.main.async {
                    completion(results, gradIdPartnerError)
                }
            }
        }
        task.resume()
    }

    func printsd() {
        logMessage(message: "accessToken:")
        logMessage(message: "\(sdk.accessToken)\r", isItalic: true)
        if let tokenExpiresAt = sd.accessTokenExpiresAt {
            logMessage(message: "accessTokenExpiresAt:")
            logMessage(message: "\(tokenExpiresAt)\r", isItalic: true)
        }

        logMessage(message: "refreshToken:")
        logMessage(message: "\(sdk.refreshToken)", isItalic: true)

        logMessage(message: "idToken:")
        logMessage(message: "\(sdk.idToken)\r", isItalic: true)

        if let code = sd.code {
            logMessage(message: "code:")
            logMessage(message: "\(code)\r", isItalic: true)
        }

        if let state = sd.state {
            logMessage(message: "state:")
            logMessage(message: "\(state)\r", isItalic: true)
        }

        if let codeVerifier = sd.codeVerifier {
            logMessage(message: "code verifier:")
            logMessage(message: "\(codeVerifier)\r", isItalic: true)
        }

        if let nonce = sd.nonce {
            logMessage(message: "nonce:")
            logMessage(message: "\(nonce)\r", isItalic: true)
        }

        if let tokenType = sd.tokenType {
            logMessage(message: "tokenType:")
            logMessage(message: "\(tokenType)\r", isItalic: true)
        }
    }

    private func printIdTokenInfo(idTokenInfo: IdTokenInfo) {
        logMessage(message: "Id Token Info:")

        if let audience = idTokenInfo.audience {
            logMessage(message: "audience:")
            logMessage(message: "\(audience)\r", isItalic: true)
        }

        if let service = idTokenInfo.service {
            logMessage(message: "service:")
            logMessage(message: "\(service)\r", isItalic: true)
        }

        if let validDate = idTokenInfo.notValidBefore {
            logMessage(message: "validDate:")
            logMessage(message: "\(validDate)\r", isItalic: true)
        }

        if let expiration = idTokenInfo.expiration {
            logMessage(message: "expiration:")
            logMessage(message: "\(expiration)\r", isItalic: true)
        }

        if let issueDate = idTokenInfo.issueDate {
            logMessage(message: "issueDate:")
            logMessage(message: "\(issueDate)\r", isItalic: true)
        }

        if let issuer = idTokenInfo.issuer {
            logMessage(message: "issuer:")
            logMessage(message: "\(issuer)\r", isItalic: true)
        }

        if let tokenId = idTokenInfo.tokenId {
            logMessage(message: "tokenId:")
            logMessage(message: "\(tokenId)\r", isItalic: true)
        }

        if let partnerId = idTokenInfo.partnerId {
            logMessage(message: "partnerId:")
            logMessage(message: "\(partnerId)\r", isItalic: true)
        }

        if let partnerUserId = idTokenInfo.partnerUserId {
            logMessage(message: "partnerUserId:")
            logMessage(message: "\(partnerUserId)\r", isItalic: true)
        }

        if let nonce = idTokenInfo.nonce {
            logMessage(message: "nonce:")
            logMessage(message: "\(nonce)\r", isItalic: true)
        }
    }

    private func clearLogMessage() {
        messageLabel.text = ""
        messageLabel.sizeToFit()
    }

    private struct Constants {
        struct Configuration {
            static let logMessageCharacterLimit = 10000
            static let logMessageCharacterPurge = 7000
        }

        struct ProtectedResource {
            static var testResourceUri: String = ""  // Initialize this with the test endpoint
        }

        struct Styles {
            static let grabGreenColor = UIColor(red: 0.00, green: 0.69, blue: 0.25, alpha: 1.0)
            static let lightGray = UIColor.lightGray
        }

        struct Localize {
            // TODO: Add app specific strings to Localizable.strings files.
            // Following are sample errors. App should define their own error messages.
            static let testResServiceFailed = "Test res service failed!"
            static let invalidServiceResponse = "Test res service returned invalid response"
        }
    }
}

