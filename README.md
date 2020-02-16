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

LoadLoginSession and CreateLoginSession are boilerplate. You just load some values from plist, do it fast OK?

## Simplify IdTokenInfo

Use it as a model type property in GrabIdPartner.

Try using default value to avoid optional. The trick is to unwrap key properties, not every property.

## Simplify networking

You can at least refactor URLRequest setup and dataTask completion, e.g.; basic error and http response code checks.

Talk to your backend team to for POST with JSON instead of encoded URL. 

Dude, it's 2020, and you are spending a good chunk of your code assembling parameters to URL. 

A JSON library would also be handy. Everything is JSON in 2020.

## Other refactors and improvements 

There's a lack of computed properties and value types.

There are quite a lot of code duplications.

There are a lot of parameters passing around and initialization. 

It can all be refacored and improved.

## Propety wrapper and Rx

Showcase an usage of @Rx property wrapper as a simple observer. 

It is on branch Rx. It takes like 30 lines of library.

It is to show how bloatware RxSwift is. Most of the features RxSwift provided are rarely used or have far simpler alternatives.

I haven't even used Combine.




