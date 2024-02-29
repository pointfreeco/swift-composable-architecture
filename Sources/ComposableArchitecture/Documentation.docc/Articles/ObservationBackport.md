# Observation backport

Learn how the Observation framework from Swift 5.9 was backported to support iOS 16 and earlier,
as well as the caveats of using the backported tools.

## Overview

With version 1.7 of the Composable Architecture we have introduced support for Swift 5.9's
observation tools, _and_ we have backported those tools to work in iOS 13 and later. Using the
observation tools in pre-iOS 17 does require a few additional steps and there are some gotchas to be
aware of.

## The Perception framework

The Composable Architecture comes with a framework known as Perception, which is our backport of
Swift 5.9's Observation to iOS 13, macOS 12, tvOS 13 and watchOS 6. For all of the tools in the
Observation framework there is a corresponding tool in Perception.

For example, instead of the `@Observable` macro, there is the `@Perceptible` macro:

```swift
@Perceptible
class CounterModel {
  var count = 0
}
```

However, in order for a view to properly observe changes to a "perceptible" model, you must
remember to wrap the contents of your view in the `WithPerceptionTracking` view:

```swift
struct CounterView: View {
  let model = CounterModel()

  var body: some View {
    WithPerceptionTracking {
      Form {
        Text(self.model.count.description)
        Button("Decrement") { self.model.count -= 1 }
        Button("Increment") { self.model.count += 1 }
      }
    }
  }
}
```

This will make sure that the view subscribes to any fields accessed in the `@Perceptible` model so
that changes to those fields invalidate the view and cause it to re-render.

If a field of a `@Percetible` model is accessed in a view while _not_ inside
`WithPerceptionTracking`, then a runtime warning will be triggered:

> 🟣 Runtime Warning: Perceptible state was accessed but is not being tracked. Track changes to
> state by wrapping your view in a 'WithPerceptionTracking' view.

To debug this, expand the warning in the Issue Navigator of Xcode (⌘5), and click through the stack
frames displayed to find the line in your view where you are accessing state without being inside
`WithPerceptionTracking`.

## Bindings

If you want to derive bindings from the store (see <doc:Bindings> for more information), then you
would typically use the `@Bindable` property wrapper that comes with SwiftUI:

```swift
struct MyView: View {
  @Bindable var store: StoreOf<MyFeature>
  // ...
}
```

However, `@Bindable` is iOS 17+. So, the Perception library comes with a tool that can be used in
its place until you can target iOS 17 and later. You just have to qualify `@Bindable` with the
`Perception` namespace:

```swift
struct MyView: View {
  @Perception.Bindable var store: StoreOf<MyFeature>
  // ...
}
```

## Gotchas

There are a few gotchas to be aware of when using `WithPerceptionTracking`.

### Lazy view closures

There are many "lazy" closures in SwiftUI that evaluate only when something happens in the view, and
not necessarily in the same stack frames as the `body` of the view. For example, the trailing
closure of `ForEach` is called _after_ the `body` of the view has been computed.

This means that even if you wrap the body of the view in `WithPerceptionTracking`:

```swift
WithPerceptionTracking {
  ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.id) { store in
    Text(store.title)
  }
}
```

…the access to the row's `store.title` happens _outside_ `WithPerceptionTracking`, and hence will
not work and will trigger a runtime warning as described above.

The fix for this is to wrap the content of the trailing closure in another `WithPerceptionTracking`:

```swift
WithPerceptionTracking {
  ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.id) { store in
    WithPerceptionTracking {
      Text(store.title)
    }
  }
}
```

### Mixing legacy and modern features together

Some problems can arise when mixing together features built in the "legacy" style, using
``ViewStore`` and ``WithViewStore``, and features built in the "modern" style, using the
``ObservableState()`` macro. The problems mostly manifest themselves as re-computing view bodies
more often than necessary, but that can also put strain on SwiftUI's ability to figure out what
state changed, and can cause glitches or exacerbate navigation bugs.

See <doc:MigratingTo1.7#Incrementally-migrating> for more information about this.
