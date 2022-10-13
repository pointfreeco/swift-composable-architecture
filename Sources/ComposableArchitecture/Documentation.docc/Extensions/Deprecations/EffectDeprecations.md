# Deprecations

Review unsupported effect APIs and their replacements.

## Overview

Avoid using deprecated APIs in your app. Select a method to see the replacement that you should use instead.

## Topics

### Creating an effect

- ``EffectPublisher/task(priority:operation:)``

### Cancellation

- ``EffectPublisher/cancel(ids:)-8q1hl``

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
- ``EffectPublisher/debounce(id:for:scheduler:options:)-1xdnj``
- ``EffectPublisher/debounce(id:for:scheduler:options:)-1oaak``
- ``EffectPublisher/deferred(for:scheduler:options:)``
- ``EffectPublisher/fireAndForget(_:)``
- ``EffectPublisher/future(_:)``
- ``EffectPublisher/receive(subscriber:)``
- ``EffectPublisher/result(_:)``
- ``EffectPublisher/run(_:)``
- ``EffectPublisher/throttle(id:for:scheduler:latest:)-3gibe``
- ``EffectPublisher/throttle(id:for:scheduler:latest:)-85y01``
- ``EffectPublisher/timer(id:every:tolerance:on:options:)-6yv2m``
- ``EffectPublisher/timer(id:every:tolerance:on:options:)-8t3is``
- ``EffectPublisher/Subscriber``
<!--DocC: Can't currently document `Publisher` extensions. -->
