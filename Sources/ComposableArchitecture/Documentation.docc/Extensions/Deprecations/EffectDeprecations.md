# Deprecations

Review unsupported effect APIs and their replacements.

## Overview

Avoid using deprecated APIs in your app. Select a method to see the replacement that you should use instead.

## Topics

### Creating an effect

- ``EffectPublisher/task(priority:operation:)``

### Cancellation

- ``EffectPublisher/cancel(ids:)-9tnmm``

### Composition

- ``EffectPublisher/concatenate(_:)-3awnj``
- ``EffectPublisher/concatenate(_:)-8x6rz``

### Testing

- ``EffectPublisher/failing(_:)``
- ``EffectPublisher/unimplemented(_:)``

### Combine integration

- ``EffectPublisher/Output``
- ``EffectPublisher/init(_:)``
- ``EffectPublisher/init(value:)``
- ``EffectPublisher/init(error:)``
- ``EffectPublisher/upstream``
- ``EffectPublisher/catching(_:)``
- ``EffectPublisher/debounce(id:for:scheduler:options:)-8x633``
- ``EffectPublisher/debounce(id:for:scheduler:options:)-76yye``
- ``EffectPublisher/deferred(for:scheduler:options:)``
- ``EffectPublisher/fireAndForget(_:)``
- ``EffectPublisher/future(_:)``
- ``EffectPublisher/receive(subscriber:)``
- ``EffectPublisher/result(_:)``
- ``EffectPublisher/run(_:)``
- ``EffectPublisher/throttle(id:for:scheduler:latest:)-9kwd5``
- ``EffectPublisher/throttle(id:for:scheduler:latest:)-5jfpx``
- ``EffectPublisher/timer(id:every:tolerance:on:options:)-4exe6``
- ``EffectPublisher/timer(id:every:tolerance:on:options:)-7po0d``
- ``EffectPublisher/Subscriber``
<!--DocC: Can't currently document `Publisher` extensions. -->
