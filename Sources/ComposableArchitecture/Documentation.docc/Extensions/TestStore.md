# ``ComposableArchitecture/TestStore``

## Topics

### Creating a test store

- ``init(initialState:reducer:file:line:)``

### Configuring a test store

- ``dependencies``
- ``timeout``

### Testing a reducer

- ``send(_:_:file:line:)-3pf4p``
- ``receive(_:timeout:_:file:line:)-1fjua``
- ``finish(timeout:file:line:)-53gi5``
- ``TestStoreTask``

### Accessing state

While the most common way of interacting with a test store's state is via its ``send(_:_:file:line:)-3pf4p`` and ``receive(_:timeout:_:file:line:)-1fjua`` methods, you may also access it directly throughout a test.

- ``state``

### Scoping test stores

- ``scope(state:action:)``
- ``scope(state:)``

### Deprecations

- <doc:TestStoreDeprecations>
