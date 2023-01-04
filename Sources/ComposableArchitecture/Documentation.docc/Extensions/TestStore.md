# ``ComposableArchitecture/TestStore``

## Topics

### Creating a test store

- ``init(initialState:reducer:prepareDependencies:file:line:)``

### Configuring a test store

- ``dependencies``
- ``exhaustivity``
- ``timeout``

### Testing a reducer

- ``send(_:assert:file:line:)-1ax61``
- ``receive(_:timeout:assert:file:line:)-1rwdd``
- ``receive(_:timeout:assert:file:line:)-4e4m0``
- ``receive(_:timeout:assert:file:line:)-3myco``
- ``finish(timeout:file:line:)-53gi5``
- ``TestStoreTask``

### Methods for skipping actions and effects

- ``skipReceivedActions(strict:file:line:)-a4ri``
- ``skipInFlightEffects(strict:file:line:)-5hbsk``

### Accessing state

While the most common way of interacting with a test store's state is via its ``send(_:assert:file:line:)-1ax61`` and ``receive(_:timeout:assert:file:line:)-1rwdd`` methods, you may also access it directly throughout a test.

- ``state``

### Scoping test stores

- ``scope(state:action:)``
- ``scope(state:)``

### Deprecations

- <doc:TestStoreDeprecations>
