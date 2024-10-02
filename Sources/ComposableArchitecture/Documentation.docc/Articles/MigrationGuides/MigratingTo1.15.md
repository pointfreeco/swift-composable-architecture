# Migrating to 1.15

The library has been completely updated for Swift 6 language mode, and now compiles in strict
concurrency with no warnings or errors.

## Overview

The library is now 100% Swift 6 compatible, and has been done in a way that is full backwards
compatible. If your project does not have strict concurrency warnings turned on, then updating
the Composable Architecture to 1.15.0 should not cause any compilation errors. However, if you have
strict concurrency turned on, then you may come across a few situations you need to update.

### Enum cases as function references

It is common to use the case of enum as a function, such as mapping on an ``Effect`` to bundle 
its output into an action:

```swift
return client.fetch()
  .map(Action.response)
```

In strict concurrency mode this may fail with a message like this:

> 🛑 Converting non-sendable function value to '@Sendable (Value) -> Action' may introduce data races

There are two ways to fix this. You can either open the closure explicitly instead of using 
`Action.response` as a function:

```swift
return client.fetch()
  .map { .response($0) }
```

There is also an upcoming Swift feature that will fix this. You can enable it in an SPM package
by adding a `enableUpcomingFeature` to its Swift settings:

```swift
swiftSettings: [
  .enableUpcomingFeature("InferSendableFromCaptures"),
]),
```

And you can [enable this feature in Xcode](https://www.swift.org/blog/using-upcoming-feature-flags/)
by navigating to your project's build settings in Xcode, and adding a new "Other Swift Flags" flag:

```
-enable-upcoming-feature InferSendableFromCaptures
```
