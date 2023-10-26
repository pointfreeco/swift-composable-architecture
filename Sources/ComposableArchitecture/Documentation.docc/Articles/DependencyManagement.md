# Dependencies

Learn how to register dependencies with the library so that they can be immediately accessible from
any reducer.

## Overview

Dependencies in an application are the types and functions that need to interact with outside 
systems that you do not control. Classic examples of this are API clients that make network requests
to servers, but also seemingly innocuous things such as `UUID` and `Date` initializers, and even
clocks, can be thought of as dependencies.

By controlling the dependencies our features need to do their job we gain the ability to completely
alter the execution context a feature runs in. This means in tests and Xcode previews you can 
provide a mock version of an API client that immediately returns some stubbed data rather than 
making a live network request to a server.

> Note: The dependency management system in the Composable Architecture is driven off of our 
> [Dependencies][swift-dependencies-gh] library. That repository has extensive 
> [documentation][swift-deps-docs] and articles, and we highly recommend you familiarize yourself
> with all of that content to best leverage dependencies.

## Overriding dependencies

It is possible to change the dependencies for just one particular reducer inside a larger composed
reducer. This can be handy when running a feature in a more controlled environment where it may not 
be appropriate to communicate with the outside world.

For example, suppose you want to teach users how to use your feature through an onboarding
experience. In such an experience it may not be appropriate for the user's actions to cause
data to be written to disk, or user defaults to be written, or any number of things. It would be
better to use mock versions of those dependencies so that the user can interact with your feature
in a fully controlled environment.

To do this you can use the ``Reducer/dependency(_:_:)`` method to override a reducer's
dependency with another value:

```swift
@Reducer
struct Onboarding {
  var body: some Reducer<State, Action> {
    Reduce { state, action in 
      // Additional onboarding logic
    }
    Feature()
      .dependency(\.userDefaults, .mock)
      .dependency(\.database, .mock)
  }
}
```

This will cause the `Feature` reducer to use a mock user defaults and database dependency, as well
as any reducer `Feature` uses under the hood, _and_ any effects produced by `Feature`.

[swift-identified-collections]: https://github.com/pointfreeco/swift-identified-collections
[environment-values-docs]: https://developer.apple.com/documentation/swiftui/environmentvalues
[xctest-dynamic-overlay-gh]: http://github.com/pointfreeco/xctest-dynamic-overlay
[swift-dependencies-gh]: http://github.com/pointfreeco/swift-dependencies
[swift-deps-docs]: https://pointfreeco.github.io/swift-dependencies/main/documentation/dependencies/
