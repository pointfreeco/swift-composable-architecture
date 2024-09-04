# ``ComposableArchitecture/TestStore``

## Topics

### Creating a test store

- ``init(initialState:reducer:withDependencies:fileID:file:line:column:)``
- ``TestStoreOf``

### Configuring a test store

- ``dependencies``
- ``exhaustivity``
- ``timeout``
- ``useMainSerialExecutor``

### Testing a reducer

- ``send(_:assert:fileID:file:line:column:)-8f2pl``
- ``send(_:assert:fileID:file:line:column:)-8877x``
- ``send(_:_:assert:fileID:file:line:column:)``
- ``receive(_:timeout:assert:fileID:file:line:column:)-8zqxk``
- ``receive(_:timeout:assert:fileID:file:line:column:)-35638``
- ``receive(_:timeout:assert:fileID:file:line:column:)-53wic``
- ``receive(_:_:timeout:assert:fileID:file:line:column:)-9jd7x``
- ``assert(_:fileID:file:line:column:)``
- ``finish(timeout:fileID:file:line:column:)-klnc``
- ``isDismissed``
- ``TestStoreTask``

### Skipping actions and effects

- ``skipReceivedActions(strict:fileID:file:line:column:)``
- ``skipInFlightEffects(strict:fileID:file:line:column:)``

### Accessing state

While the most common way of interacting with a test store's state is via its
``send(_:assert:fileID:file:line:column:)-8f2pl`` and 
``receive(_:timeout:assert:fileID:file:line:column:)-53wic`` methods, you may also access it 
directly throughout a test.

- ``state``

### Supporting types

- ``TestStoreOf``

### Deprecations

- <doc:TestStoreDeprecations>
