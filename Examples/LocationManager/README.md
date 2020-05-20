# Location Manager

<img width="1290" alt="image" src="https://user-images.githubusercontent.com/135203/82390225-0187c880-99f3-11ea-8ae7-e33f6993f89d.png">

This application demonstrates how to build a simple application for both iOS and macOS using CoreLocation and MapKit. It displays a map and allows you to search for points of interest on the map by category (e.g. cafe, museum, etc). You can also center the map on your current location, if you allow access.

The core logic of the application is written a single time, and powers both views. All of the code shared between the iOS and macOS apps is in the `Common` Swift package. It has:

* Core business logic implemented as a reducer that operates on the domain state, actions and environment.
* A thin wrapper around the `MKLocalSearch` API that allows us to search for points of interest on the map.
* A wrapper around `MKMapView` to make it usable from SwiftUI.

Interaction with CoreLocation's `CLLocationManager` API is done via the [`ComposableCoreLocation`](../../Sources/ComposableCoreLocation) library that comes with the Composable Architecture. It gives you an `Effect`-friendly interface to all of `CLLocationManager`'s APIs, making it easy to use its features from a reducer _and_ making it easy to test logic that depends on its `CLLocationManager`'s functionality.
