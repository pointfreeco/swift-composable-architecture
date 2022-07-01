# ``ComposableArchitecture/Effect``

## Topics

### Creating an Effect

- ``none``
- ``init(value:)``
- ``init(error:)``
- ``run(_:)``
- ``future(_:)``
- ``catching(_:)``
- ``result(_:)``
- ``fireAndForget(_:)``
- ``fireAndForget(priority:_:)``
- ``task(priority:operation:)-7lrdd``

### Cancellation

- ``cancellable(id:cancelInFlight:)-499iv``
- ``cancel(id:)-7vmd9``
- ``cancel(ids:)-8gan2``
- ``cancellable(id:cancelInFlight:)-17skv``
- ``cancel(id:)-iun1``
- ``cancel(ids:)-dmwy``

### Composition

<!--NB: DocC bug prevents the following from being resolved-->
<!--- ``map(_:)``-->
- ``merge(_:)-3al9f``
- ``merge(_:)-4n451``
- ``concatenate(_:)-3awnj``
- ``concatenate(_:)-8x6rz``

### Timing

- ``deferred(for:scheduler:options:)``
- ``debounce(id:for:scheduler:options:)-8x633``
- ``debounce(id:for:scheduler:options:)-76yye``
- ``throttle(id:for:scheduler:latest:)-9kwd5``
- ``throttle(id:for:scheduler:latest:)-5jfpx``
- ``timer(id:every:tolerance:on:options:)-4exe6``
- ``timer(id:every:tolerance:on:options:)-7po0d``

### Testing

- ``unimplemented(_:)``

### SwiftUI Integration

- ``animation(_:)``

### Combine Integration

- ``receive(subscriber:)``
- ``init(_:)``
- ``upstream``
- ``Subscriber``
<!--TODO: Can't currently document `Publisher` extensions-->

### Deprecations

- <doc:EffectDeprecations>
