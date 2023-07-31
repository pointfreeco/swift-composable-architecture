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
- ``merge(_:)-5ai73``
- ``merge(_:)-8ckqn``
- ``merge(with:)``
- ``concatenate(_:)-3iza9``
- ``concatenate(_:)-4gba2``
- ``concatenate(with:)``

### SwiftUI integration

- ``animation(_:)``
- ``transaction(_:)``

### Combine integration

- ``publisher(_:)``
