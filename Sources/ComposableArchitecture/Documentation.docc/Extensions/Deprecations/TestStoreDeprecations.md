# Deprecations

Review unsupported test store APIs and their replacements.

## Overview

Avoid using deprecated APIs in your app. Select a method to see the replacement that you should use instead.

## Topics

### Creating a test store

- ``TestStore/init(initialState:reducer:prepareDependencies:file:line:)-55zkv``
- ``TestStore/init(initialState:reducer:observe:prepareDependencies:file:line:)``
- ``TestStore/init(initialState:reducer:observe:send:prepareDependencies:file:line:)``
- ``TestStore/init(initialState:reducer:environment:file:line:)``
- ``TestStore/init(initialState:reducer:withDependencies:file:line:)-1l3ek``
- ``TestStore/init(initialState:reducer:prepareDependencies:file:line:)-72tkt``

### Configuring a test store

- ``TestStore/environment``

### Testing reducers

- ``TestStore/send(_:assert:file:line:)-30pjj``
- ``TestStore/receive(_:assert:file:line:)-2nhm0``
- ``TestStore/receive(_:assert:file:line:)-1bfw4``
- ``TestStore/receive(_:assert:file:line:)-5o4u3``
- ``TestStore/assert(_:file:line:)-707lb``
- ``TestStore/assert(_:file:line:)-4gff7``
- ``TestStore/LocalState``
- ``TestStore/LocalAction``
- ``TestStore/Step``

### Methods for skipping tests

- ``TestStore/skipReceivedActions(strict:file:line:)-3nldt``
- ``TestStore/skipInFlightEffects(strict:file:line:)-95n5f``

### Scoping test stores

- ``TestStore/scope(state:action:)``
- ``TestStore/scope(state:)``
