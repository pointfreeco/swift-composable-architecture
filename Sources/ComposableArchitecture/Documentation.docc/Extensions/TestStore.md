# ``ComposableArchitecture/TestStore``

## Topics

### Creating a test store

- ``init(initialState:reducer:prepareDependencies:file:line:)-55zkv``
- ``init(initialState:reducer:observe:prepareDependencies:file:line:)``
- ``init(initialState:reducer:observe:send:prepareDependencies:file:line:)``

### Configuring a test store

- ``dependencies``
- ``exhaustivity``
- ``timeout``

### Testing a reducer

- ``send(_:assert:file:line:)-1ax61``
- ``receive(_:timeout:assert:file:line:)-1rwdd``
- ``receive(_:timeout:assert:file:line:)-8xkqt``
- ``receive(_:timeout:assert:file:line:)-2ju31``
- ``finish(timeout:file:line:)``
- ``TestStoreTask``

### Methods for skipping actions and effects

- ``skipReceivedActions(strict:file:line:)-a4ri``
- ``skipInFlightEffects(strict:file:line:)-5hbsk``

### Accessing state

While the most common way of interacting with a test store's state is via its ``send(_:assert:file:line:)-1ax61`` and ``receive(_:timeout:assert:file:line:)-1rwdd`` methods, you may also access it directly throughout a test.

- ``state``

### Deprecations

- <doc:TestStoreDeprecations>
