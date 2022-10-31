# Deprecations

Review unsupported test store APIs and their replacements.

## Overview

Avoid using deprecated APIs in your app. Select a method to see the replacement that you should use instead.

## Topics

### Creating a test store

- ``TestStore/init(initialState:reducer:environment:file:line:)``

### Configuring a test store

- ``TestStore/environment``

### Testing reducers

- ``TestStore/send(_:assert:file:line:)-30pjj``
- ``TestStore/receive(_:assert:file:line:)-2nhm0``
- ``TestStore/receive(_:assert:file:line:)-6fuav``
- ``TestStore/receive(_:assert:file:line:)-u5tf``
- ``TestStore/assert(_:file:line:)-707lb``
- ``TestStore/assert(_:file:line:)-4gff7``
- ``TestStore/LocalState``
- ``TestStore/LocalAction``
- ``TestStore/Step``

### Methods for skipping tests

- ``TestStore/skipReceivedActions(strict:file:line:)-3nldt``
- ``TestStore/skipInFlightEffects(strict:file:line:)-95n5f``
