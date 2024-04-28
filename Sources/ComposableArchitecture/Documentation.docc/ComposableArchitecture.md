# ``ComposableArchitecture``

The Composable Architecture (TCA, for short) is a library for building applications in a consistent
and understandable way, with composition, testing, and ergonomics in mind. It can be used in
SwiftUI, UIKit, and more, and on any Apple platform (iOS, macOS, tvOS, and watchOS).

## Additional Resources

- [GitHub Repo](https://github.com/pointfreeco/swift-composable-architecture)
- [Discussions](https://github.com/pointfreeco/swift-composable-architecture/discussions)
- [Point-Free Videos](https://www.pointfree.co/collections/composable-architecture)

## Overview

This library provides a few core tools that can be used to build applications of varying purpose and
complexity. It provides compelling stories that you can follow to solve many problems you encounter
day-to-day when building applications, such as:

* **State management**

    How to manage the state of your application using simple value types, and share state across
    many screens so that mutations in one screen can be immediately observed in another screen.

* **Composition**

    How to break down large features into smaller components that can be extracted to their own,
    isolated modules and be easily glued back together to form the feature.

* **Side effects**

    How to let certain parts of the application talk to the outside world in the most testable and
    understandable way possible.

* **Testing**

    How to not only test a feature built in the architecture, but also write integration tests for
    features that have been composed of many parts, and write end-to-end tests to understand how
    side effects influence your application. This allows you to make strong guarantees that your
    business logic is running in the way you expect.

* **Ergonomics**

    How to accomplish all of the above in a simple API with as few concepts and moving parts as
    possible.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:DependencyManagement>
- <doc:Testing>
- <doc:Navigation>
- <doc:SharingState>
- <doc:Performance>

### Tutorials

- <doc:MeetComposableArchitecture>

### State management

- <doc:Reducers>
- ``Effect``
- ``Store``
- <doc:SharingState>

### Testing

- ``TestStore``
- <doc:Testing>

### Integrations

- <doc:SwiftConcurrency>
- <doc:SwiftUIIntegration>
- <doc:ObservationBackport>
- <doc:UIKit>

### Migration guides

- <doc:MigrationGuides>

## See Also

The collection of videos from [Point-Free](https://www.pointfree.co) that dive deep into the
development of the library.

* [Point-Free Videos](https://www.pointfree.co/collections/composable-architecture)
