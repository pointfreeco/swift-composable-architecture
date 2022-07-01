# ``ComposableArchitecture/TestStore``

## Topics

### Creating a Test Store

- ``init(initialState:reducer:environment:file:line:)``

### Testing a Reducer

- ``send(_:_:file:line:)``
- ``receive(_:_:file:line:)``

### Controlling Dependencies

Controlling a reducer's dependencies are a crucial part of building a reliable test suite. Mutating the environment provides a means of influencing a reducer's dependencies over the course of a test.

- ``environment``

### Accessing State

While the most common way of interacting with a test store's state is via its ``send(_:_:file:line:)`` and ``receive(_:_:file:line:)`` methods, you may also access it directly throughout a test.

- ``state``

### Scoping a Test Store

- ``scope(state:action:)``
- ``scope(state:)``

### Deprecations

- <doc:TestStoreDeprecations>
