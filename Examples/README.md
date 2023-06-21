# Examples

This directory holds many case studies and applications to demonstrate solving various problems with the Composable Architecture. Open the `ComposableArchitecture.xcworkspace` at the root of the repo to see all example projects in one single workspace, or you can open each example application individually.

* **Case Studies**
  <br> Demonstrates how to solve some common application problems in an isolated environment, in both SwiftUI and UIKit. Things like bindings, navigation, effects, and reusable components.

* **Search**
  <br> Demonstrates how to build a search feature, with debouncing of typing events, and comes with a full test suite to perform end-to-end testing from user actions to running side effects.

* **Speech Recognition**
  <br> This application uses Apple's Speech framework to demonstrate how to wrap complex dependencies in the `Effect` type of the Composable Architecture. Doing a little bit of upfront work allows you to interact with the dependencies in a controlled, understandable way, and you can write tests on how the dependency interacts with your application logic.

* **Standups**
  <br> This application is a faithful reconstruction of one of Apple's more interesting sample projects, called [Scrumdinger][scrumdinger]. It deals with many forms of navigation (alerts, sheets, drill-downs) and many forms of side effects (data persistence, timers and speech recognizers).

* **Tic-Tac-Toe**
  <br> Builds a moderately complex application in both SwiftUI and UIKit that is fully controlled by the Composable Architecture. The core application logic is put into its own modules, with no UI, and then both of the SwiftUI and UIKit applications are run off of that single source of logic. This demonstrates how one can hyper-modularize an application, which for a big enough application can greatly help compile times and developer productivity. This demo was inspired by the equivalent demos in [RIBs](http://github.com/uber/RIBs) (see [here](https://github.com/uber/RIBs/tree/master/ios/tutorials/tutorial4-completed)) and [Workflow](https://github.com/square/workflow/) (see [here](https://github.com/square/workflow-swift/tree/main/Samples/TicTacToe)).

* **Todos**
  <br> A simple todo application with a few bells and whistles, and a comprehensive test suite.

* **Voice Memos**
  <br> A more complex demo that demonstrates how to work with many complex dependencies at once, and how to manage a complex state machine driven off of timers.

[scrumdinger]: https://developer.apple.com/tutorials/app-dev-training/getting-started-with-scrumdinger