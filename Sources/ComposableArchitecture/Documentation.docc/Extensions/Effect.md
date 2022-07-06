# ``ComposableArchitecture/Effect``

## Topics

### Creating an Effect

- ``none``
- ``task(priority:operation:catch:file:fileID:line:)``
- ``run(priority:operation:catch:file:fileID:line:)``
- ``fireAndForget(priority:_:)``
- ``TaskResult``

### Cancellation

- ``cancellable(id:cancelInFlight:)-499iv``
- ``cancel(id:)-7vmd9``
- ``cancel(ids:)-8gan2``
- ``cancellable(id:cancelInFlight:)-17skv``
- ``cancel(id:)-iun1``
- ``cancel(ids:)-dmwy``
- ``withTaskCancellation(id:cancelInFlight:resultType:operation:)-1m27c``
- ``withTaskCancellation(id:cancelInFlight:resultType:operation:)-8exbl``

### Composition

<!--NB: DocC bug prevents the following from being resolved-->
<!--- ``map(_:)``-->
- ``merge(_:)-3al9f``
- ``merge(_:)-4n451``

### Testing

- ``unimplemented(_:)``

### SwiftUI Integration

- ``animation(_:)``

### Deprecations

- <doc:EffectDeprecations>
