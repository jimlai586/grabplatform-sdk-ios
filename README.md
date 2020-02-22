# SDK rewrite

Use this SDK as an example to showcase how I review and develop a library.

## Swift 5

First and foremost, a Swift library should always push to support latest Swift. 

There's 0 reason to release a library that supports Swift 3 in 2020, when Xcode no long supports Swift 3.

If your Swift app requires an older version of Xcode to maintain, you are doing it wrong.

If you want a library that can be used forever without updating, use Objective-C.

When you have ABI-stable version, you take it.

Use Codable to replace NSCoding. Remove all NSObject inheritances and @Objc.

## Singleton re-design

```swift
  @objc static public func sharedInstance() -> GrabIdPartnerProtocol? {
    objc_sync_enter(GrabIdPartner.grabIdPartnerSdkLock)
    defer { objc_sync_exit(GrabIdPartner.grabIdPartnerSdkLock) }
    
    if grabIdPartner != nil {
      return grabIdPartner
    } else {
      grabIdPartner = GrabIdPartner()
      return grabIdPartner
    }
  }
 ```
Singleton being optional forces developer to handle nil even before calling your library to do anything. 

It injects optional unwrap codes wherever it is accessed. 

Whatever your problem may be during initialization, deal with it. A nil singleton is useless. 

Lazy initialization of a static property is thread-safe, shouldn't need objc_sync_enter. 

iOS SDK uses shorthand 'shared' for singleton.

Returning GrabIdPartnerProtocol serves no purpose. That protocol serves no purpose. 

It's not like you would swap singleton in runtime for a different protocol instance.

If you would, you are making things complicated for no apparent reason.

Overall it's very Objective-C style design.

## Simplify LoginSession

```swift
  @objc public func loadLoginSession(completion: @escaping(LoginSession?, GrabIdPartnerError?) -> Void)
 ```
There's no strong reason to pass LoginSession around. There's no strong reason for completion handler.

No networking operation as far as I can tell.

Instead of passing LoginSession to every method in GrabIdPartner, just use it as a model type property in GrabIdPartner. 

Simplify all intermediate error handling. The trick is not checking every step of the way, the trick is checking some important steps so 

you don't need to check remaining steps.

LoadLoginSession and CreateLoginSession are boilerplate. 

Take a look at its design:

```swift
      (loginSession, error) = createLoginSession(clientId: clientId, redirectUrl: redirectUrl, scope: scope, request: request,
                                                   acrValues: acrValues, serviceDiscoveryUrl: serviceDiscoveryUrl,
                                                   hint: hint, idTokenHint: idTokenHint, prompt: prompt)
  //...
  public func createLoginSession(clientId: String?, redirectUrl: String?, scope: String?,
                                  request: String? = nil, acrValues: [String:String]? = nil, serviceDiscoveryUrl: String?,
                                  hint: String = "", idTokenHint: String = "", prompt:String = "") -> (LoginSession?, GrabIdPartnerError?) {
    if let appClientId = clientId, !appClientId.isEmpty,
       let appScope = scope, !appScope.isEmpty,
       let appRedirectUrl = redirectUrl,
       let appUrl = URL(string: appRedirectUrl),
       let serviceDiscoveryUrl = serviceDiscoveryUrl {
      var loginSession: LoginSession? = nil
      loginSession = LoginSession(clientId: appClientId,
                                  redirectUrl: appUrl,
                                  scope: appScope,
                                  request: request,
                                  acrValues: acrValues,
                                  serviceDiscoveryUrl: serviceDiscoveryUrl,
                                  hint: hint,
                                  idTokenHint: idTokenHint,
                                  prompt: prompt)
      return (loginSession, nil)
    } //... 
```
And the LoginSession init itself
```swift
  @objc public init(clientId : String, redirectUrl : URL, scope: String, request: String? = nil, acrValues: [String:String]? = nil,
                    serviceDiscoveryUrl: String, hint: String = "", idTokenHint: String = "", prompt:String = "") {
    self.clientId = clientId
    self.redirectUrl = redirectUrl
    self.scope = scope
    self.serviceDiscoveryUrl = serviceDiscoveryUrl
    self.request = request
    self.acrValues = acrValues
    self.hint = hint
    self.idTokenHint = idTokenHint
    self.prompt = prompt
    
    super.init()
  }
```

That is a lot of boilerplate to create an instance.

You can just create an instance and pass that instance around. Or better yet, create the instance in init as part of the model properties, since SDK couldn't work without it. I showcased this in this fork.

Most of the GrabIdPartner methods take a LoginSession instance as argument. This requires developer to maintain a LoginSession object and pass it around. From the looks of it LoginSession should be a one-off config, i.e.; you config once. You are also assuming developer won't mutate it somewhere and cause inconsistent session states.

Simplify LoginSession by replacing it with a simple Config value type that conforms to Codable. SDk simply creates a copy as default value. Can be made to be configurable later.

## Simplify IdTokenInfo

Use it as a model type property in GrabIdPartner.

Try using default value to avoid optional. The trick is to unwrap key properties, not every property.

## Simplify networking

One should at least refactor URLRequest setup and dataTask completion, e.g.; basic error and http response code checks.

I'd avoid using encoded url in POST requests.

A JSON library would also be handy. E.g.; 

```swift
public indirect enum JSON {
    case arr([Any]), dict([String: Any]), json(JSON), raw(Any), null
}
```
I'd also recommend a resource-based approach:

```swift
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
```
Observe that requests, and callbacks are refactored out in protocol extension which can be customized for different types of resources.

A GET would look like this `api.resource.get().onSuccess { json in ...}.onFailure { error in ...}`

Protocol oriented, highly refactored, with self-contained simple libraries (total < 300 lines). 

## Other refactors and improvements 

There's a lack of computed properties and value types.

There are quite a lot of code duplications.

There are a lot of parameters passing around. 

It can all be refacored and improved.

## Propety wrapper and Rx

Showcase an usage of @Rx property wrapper as a simple observer. 

It is on branch Rx. It takes like 30 lines of library.

It is to show how bloatware RxSwift is. Most of the features RxSwift provided are rarely used or have far simpler alternatives.

I haven't even used Combine.




