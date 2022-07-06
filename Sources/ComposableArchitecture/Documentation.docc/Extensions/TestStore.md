# ``ComposableArchitecture/TestStore``

## Topics

### Creating a Test Store

- ``init(initialState:reducer:environment:file:line:)``

### Configuring a Test Store

- ``environment``
- ``timeout``

### Testing a Reducer

- ``send(_:_:file:line:)``
- ``receive(_:timeout:_:file:line:)``
- ``finish(timeout:file:line:)``
- ``TestStoreTask``

### Accessing State

While the most common way of interacting with a test store's state is via its ``send(_:_:file:line:)`` and ``receive(_:_:file:line:)`` methods, you may also access it directly throughout a test.

- ``state``

### Scoping a Test Store

- ``scope(state:action:)``
- ``scope(state:)``

### Deprecations

- <doc:TestStoreDeprecations>
