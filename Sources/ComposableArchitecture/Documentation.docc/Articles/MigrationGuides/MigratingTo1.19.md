# Migrating to 1.19

Store internals have been rewritten for performance and future features, and are now compatible with
SwiftUI's `@StateObject` property wrapper.

## Overview

There are no steps needed to migrate to 1.19 of the Composable Architecture, but there are a number
of changes and improvements that have been made to the `Store` that one should be aware of.

## Store internals rewrite

The store's internals have been rewritten to improved performance and to pave the way for future
features. While this should not be a breaking change, with any rewrite it is important to thoroughly
test your application after upgrading.

## StateObject compatibility

SwiftUI's `@State` and `@StateObject` allow a view to own a value or object over time, ensuring that
when a parent view is recomputed, the view-local state isn't recreated from scratch.

One important difference between `@State` and `@StateObject` is that `@State`'s initializer is
eager, while `@StateObject`'s is lazy. Because of this, if you initialize a root `Store` to be held
in `@State`, stores will be initialized (and immediately discarded) whenever the parent view's body
is computed.

To avoid the creation of these stores, one can now assign the store to a `@StateObject`, instead:

```swift
struct FeatureView: View {
  @StateObject var store: StoreOf<Feature>

  init() {
    _store = StateObject(
      // This expression is only evaluated the first time the parent view is computed.
      wrappedValue: Store(initialState: Feature.State()) {
        Feature()
      }
    )
  }

  var body: some View { /* ... */ }
}
```

> Important: The store's `ObservableObject` conformance does not have any impact on the actual
> observability of the store. You should continue to rely on the ``ObservableState()`` macro for
> observation.
