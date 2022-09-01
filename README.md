# The Composable Architecture

[![CI](https://github.com/pointfreeco/swift-composable-architecture/workflows/CI/badge.svg)](https://github.com/pointfreeco/swift-composable-architecture/actions?query=workflow%3ACI)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpointfreeco%2Fswift-composable-architecture%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/pointfreeco/swift-composable-architecture)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpointfreeco%2Fswift-composable-architecture%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/pointfreeco/swift-composable-architecture)

The Composable Architecture (TCA, for short) is a library for building applications in a consistent and understandable way, with composition, testing, and ergonomics in mind. It can be used in SwiftUI, UIKit, and more, and on any Apple platform (iOS, macOS, tvOS, and watchOS).

* [What is the Composable Architecture?](#what-is-the-composable-architecture)
* [Learn more](#learn-more)
* [Examples](#examples)
* [Basic usage](#basic-usage)
* [Supplemental libraries](#supplementary-libraries)
* [FAQ](#faq)
* [Requirements](#requirements)
* [Installation](#installation)
* [Documentation](#documentation)
* [Help](#help)
* [Translations](#translations)
* [Credits and thanks](#credits-and-thanks)
* [Other libraries](#other-libraries)

## What is the Composable Architecture?

This library provides a few core tools that can be used to build applications of varying purpose and complexity. It provides compelling stories that you can follow to solve many problems you encounter day-to-day when building applications, such as:

* **State management**
  <br> How to manage the state of your application using simple value types, and share state across many screens so that mutations in one screen can be immediately observed in another screen.

* **Composition**
  <br> How to break down large features into smaller components that can be extracted to their own, isolated modules and be easily glued back together to form the feature.

* **Side effects**
  <br> How to let certain parts of the application talk to the outside world in the most testable and understandable way possible.

* **Testing**
  <br> How to not only test a feature built in the architecture, but also write integration tests for features that have been composed of many parts, and write end-to-end tests to understand how side effects influence your application. This allows you to make strong guarantees that your business logic is running in the way you expect.

* **Ergonomics**
  <br> How to accomplish all of the above in a simple API with as few concepts and moving parts as possible.

## Learn More

The Composable Architecture was designed over the course of many episodes on [Point-Free](https://www.pointfree.co), a video series exploring functional programming and the Swift language, hosted by [Brandon Williams](https://twitter.com/mbrandonw) and [Stephen Celis](https://twitter.com/stephencelis).

You can watch all of the episodes [here](https://www.pointfree.co/collections/composable-architecture), as well as a dedicated, multipart tour of the architecture from scratch: [part 1](https://www.pointfree.co/collections/composable-architecture/a-tour-of-the-composable-architecture/ep100-a-tour-of-the-composable-architecture-part-1), [part 2](https://www.pointfree.co/collections/composable-architecture/a-tour-of-the-composable-architecture/ep101-a-tour-of-the-composable-architecture-part-2), [part 3](https://www.pointfree.co/collections/composable-architecture/a-tour-of-the-composable-architecture/ep102-a-tour-of-the-composable-architecture-part-3) and [part 4](https://www.pointfree.co/collections/composable-architecture/a-tour-of-the-composable-architecture/ep103-a-tour-of-the-composable-architecture-part-4).

<a href="https://www.pointfree.co/collections/composable-architecture">
  <img alt="video poster image" src="https://d3rccdn33rt8ze.cloudfront.net/episodes/0069.jpeg" width="600">
</a>

## Examples

[![Screen shots of example applications](https://d3rccdn33rt8ze.cloudfront.net/composable-architecture/demos.png)](./Examples)

This repo comes with _lots_ of examples to demonstrate how to solve common and complex problems with the Composable Architecture. Check out [this](./Examples) directory to see them all, including:

* [Case Studies](./Examples/CaseStudies)
  * Getting started
  * Effects
  * Navigation
  * Higher-order reducers
  * Reusable components
* [Location manager](https://github.com/pointfreeco/composable-core-location/tree/main/Examples/LocationManager)
* [Motion manager](https://github.com/pointfreeco/composable-core-motion/tree/main/Examples/MotionManager)
* [Search](./Examples/Search)
* [Speech Recognition](./Examples/SpeechRecognition)
* [Tic-Tac-Toe](./Examples/TicTacToe)
* [Todos](./Examples/Todos)
* [Voice memos](./Examples/VoiceMemos)

Looking for something more substantial? Check out the source code for [isowords](https://github.com/pointfreeco/isowords), an iOS word search game built in SwiftUI and the Composable Architecture.

## Basic Usage

To build a feature using the Composable Architecture you define some types and values that model your domain:

* **State**: A type that describes the data your feature needs to perform its logic and render its UI.
* **Action**: A type that represents all of the actions that can happen in your feature, such as user actions, notifications, event sources, and more.
* **Environment**: A type that holds any dependencies the feature needs, such as API clients, analytics clients, etc.
* **Reducer**: A function that describes how to evolve the current state of the app to the next state given an action. The reducer is also responsible for returning any effects that should be run, such as API requests, which can be done by returning an `Effect` value.
* **Store**: The runtime that actually drives your feature. You send all user actions to the store so that the store can run the reducer and effects, and you can observe state changes in the store so that you can update UI.

The benefits of doing this are that you will instantly unlock testability of your feature, and you will be able to break large, complex features into smaller domains that can be glued together.

As a basic example, consider a UI that shows a number along with "+" and "−" buttons that increment and decrement the number. To make things interesting, suppose there is also a button that when tapped makes an API request to fetch a random fact about that number and then displays the fact in an alert.

The state of this feature would consist of an integer for the current count, as well as an optional string that represents the title of the alert we want to show (optional because `nil` represents not showing an alert):

```swift
struct AppState: Equatable {
  var count = 0
  var numberFactAlert: String?
}
```

Next, we have the actions in the feature. There are the obvious actions, such as tapping the decrement button, increment button, or fact button. But there are also some slightly non-obvious ones, such as the action of the user dismissing the alert, and the action that occurs when we receive a response from the fact API request:

```swift
enum AppAction: Equatable {
  case factAlertDismissed
  case decrementButtonTapped
  case incrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(TaskResult<String>)
}
```

Next, we model the environment of dependencies this feature needs to do its job. In particular, to fetch a number fact we can model an async throwing function from `Int` to `String`:

```swift
struct AppEnvironment {
  var numberFact: (Int) async throws -> String
}
```

Next, we implement a reducer that implements the logic for this domain. It describes how to change the current state to the next state, and describes what effects need to be executed. Some actions don't need to execute effects, and they can return `.none` to represent that:

```swift
let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  switch action {
  case .factAlertDismissed:
    state.numberFactAlert = nil
    return .none

  case .decrementButtonTapped:
    state.count -= 1
    return .none

  case .incrementButtonTapped:
    state.count += 1
    return .none

  case .numberFactButtonTapped:
    return .task {
      await .numberFactResponse(TaskResult { try await environment.numberFact(state.count) })
    }

  case let .numberFactResponse(.success(fact)):
    state.numberFactAlert = fact
    return .none

  case .numberFactResponse(.failure):
    state.numberFactAlert = "Could not load a number fact :("
    return .none
  }
}
```

And then finally we define the view that displays the feature. It holds onto a `Store<AppState, AppAction>` so that it can observe all changes to the state and re-render, and we can send all user actions to the store so that state changes. We must also introduce a struct wrapper around the fact alert to make it `Identifiable`, which the `.alert` view modifier requires:

```swift
struct AppView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        HStack {
          Button("−") { viewStore.send(.decrementButtonTapped) }
          Text("\(viewStore.count)")
          Button("+") { viewStore.send(.incrementButtonTapped) }
        }

        Button("Number fact") { viewStore.send(.numberFactButtonTapped) }
      }
      .alert(
        item: viewStore.binding(
          get: { $0.numberFactAlert.map(FactAlert.init(title:)) },
          send: .factAlertDismissed
        ),
        content: { Alert(title: Text($0.title)) }
      )
    }
  }
}

struct FactAlert: Identifiable {
  var title: String
  var id: String { self.title }
}
```

It's important to note that we were able to implement this entire feature without having a real, live effect at hand. This is important because it means features can be built in isolation without building their dependencies, which can help compile times.

It is also straightforward to have a UIKit controller driven off of this store. You subscribe to the store in `viewDidLoad` in order to update the UI and show alerts. The code is a bit longer than the SwiftUI version, so we have collapsed it here:

<details>
  <summary>Click to expand!</summary>

  ```swift
  class AppViewController: UIViewController {
    let viewStore: ViewStore<AppState, AppAction>
    var cancellables: Set<AnyCancellable> = []

    init(store: Store<AppState, AppAction>) {
      self.viewStore = ViewStore(store)
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()

      let countLabel = UILabel()
      let incrementButton = UIButton()
      let decrementButton = UIButton()
      let factButton = UIButton()

      // Omitted: Add subviews and set up constraints...

      self.viewStore.publisher
        .map { "\($0.count)" }
        .assign(to: \.text, on: countLabel)
        .store(in: &self.cancellables)

      self.viewStore.publisher.numberFactAlert
        .sink { [weak self] numberFactAlert in
          let alertController = UIAlertController(
            title: numberFactAlert, message: nil, preferredStyle: .alert
          )
          alertController.addAction(
            UIAlertAction(
              title: "Ok",
              style: .default,
              handler: { _ in self?.viewStore.send(.factAlertDismissed) }
            )
          )
          self?.present(alertController, animated: true, completion: nil)
        }
        .store(in: &self.cancellables)
    }

    @objc private func incrementButtonTapped() {
      self.viewStore.send(.incrementButtonTapped)
    }
    @objc private func decrementButtonTapped() {
      self.viewStore.send(.decrementButtonTapped)
    }
    @objc private func factButtonTapped() {
      self.viewStore.send(.numberFactButtonTapped)
    }
  }
  ```
</details>

Once we are ready to display this view, for example in the app's entry point, we can construct a store. This is the moment where we need to supply the dependencies, including the `numberFact` endpoint that actually reaches out into the real world to fetch the fact:

```swift
@main
struct CaseStudiesApp: App {
  var body: some Scene {
    AppView(
      store: Store(
        initialState: AppState(),
        reducer: appReducer,
        environment: AppEnvironment(
          numberFact: { number in 
            let (data, _) = try await URLSession.shared
              .data(from: .init(string: "http://numbersapi.com/\(number)")!)
            return String(decoding: data, using: UTF8.self)
          }
        )
      )
    )
  }
}
```

And that is enough to get something on the screen to play around with. It's definitely a few more steps than if you were to do this in a vanilla SwiftUI way, but there are a few benefits. It gives us a consistent manner to apply state mutations, instead of scattering logic in some observable objects and in various action closures of UI components. It also gives us a concise way of expressing side effects. And we can immediately test this logic, including the effects, without doing much additional work.

### Testing

To test, you first create a `TestStore` with the same information that you would to create a regular `Store`, except this time we can supply test-friendly dependencies. In particular, we can now use a `numberFact` implementation that immediately returns a value we control rather than reaching out into the real world:

```swift
@MainActor
func testFeature() async {
  let store = TestStore(
    initialState: AppState(),
    reducer: appReducer,
    environment: AppEnvironment(
      numberFact: { "\($0) is a good number Brent" }
    )
  )
}
```

Once the test store is created we can use it to make an assertion of an entire user flow of steps. Each step of the way we need to prove that state changed how we expect. Further, if a step causes an effect to be executed, which feeds data back into the store, we must assert that those actions were received properly.

The test below has the user increment and decrement the count, then they ask for a number fact, and the response of that effect triggers an alert to be shown, and then dismissing the alert causes the alert to go away.

```swift
// Test that tapping on the increment/decrement buttons changes the count
await store.send(.incrementButtonTapped) {
  $0.count = 1
}
await store.send(.decrementButtonTapped) {
  $0.count = 0
}

// Test that tapping the fact button causes us to receive a response from the effect. Note
// that we have to await the receive because the effect is asynchronous and so takes a small
// amount of time to emit.
await store.send(.numberFactButtonTapped)

await store.receive(.numberFactResponse(.success("0 is a good number Brent"))) {
  $0.numberFactAlert = "0 is a good number Brent"
}

// And finally dismiss the alert
await store.send(.factAlertDismissed) {
  $0.numberFactAlert = nil
}
```

That is the basics of building and testing a feature in the Composable Architecture. There are _a lot_ more things to be explored, such as composition, modularity, adaptability, and complex effects. The [Examples](./Examples) directory has a bunch of projects to explore to see more advanced usages.

### Debugging

The Composable Architecture comes with a number of tools to aid in debugging.

* `reducer.debug()` enhances a reducer with debug-printing that describes every action the reducer receives and every mutation it makes to state.

    ``` diff
    received action:
      AppAction.todoCheckboxTapped(id: UUID(5834811A-83B4-4E5E-BCD3-8A38F6BDCA90))
      AppState(
        todos: [
          Todo(
    -       isComplete: false,
    +       isComplete: true,
            description: "Milk",
            id: 5834811A-83B4-4E5E-BCD3-8A38F6BDCA90
          ),
          … (2 unchanged)
        ]
      )
    ```

* `reducer.signpost()` instruments a reducer with signposts so that you can gain insight into how long actions take to execute, and when effects are running.

    <img src="https://s3.amazonaws.com/pointfreeco-production/point-free-pointers/0044-signposts-cover.jpg" width="600">

## Supplementary libraries

One of the most important principles of the Composable Architecture is that side effects are never performed directly, but instead are wrapped in the `Effect` type, returned from reducers, and then the `Store` later performs the effect. This is crucial for simplifying how data flows through an application, and for gaining testability on the full end-to-end cycle of user action to effect execution.

However, this also means that many libraries and SDKs you interact with on a daily basis need to be retrofitted to be a little more friendly to the Composable Architecture style. That's why we'd like to ease the pain of using some of Apple's most popular frameworks by providing wrapper libraries that expose their functionality in a way that plays nicely with our library. So far we support:

* [`ComposableCoreLocation`](https://github.com/pointfreeco/composable-core-location): A wrapper around `CLLocationManager` that makes it easy to use from a reducer, and easy to write tests for how your logic interacts with `CLLocationManager`'s functionality.
* [`ComposableCoreMotion`](https://github.com/pointfreeco/composable-core-motion): A wrapper around `CMMotionManager` that makes it easy to use from a reducer, and easy to write tests for how your logic interacts with `CMMotionManager`'s functionality.
* More to come soon. Keep an eye out 😉

If you are interested in contributing a wrapper library for a framework that we have not yet covered, feel free to open an issue expressing your interest so that we can discuss a path forward.

## FAQ

* How does the Composable Architecture compare to Elm, Redux, and others?
  <details>
    <summary>Expand to see answer</summary>
    The Composable Architecture (TCA) is built on a foundation of ideas popularized by the Elm Architecture (TEA) and Redux, but made to feel at home in the Swift language and on Apple's platforms.

    In some ways TCA is a little more opinionated than the other libraries. For example, Redux is not prescriptive with how one executes side effects, but TCA requires all side effects to be modeled in the `Effect` type and returned from the reducer.

    In other ways TCA is a little more lax than the other libraries. For example, Elm controls what kinds of effects can be created via the `Cmd` type, but TCA allows an escape hatch to any kind of effect since `Effect` conforms to the Combine `Publisher` protocol.

    And then there are certain things that TCA prioritizes highly that are not points of focus for Redux, Elm, or most other libraries. For example, composition is very important aspect of TCA, which is the process of breaking down large features into smaller units that can be glued together. This is accomplished with the `pullback` and `combine` operators on reducers, and it aids in handling complex features as well as modularization for a better-isolated code base and improved compile times.
  </details>

## Requirements

The Composable Architecture depends on the Combine framework, so it requires minimum deployment targets of iOS 13, macOS 10.15, Mac Catalyst 13, tvOS 13, and watchOS 6. If your application must support older OSes, there are forks for [ReactiveSwift](https://github.com/trading-point/reactiveswift-composable-architecture) and [RxSwift](https://github.com/dannyhertz/rxswift-composable-architecture) that you can adopt!

## Installation

You can add ComposableArchitecture to an Xcode project by adding it as a package dependency.

  1. From the **File** menu, select **Add Packages...**
  2. Enter "https://github.com/pointfreeco/swift-composable-architecture" into the package repository URL text field
  3. Depending on how your project is structured:
      - If you have a single application target that needs access to the library, then add **ComposableArchitecture** directly to your application.
      - If you want to use this library from multiple Xcode targets, or mixing Xcode targets and SPM targets, you must create a shared framework that depends on **ComposableArchitecture** and then depend on that framework in all of your targets. For an example of this, check out the [Tic-Tac-Toe](./Examples/TicTacToe) demo application, which splits lots of features into modules and consumes the static library in this fashion using the **tic-tac-toe** Swift package.

## Documentation

The documentation for releases and `main` are available here:

* [`main`](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture)
* [0.39.0](https://pointfreeco.github.io/swift-composable-architecture/0.39.0/documentation/composablearchitecture/)
<details>
  <summary>
  Other versions
  </summary>

  * [0.38.0](https://pointfreeco.github.io/swift-composable-architecture/0.38.0/documentation/composablearchitecture/)
  * [0.37.0](https://pointfreeco.github.io/swift-composable-architecture/0.37.0/documentation/composablearchitecture)
  * [0.36.0](https://pointfreeco.github.io/swift-composable-architecture/0.36.0/documentation/composablearchitecture)
  * [0.35.0](https://pointfreeco.github.io/swift-composable-architecture/0.35.0/documentation/composablearchitecture)
  * [0.34.0](https://pointfreeco.github.io/swift-composable-architecture/0.34.0/documentation/composablearchitecture)
  * [0.33.1](https://pointfreeco.github.io/swift-composable-architecture/0.33.1/documentation/composablearchitecture)
  * [0.33.0](https://pointfreeco.github.io/swift-composable-architecture/0.33.0/documentation/composablearchitecture)
  * [0.32.0](https://pointfreeco.github.io/swift-composable-architecture/0.32.0/documentation/composablearchitecture)
  * [0.31.0](https://pointfreeco.github.io/swift-composable-architecture/0.31.0/documentation/composablearchitecture)
  * [0.30.0](https://pointfreeco.github.io/swift-composable-architecture/0.30.0/documentation/composablearchitecture)
  * [0.29.0](https://pointfreeco.github.io/swift-composable-architecture/0.29.0/documentation/composablearchitecture)
  * [0.28.1](https://pointfreeco.github.io/swift-composable-architecture/0.28.1/documentation/composablearchitecture)
  * [0.28.0](https://pointfreeco.github.io/swift-composable-architecture/0.28.0/documentation/composablearchitecture)
  * [0.27.1](https://pointfreeco.github.io/swift-composable-architecture/0.27.1/documentation/composablearchitecture)
  * [0.27.0](https://pointfreeco.github.io/swift-composable-architecture/0.27.0/documentation/composablearchitecture)
  * [0.26.0](https://pointfreeco.github.io/swift-composable-architecture/0.26.0/documentation/composablearchitecture)
  * [0.25.1](https://pointfreeco.github.io/swift-composable-architecture/0.25.1/documentation/composablearchitecture)
  * [0.25.0](https://pointfreeco.github.io/swift-composable-architecture/0.25.0/documentation/composablearchitecture)
  * [0.24.0](https://pointfreeco.github.io/swift-composable-architecture/0.24.0/documentation/composablearchitecture)
  * [0.23.0](https://pointfreeco.github.io/swift-composable-architecture/0.23.0/documentation/composablearchitecture)
  * [0.22.0](https://pointfreeco.github.io/swift-composable-architecture/0.22.0/documentation/composablearchitecture)
  * [0.21.0](https://pointfreeco.github.io/swift-composable-architecture/0.21.0/documentation/composablearchitecture)
  * [0.20.0](https://pointfreeco.github.io/swift-composable-architecture/0.20.0/documentation/composablearchitecture)
  * [0.19.0](https://pointfreeco.github.io/swift-composable-architecture/0.19.0/documentation/composablearchitecture)
  * [0.18.0](https://pointfreeco.github.io/swift-composable-architecture/0.18.0/documentation/composablearchitecture)
  * [0.17.0](https://pointfreeco.github.io/swift-composable-architecture/0.17.0/documentation/composablearchitecture)
  * [0.16.0](https://pointfreeco.github.io/swift-composable-architecture/0.16.0/documentation/composablearchitecture)
  * [0.15.0](https://pointfreeco.github.io/swift-composable-architecture/0.15.0/documentation/composablearchitecture)
  * [0.14.0](https://pointfreeco.github.io/swift-composable-architecture/0.14.0/documentation/composablearchitecture)
  * [0.13.0](https://pointfreeco.github.io/swift-composable-architecture/0.13.0/documentation/composablearchitecture)
  * [0.12.0](https://pointfreeco.github.io/swift-composable-architecture/0.12.0/documentation/composablearchitecture)
  * [0.11.0](https://pointfreeco.github.io/swift-composable-architecture/0.11.0/documentation/composablearchitecture)
  * [0.10.0](https://pointfreeco.github.io/swift-composable-architecture/0.10.0/documentation/composablearchitecture)
  * [0.9.0](https://pointfreeco.github.io/swift-composable-architecture/0.9.0/documentation/composablearchitecture)
  * [0.8.0](https://pointfreeco.github.io/swift-composable-architecture/0.8.0/documentation/composablearchitecture)
  * [0.7.0](https://pointfreeco.github.io/swift-composable-architecture/0.7.0/documentation/composablearchitecture)
  * [0.6.0](https://pointfreeco.github.io/swift-composable-architecture/0.6.0/documentation/composablearchitecture)
  * [0.5.0](https://pointfreeco.github.io/swift-composable-architecture/0.5.0/documentation/composablearchitecture)
  * [0.4.0](https://pointfreeco.github.io/swift-composable-architecture/0.4.0/documentation/composablearchitecture)
  * [0.3.0](https://pointfreeco.github.io/swift-composable-architecture/0.3.0/documentation/composablearchitecture)
  * [0.2.0](https://pointfreeco.github.io/swift-composable-architecture/0.2.0/documentation/composablearchitecture)
  * [0.1.5](https://pointfreeco.github.io/swift-composable-architecture/0.1.5/documentation/composablearchitecture)
  * [0.1.4](https://pointfreeco.github.io/swift-composable-architecture/0.1.4/documentation/composablearchitecture)
  * [0.1.3](https://pointfreeco.github.io/swift-composable-architecture/0.1.3/documentation/composablearchitecture)
  * [0.1.2](https://pointfreeco.github.io/swift-composable-architecture/0.1.2/documentation/composablearchitecture)
  * [0.1.1](https://pointfreeco.github.io/swift-composable-architecture/0.1.1/documentation/composablearchitecture)
  * [0.1.0](https://pointfreeco.github.io/swift-composable-architecture/0.1.0/documentation/composablearchitecture)
</details>

## Help

If you want to discuss the Composable Architecture or have a question about how to use it to solve a particular problem, you can start a topic in the [discussions](https://github.com/pointfreeco/swift-composable-architecture/discussions) tab of this repo, or ask around on [its Swift forum](https://forums.swift.org/c/related-projects/swift-composable-architecture).

## Translations

The following translations of this README have been contributed by members of the community:

* [Arabic](https://gist.github.com/NorhanBoghdadi/1b98d55c02b683ddef7e05c2ebcccd47)
* [French](https://gist.github.com/nikitamounier/0e93eb832cf389db12f9a69da030a2dc)
* [Indonesian](https://gist.github.com/wendyliga/792ea9ac5cc887f59de70a9e39cc7343)
* [Italian](https://gist.github.com/Bellaposa/5114e6d4d55fdb1388e8186886d48958)
* [Japanese](https://gist.github.com/kalupas226/bdf577e4a7066377ea0a8aaeebcad428)
* [Korean](https://gist.github.com/pilgwon/ea05e2207ab68bdd1f49dff97b293b17)
* [Portuguese](https://gist.github.com/SevioCorrea/2bbf337cd084a58c89f2f7f370626dc8)
* [Simplified Chinese](https://gist.github.com/sh3l6orrr/10c8f7c634a892a9c37214f3211242ad)
* [Spanish](https://gist.github.com/pitt500/f5e32fccb575ce112ffea2827c7bf942)

If you'd like to contribute a translation, please [open a PR](https://github.com/pointfreeco/swift-composable-architecture/edit/main/README.md) with a link to a [Gist](https://gist.github.com)!

## Credits and thanks

The following people gave feedback on the library at its early stages and helped make the library what it is today:

Paul Colton, Kaan Dedeoglu, Matt Diephouse, Josef Doležal, Eimantas, Matthew Johnson, George Kaimakas, Nikita Leonov, Christopher Liscio, Jeffrey Macko, Alejandro Martinez, Shai Mishali, Willis Plummer, Simon-Pierre Roy, Justin Price, Sven A. Schmidt, Kyle Sherman, Petr Šíma, Jasdev Singh, Maxim Smirnov, Ryan Stone, Daniel Hollis Tavares, and all of the [Point-Free](https://www.pointfree.co) subscribers 😁.

Special thanks to [Chris Liscio](https://twitter.com/liscio) who helped us work through many strange SwiftUI quirks and helped refine the final API.

And thanks to [Shai Mishali](https://github.com/freak4pc) and the [CombineCommunity](https://github.com/CombineCommunity/CombineExt/) project, from which we took their implementation of `Publishers.Create`, which we use in `Effect` to help bridge delegate and callback-based APIs, making it much easier to interface with 3rd party frameworks.

## Other libraries

The Composable Architecture was built on a foundation of ideas started by other libraries, in particular [Elm](https://elm-lang.org) and [Redux](https://redux.js.org/).

There are also many architecture libraries in the Swift and iOS community. Each one of these has their own set of priorities and trade-offs that differ from the Composable Architecture.

* [RIBs](https://github.com/uber/RIBs)
* [Loop](https://github.com/ReactiveCocoa/Loop)
* [ReSwift](https://github.com/ReSwift/ReSwift)
* [Workflow](https://github.com/square/workflow)
* [ReactorKit](https://github.com/ReactorKit/ReactorKit)
* [RxFeedback](https://github.com/NoTests/RxFeedback.swift)
* [Mobius.swift](https://github.com/spotify/mobius.swift)
* <details>
  <summary>And more</summary>

  * [Fluxor](https://github.com/FluxorOrg/Fluxor)
  * [PromisedArchitectureKit](https://github.com/RPallas92/PromisedArchitectureKit)
  </details>

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
