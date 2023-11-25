# Observation backport

Learn how the Observation framework from Swift 5.9 was backported to support iOS 16 and earlier, 
as well as the caveats of using the backported tools.

## Overview

With version 1.6<!--TODO:Update version--> of the Composable Architecture we have introduced 
support for Swift 5.9's observation tools, _and_ we have backported those tools to work in iOS 13
and later. Using the observation tools in pre-iOS 17 does require a few additional steps and there
are some gotchas to be aware of.

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

## Gotchas


### Lazy view closures
