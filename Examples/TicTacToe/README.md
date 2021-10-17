# Tic-Tac-Toe

This example demonstrates how to build a full, moderately complex application in the Composable Architecture. It is based off the Tic-Tac-Toe examples used to demonstrate [RIBs](https://github.com/uber/RIBs) from Uber ([see here](https://github.com/uber/RIBs/tree/master/ios/tutorials)) and [Workflows](https://github.com/square/workflow) from Square ([see here](https://github.com/square/workflow-swift/tree/main/Samples/TicTacToe)).

It shows many real-world use cases and best practices that we encounter when building applications:

* Login flow and two-factor screens.

* Multistep navigation flows, from login to new game screen to game screen.

* Comprehensive test suite for every feature, including integration tests of many features working in unison, and end-to-end testing of side effects.

* Fully controlled side effects. Every feature is provided with all the dependencies it needs to do its work, which makes testing very easy.

* Highly modularized: every feature is isolated into its own module with minimal dependencies between them, allowing us to compile and run features in isolation without building the entire application.

* SwiftUI and UIKit applications are implemented, and both share the same core logic. This shows it's possible to create UIKit applications with the Composable Architecture just as easily as it is to create SwiftUI applications.

* The core logic of the application is put into modules named like `*Core`, and they are kept separate from modules containing UI, which is what allows us to share code across multiple platforms (SwiftUI and UIKit), but could also allow us to share code across iOS, macOS, watchOS and tvOS apps.

* Navigation is completely driven off of state. To see this, try opening the SwiftUI game, do a few things in the game, then close the modal and open the UIKit version to see that state is fully restored to where you left off.
