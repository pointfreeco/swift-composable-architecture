# Migrating to 1.6

Update your code to make use of the new ``TestStore/receive(_:_:timeout:assert:file:line:)-dkei`` 
method when you need to assert on the payload inside an action received.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

### Asserting on action payloads

In version 1.4 of the library we provided a new a new assertion method on ``TestStore`` for 
asserting on actions received without asserting on the payload in the action (see
<doc:MigratingTo1.4#Receiving-test-store-actions> for more information). However, sometimes it is
important to assert on the payload, especially when testing delegate actions from child features,
and so that is why 1.6 introduces ``TestStore/receive(_:_:timeout:assert:file:line:)-dkei``.

If you have code like the following for asserting that an action features sends a delegate action
with a specific payload:

```swift
await store.receive(.child(.delegate(.response(true))))
```

You can now update that code to the following:

```swift
await store.receive(\.child.delegate.response, true)
```
