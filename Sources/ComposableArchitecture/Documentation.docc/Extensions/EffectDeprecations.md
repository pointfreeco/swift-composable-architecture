# Deprecations

Review unsupported effect APIs and their replacements.

## Overview

Avoid using deprecated APIs in your app. Select a method to see the replacement that you should use instead.

## Topics

### Creating an Effect

- ``Effect/task(priority:operation:)``

### Cancellation

- ``Effect/cancel(ids:)-9tnmm``

### Composition

- ``Effect/concatenate(_:)-3awnj``
- ``Effect/concatenate(_:)-8x6rz``

### Testing

- ``Effect/failing(_:)``
- ``Effect/unimplemented(_:)``

### Combine Integration

- ``Effect/Output``
- ``Effect/init(_:)``
- ``Effect/init(value:)``
- ``Effect/init(error:)``
- ``Effect/upstream``
- ``Effect/catching(_:)``
- ``Effect/debounce(id:for:scheduler:options:)-8x633``
- ``Effect/debounce(id:for:scheduler:options:)-76yye``
- ``Effect/deferred(for:scheduler:options:)``
- ``Effect/fireAndForget(_:)``
- ``Effect/future(_:)``
- ``Effect/receive(subscriber:)``
- ``Effect/result(_:)``
- ``Effect/run(_:)``
- ``Effect/throttle(id:for:scheduler:latest:)-9kwd5``
- ``Effect/throttle(id:for:scheduler:latest:)-5jfpx``
- ``Effect/timer(id:every:tolerance:on:options:)-4exe6``
- ``Effect/timer(id:every:tolerance:on:options:)-7po0d``
- ``Effect/Subscriber``
<!--TODO: Can't currently document `Publisher` extensions-->
