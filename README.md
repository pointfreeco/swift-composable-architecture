# The Composable Architecture

[![Swift 5.1](https://img.shields.io/badge/swift-5.1-ED523F.svg?style=flat)](https://swift.org/download/)
[![CI](https://github.com/pointfreeco/swift-composable-architecture/workflows/CI/badge.svg)](https://actions-badge.atrox.dev/pointfreeco/swift-composable-architecture/goto)
[![@pointfreeco](https://img.shields.io/badge/contact-@pointfreeco-5AA9E7.svg?style=flat)](https://twitter.com/pointfreeco)

The Composable Architecture is a library for building applications in a consistent and understandable way, with composition, testing and ergonomics in mind. It can be used in SwiftUI, UIKit, and more, and on any Apple platform (iOS, macOS, tvOS, and watchOS).

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

The Composable Architecture was designed over the course of many episodes on [Point-Free](https://www.pointfree.co), a video series exploring functional programming and the Swift, hosted by [Brandon Williams](https://twitter.com/mbrandonw) and [Stephen Celis](https://twitter.com/stephencelis).

To see all of the episodes, [click here](https://www.pointfree.co/collections/composable-architecture), and to see a tour of the library, [click here](https://www.pointfree.co/episodes/ep100-a-tour-of-the-composable-architecture-part-1).

<a href="https://www.pointfree.co/collections/composable-architecture">
  <img alt="video poster image" src="https://i.vimeocdn.com/video/850265054.jpg" width="600">
</a>

## Examples

This repo comes with _lots_ of examples to demonstrate how to solve common and complex problems with the Composable Architecture. Check out [this](./Examples) directory to see them all, including:

* [Case Studies](./Examples/CaseStudies)
  * Getting started
  * Effects
  * Navigation
  * Higher-order reducers
  * Reusable components
* [Motion manager](./Examples/MotionManager)
* [Search](./Examples/Search)
* [Speech Recognition](./Examples/SpeechRecognition)
* [Tic-Tac-Toe](./Examples/TicTacToe)
* [Todos](./Examples/Todos)
* [Voice memos](./Examples/VoiceMemos)

## Basic Usage

To build a feature using the Composable Architecture you define some types and values that model your domain:

* **State**: A type that describes the data your feature needs to perform its logic and render its UI.
* **Action**: A type that represents all of the actions that can happen in your feature, such as user actions, notifications, event sources and more.
* **Environment**: A type that holds any dependencies the feature needs, such as API clients, analytics clients, etc.
* **Reducer**: A function that describes how to evolve the current state of the app to the next state given an action. The reducer is also responsible for returning any effects that should be run, such as API requests.
* **Store**: The runtime that actually drives your feature. You send all user actions to the store so that the store can run the reducer and effects, and you can observe state changes in the store so that you can update UI.

The benefits of doing this is that you will instantly unlock testability of your feature, and you will be able to break large, complex features into smaller domains that can be glued together.

As a basic example, consider a UI that shows a number along with "+" and "−" buttons that increment and decrement the number. To make things interesting, suppose there is also a button that when tapped makes an API request to fetch a random fact about that number and then displays the fact in an alert.

The state of this feature would consist of an integer for the current count, as well as an optional string that represents the title of the alert we want to show (optional because `nil` represents not showing an alert):

```swift
struct AppState {
  var count = 0
  var numberFactAlert: String?
}
```

Next we have the actions in the feature. There are the obvious actions, such as tapping the decrement button, increment button, or fact button. But there are also some slightly non-obvious ones, such as the action of the user dismissing the alert, and the action that occurs when we receive a response from the fact API request:

```swift
enum AppAction {
  case factAlertDismissed
  case decrementButtonTapped
  case incrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(Result<String, ApiError>)
}

struct ApiError: Error {}
```

Next we model the environment of dependencies this feature needs to do its job. In particular, to fetch a number fact we need to construct an `Effect` value that encapsulates the network request. So that dependency is a function from `Int` to `Effect<String, ApiError>`, where `String` represents the response from the request. Further, the effect will typically do its work on a background thread (as is the case with `URLSession`), and so we need a way to receive the effect's values on the main queue. We do this via a main queue scheduler, which is a dependency that is important to control so that we can write tests. We must use an `AnyScheduler` so that we can use a live `DispatchQueue` in production and a test scheduler in tests.

```swift
struct AppEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var numberFact: (Int) -> Effect<String, ApiError>
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
    return environment.numberFact(state.count)
      .receive(on: environment.mainQueue)
      .map(AppAction.numberFactResponse)
      .catchToEffect()

  case let .numberFactResponse(.success(fact)):
    state.numberFactAlert = fact
    return .none

  case let .numberFactResponse(.failure):
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
        })
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

Once we are ready to display this view, for example in the scene delegate, we can construct a store. This is the moment where we need to supply the dependencies, and for now we can just use an effect that immediately returns a mocked string:

```swift
let appView = AppView(
  store: Store(
    initialState: AppState(),
    reducer: appReducer,
    environment: AppEnvironment(
      mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
      numberFact: { number in Effect(value: "\(number) is a good number Brent") }
    )
  )
)
```

And that is enough to get something on the screen to play around with. It's definitely a few more steps than if you were to do this in a vanilla SwiftUI way, but there are a few benefits. It gives us a consistent manner to apply state mutations, instead of scattering logic in some observable objects and in various action closures of UI components. It also gives us a concise way of expressing side effects. And we can immediately test this logic, including the effects, without doing much additional work.

To test, you first create a `TestStore` with the same information that you would to create a regular `Store`, except this time we can supply test-friendly dependencies. In particular, we use a test scheduler instead of the live `DispatchQueue.main` scheduler because that allows us to control when work is executed, and we don't have to artificially wait for queues to catch up.

```swift
let scheduler = DispatchQueue.testScheduler

let store = TestStore(
  initialState: AppState(),
  reducer: appReducer,
  environment: AppEnvironment(
    mainQueue: scheduler.eraseToAnyScheduler(),
    numberFact: { number in Effect(value: "\(number) is a good number Brent") }
  )
)
```

Once the test store is created we can use it to make an assertion of an entire user flow of steps. Each step of the way we need to prove that state changed how we expect. Further, if a step causes an effect to be executed, which feeds data back into the store, we must assert that those actions were received properly.

The test below has the user increment and decrement the count, then they ask for a number fact, and the response of that effect triggers an alert to be shown, and then dismissing the alert causes the alert to go away.

```swift
store.assert(
  // Test that tapping on the increment/decrement buttons changes the count
  .send(.incrementButtonTapped) {
    $0.count = 1
  },
  .send(.decrementButtonTapped) {
    $0.count = 0
  },

  // Test that tapping the fact button causes us to receive a response from the effect. Note
  // that we have to advance the scheduler because we used `.receive(on:)` in the reducer.
  .send(.numberFactButtonTapped),
  .do { scheduler.advance() },
  .receive(.numberFactResponse(.success("0 is a good number Brent"))) {
    $0.numberFactAlert = "0 is a good number Brent"
  },

  // And finally dismiss the alert
  .send(.factAlertDismissed) {
    $0.numberFactAlert = nil
  }
)
```

That is the basics of building and testing a feature in the Composable Architecture. There are _a lot_ more things to be explored, such as composition, modularity, adaptability, and complex effects. The [Examples](./Examples) directory has a bunch of projects to explore to see more advanced usages.

## Installation

You can add ComposableArchitecture to an Xcode project by adding it as a package dependency.

> https://github.com/pointfreeco/swift-composable-architecture

## Credits and Thanks

The following people gave feedback on the library at its early stages and helped make the library what it is today:

Paul Colton, Kaan Dedeoglu, Matt Diephouse, Josef Doležal, Eimantas, Matthew Johnson, George Kaimakas, Nikita Leonov, Christopher Liscio, Jeffrey Macko, Shai Mishali, Willis Plummer, Simon-Pierre Roy, Justin Price, Sven A. Schmidt, Kyle Sherman, Petr Sima, Jasdev Singh, Maxim Smirnov, Ryan Stone, Daniel Hollis Tavares, and all of the [Point-Free](https://www.pointfree.co) subscribers 😁.

Special thanks to [Chris Liscio](http://twitter.com/liscio) who helped us work through many strange SwiftUI quirks and helped refine the final API.

And thanks to [Shai Mishali](https://github.com/freak4pc) and the [CombineCommunity](https://github.com/CombineCommunity/CombineExt/) project, from which we took their implementation of `Publishers.Create`, which we use in `Effect` to help bridge delegate and callback-based APIs, making it much easier to interface with 3rd party frameworks.

## Other libraries

The Composable Architecture was built on a foundation of ideas started by other libraries, in particular [Elm](https://elm-lang.org) and [Redux](http://redux.js.org).

There are also many architecture libraries in the Swift and iOS community. Each one of these has their own set of priorities and trade-offs that differ from the Composable Architecture.

* [RIBs](http://github.com/uber/RIBs)
* [ReSwift](https://github.com/ReSwift/ReSwift)
* [Workflow](http://github.com/square/workflow)
* [ReactorKit](https://github.com/ReactorKit/ReactorKit)
* [RxFeedback](https://github.com/NoTests/RxFeedback.swift)
* [Mobius.swift](http://github.com/spotify/mobius.swift)
* [ReactiveFeedback](http://github.com/babylonhealth/ReactiveFeedback)

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
