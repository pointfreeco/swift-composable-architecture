# Deprecations

Review unsupported SwiftUI APIs and their replacements.

## Overview

Avoid using deprecated APIs in your app. Select a method to see the replacement that you should use instead.

## Topics

### View stores

- ``ViewStore``

### View containers

- ``WithViewStore``
- ``IfLetStore``
- ``ForEachStore``
- ``SwitchStore``
- ``NavigationLinkStore``
- ``NavigationStackStore``

### View modifiers

- ``SwiftUI/View/alert(store:)``
- ``SwiftUI/View/alert(store:state:action:)``
- ``SwiftUI/View/confirmationDialog(store:)``
- ``SwiftUI/View/confirmationDialog(store:state:action:)``
- ``SwiftUI/View/fullScreenCover(store:onDismiss:content:)``
- ``SwiftUI/View/fullScreenCover(store:state:action:onDismiss:content:)``
- ``SwiftUI/View/legacyAlert(store:)``
- ``SwiftUI/View/legacyAlert(store:state:action:)``
- ``SwiftUI/View/navigationDestination(store:destination:)``
- ``SwiftUI/View/navigationDestination(store:state:action:destination:)``
- ``SwiftUI/View/popover(store:attachmentAnchor:arrowEdge:content:)``
- ``SwiftUI/View/popover(store:state:action:attachmentAnchor:arrowEdge:content:)``
- ``SwiftUI/View/sheet(store:onDismiss:content:)``
- ``SwiftUI/View/sheet(store:state:action:onDismiss:content:)``

### Bindings

- ``BindingState``
- ``BindingViewState``
- ``BindingViewStore``
