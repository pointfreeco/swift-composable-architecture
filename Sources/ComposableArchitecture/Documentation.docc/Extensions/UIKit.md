# UIKit Integration

Integrating the Composable Architecture into a UIKit application.

## Overview

While the Composable Architecture was designed with SwiftUI in mind, it comes with tools to 
integrate into application code written in UIKit.

## Topics

### Subscribing to state changes

- ``ObjectiveC/NSObject/observe(_:)``
- ``ObservationToken``

### Presenting alerts and action sheets

- ``UIKit/UIAlertController/init(store:)``

### Combine integration

- ``Store/ifLet(then:else:)``
- ``Store/publisher``
- ``ViewStore/publisher``
