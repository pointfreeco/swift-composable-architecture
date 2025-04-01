# Migrating to 1.18

Stores now automatically cancel their in-flight effects when they deallocate. And another UIKit
navigation helper has been introduced.

## An effect lifecycle change

In previous versions of the Composable Architecture, a root store's effects continued to run even
after the store's lifetime. In 1.18, this leak has been fixed, and a root store's effects will be
cancelled when the store deallocates.

If you depend on a store's fire-and-forget effect to outlive the store, for example if you want to
ensure an analytics or persistence effect proceeds without cancellation, perform this work in an
unstructured task, instead:

```diff
 return .run { _ in
-  await analytics.track(/* ... */)
+  Task {
+    await analytics.track(/* ... */)
+  }
 }
```

## A UIKit navigation helper

Our [Swift Navigation](https://github.com/pointfreeco/swift-navigation) library ships with many
UIKit tools, and the Composable Architecture integrates with many of them, but up till now it has
lacked support for trait-based navigation by pushing an element of ``StackState``.

This has been fixed with a new endpoint on the `push` trait that takes a `state` parameter:

```swift
traitCollection.push(state: Path.State.detail(/* ... */))
```
