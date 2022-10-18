# ``ComposableArchitecture/TestStore``

## Topics

### Creating a test store

- ``init(initialState:reducer:file:line:)``

### Configuring a test store

- ``dependencies``
- ``timeout``

### Testing a reducer

- ``send(_:_:file:line:)-6s1gq``
- ``receive(_:timeout:_:file:line:)-8yd62``
- ``finish(timeout:file:line:)-7pmv3``
- ``TestStoreTask``

### Accessing state

While the most common way of interacting with a test store's state is via its ``send(_:_:file:line:)-6s1gq`` and ``receive(_:timeout:_:file:line:)-8yd62`` methods, you may also access it directly throughout a test.

- ``state``

### Scoping test stores

- ``scope(state:action:)``
- ``scope(state:)``

### Deprecations

- <doc:TestStoreDeprecations>
