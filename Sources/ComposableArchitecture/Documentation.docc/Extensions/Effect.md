# ``ComposableArchitecture/Effect``

## Topics

### Creating an effect

- ``none``
- ``run(priority:operation:catch:fileID:line:)``
- ``send(_:)``
- ``EffectOf``
- ``TaskResult``

### Cancellation

- ``cancellable(id:cancelInFlight:)``
- ``cancel(id:)``
- ``withTaskCancellation(id:cancelInFlight:operation:)``

### Composition

- ``map(_:)``
- ``merge(_:)-8ckqn``
- ``merge(with:)``

### Combine integration

- ``publisher(_:)``

### SwiftUI integration

- ``animation(_:)``
