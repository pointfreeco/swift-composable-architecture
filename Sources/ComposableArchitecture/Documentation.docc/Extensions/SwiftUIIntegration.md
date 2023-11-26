# SwiftUI Integration

Integrating the Composable Architecture into a SwiftUI application.

## Overview

The Composable Architecture can be used to power applications built in many frameworks, but it was
designed with SwiftUI in mind, and comes with many powerful tools to integrate into your SwiftUI applications.

## Topics

### View containers

- ``WithViewStore``
- ``IfLetStore``
- ``ForEachStore``
- ``SwitchStore``
- ``NavigationStackStore``

### Bindings

- <doc:Bindings>
- ``ViewStore/binding(get:send:)-65xes``
- ``BindingState``
- ``BindableAction``
- ``BindingAction``
- ``BindingReducer``
- ``BindingViewState``
- ``BindingViewStore``

### View Modifiers

- ``SwiftUI/View/alert(store:)``
- ``SwiftUI/View/confirmationDialog(store:)``
- ``SwiftUI/View/fullScreenCover(store:onDismiss:content:)``
- ``SwiftUI/View/navigationDestination(store:destination:)``
- ``SwiftUI/View/popover(store:attachmentAnchor:arrowEdge:content:)``
- ``SwiftUI/View/sheet(store:onDismiss:content:)``

### Deprecations

- <doc:SwiftUIDeprecations>
