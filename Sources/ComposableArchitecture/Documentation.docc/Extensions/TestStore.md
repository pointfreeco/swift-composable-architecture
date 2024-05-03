# ``ComposableArchitecture/TestStore``

## Topics

### Creating a test store

- ``init(initialState:reducer:withDependencies:file:line:)-3zio1``
- ``TestStoreOf``

### Configuring a test store

- ``dependencies``
- ``exhaustivity``
- ``timeout``
- ``useMainSerialExecutor``

### Testing a reducer

- ``send(_:assert:file:line:)-2co21``
- ``send(_:assert:file:line:)-1oopl``
- ``send(_:_:assert:file:line:)``
- ``receive(_:timeout:assert:file:line:)-6325h``
- ``receive(_:_:timeout:assert:file:line:)-dkei``
- ``receive(_:timeout:assert:file:line:)-5awso``
- ``receive(_:timeout:assert:file:line:)-7md3m``
- ``assert(_:file:line:)``
- ``finish(timeout:file:line:)-53gi5``
- ``isDismissed``
- ``TestStoreTask``

### Skipping actions and effects

- ``skipReceivedActions(strict:file:line:)-a4ri``
- ``skipInFlightEffects(strict:file:line:)-5hbsk``

### Accessing state

While the most common way of interacting with a test store's state is via its
``send(_:assert:file:line:)-2co21`` and ``receive(_:timeout:assert:file:line:)-6325h`` methods, you
may also access it directly throughout a test.

- ``state``

### Supporting types

- ``TestStoreOf``

### Deprecations

- <doc:TestStoreDeprecations>
