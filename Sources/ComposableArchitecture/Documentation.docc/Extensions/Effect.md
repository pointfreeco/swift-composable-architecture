# ``ComposableArchitecture/EffectTask``

## Topics

### Creating an effect

- ``EffectPublisher/none``
- ``EffectPublisher/task(priority:operation:catch:file:fileID:line:)``
- ``EffectPublisher/run(priority:operation:catch:file:fileID:line:)``
- ``EffectPublisher/fireAndForget(priority:_:)``
- ``TaskResult``

### Cancellation

- ``EffectPublisher/cancellable(id:cancelInFlight:)-29q60``
- ``EffectPublisher/cancel(id:)-6hzsl``
- ``EffectPublisher/cancel(ids:)-1cqqx``
- ``withTaskCancellation(id:cancelInFlight:operation:)-4dtr6``

### Composition

- ``EffectPublisher/map(_:)-yn70``
- ``EffectPublisher/merge(_:)-45guh``
- ``EffectPublisher/merge(_:)-3d54p``

### Concurrency

- ``UncheckedSendable``

### Testing

- ``EffectPublisher/unimplemented(_:)``

### SwiftUI integration

- ``EffectPublisher/animation(_:)``

### Deprecations

- <doc:EffectDeprecations>
