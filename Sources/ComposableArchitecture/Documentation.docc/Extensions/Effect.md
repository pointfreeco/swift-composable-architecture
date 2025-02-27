# ``ComposableArchitecture/Effect``

## Topics

### Creating an effect

- ``none``
- ``run(priority:operation:catch:fileID:filePath:line:column:)``
- ``send(_:)``
- ``EffectOf``
- ``TaskResult``

### Cancellation

- ``cancellable(id:cancelInFlight:)``
- ``cancel(id:)``
- ``ComposableArchitecture/withTaskCancellation(id:cancelInFlight:isolation:operation:)``
- ``_Concurrency/Task/cancel(id:)``

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
- ``debounce(id:for:scheduler:options:)``
- ``throttle(id:for:scheduler:latest:)``
