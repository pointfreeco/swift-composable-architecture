# Migrating to 1.16

The `.appStorage` strategy used with `@Shared` now uses key-value observing instead of 
`NotificationCenter` when possible. Learn how this may affect your code.

## Overview

There are no steps needed to migrate to 1.16 of the Composable Architecture, but there has been
a change to the underlying behavior of `.appStorage` that one should be aware of. When using
`.appStorage` with `@Shared`, if your key does not contain the characters "." or "@", then changes 
to that key in `UserDefaults` will be observed using key-value observing (KVO). 
Otherwise, `NotificationCenter` will be used to observe changes.

KVO is a far more efficient way of observing changes to `UserDefaults` and it works cross-process,
such as from widgets and app extensions. However, KVO does not work when the keys contain "."
or "@", and so in those cases we must use the cruder tool of `NotificationCenter`. That is not
as efficient, and it forces us to perform a thread-hop when the notification is posted before
we can update the `@Shared` value. For this reason it is not possible to animate changes that are
made directly to `UserDefaults`:

```swift
withAnimation {
  // ⚠️ This will not animate any SwiftUI views using '@Shared(.appStorage("co.pointfree.count"))'
  UserDefaults.standard.set(0, forKey: "co.pointfree.count")
}
```

In general, we recommend using other delimeters for your keys, such as "/", ":", "-", etc.:

```swift
@Shared(.appStorage("co:pointfree:count")) var count = 0
```
