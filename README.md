# The Composable Architecture

[![Swift 5.2](https://img.shields.io/badge/swift-5.2-ED523F.svg?style=flat)](https://swift.org/download/)
[![Swift 5.1](https://img.shields.io/badge/swift-5.1-ED523F.svg?style=flat)](https://swift.org/download/)
[![CI](https://github.com/pointfreeco/swift-composable-architecture/workflows/CI/badge.svg)](https://github.com/pointfreeco/swift-composable-architecture/actions?query=workflow%3ACI)
[![@pointfreeco](https://img.shields.io/badge/contact-@pointfreeco-5AA9E7.svg?style=flat)](https://twitter.com/pointfreeco)

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
  <img alt="video poster image" src="https://i.vimeocdn.com/video/850265054.jpg" width="600">
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
* [Location manager](./Examples/LocationManager)
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
* **Reducer**: A function that describes how to evolve the current state of the app to the next state given an action. The reducer is also responsible for returning any effects that should be run, such as API requests, which can be done by returning an `Effect` value.
* **Store**: The runtime that actually drives your feature. You send all user actions to the store so that the store can run the reducer and effects, and you can observe state changes in the store so that you can update UI.

The benefits of doing this is that you will instantly unlock testability of your feature, and you will be able to break large, complex features into smaller domains that can be glued together.

As a basic example, consider a UI that shows a number along with "+" and "−" buttons that increment and decrement the number. To make things interesting, suppose there is also a button that when tapped makes an API request to fetch a random fact about that number and then displays the fact in an alert.

The state of this feature would consist of an integer for the current count, as well as an optional string that represents the title of the alert we want to show (optional because `nil` represents not showing an alert):

```swift
struct AppState: Equatable {
  var count = 0
  var numberFactAlert: String?
}
```

Next we have the actions in the feature. There are the obvious actions, such as tapping the decrement button, increment button, or fact button. But there are also some slightly non-obvious ones, such as the action of the user dismissing the alert, and the action that occurs when we receive a response from the fact API request:

```swift
enum AppAction: Equatable {
  case factAlertDismissed
  case decrementButtonTapped
  case incrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(Result<String, ApiError>)
}

struct ApiError: Error, Equatable {}
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
      .catchToEffect()
      .map(AppAction.numberFactResponse)

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

### Testing

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

### Debugging

The Composable Architecture comes with a number of tools to aid in debugging.

* `reducer.debug()` enhances a reducer with debug-printing that describes every action the reducer receives and every mutation it makes to state.

    ``` diff
    received action:
      AppAction.todoCheckboxTapped(
        index: 0
      )
      AppState(
        todos: [
          Todo(
    -       isComplete: false,
    +       isComplete: true,
            description: "Milk",
            id: 5834811A-83B4-4E5E-BCD3-8A38F6BDCA90
          ),
          Todo(
            isComplete: false,
            description: "Eggs",
            id: AB3C7921-8262-4412-AA93-9DC5575C1107
          ),
          Todo(
            isComplete: true,
            description: "Hand Soap",
            id: 06E94D88-D726-42EF-BA8B-7B4478179D19
          ),
        ]
      )
    ```

* `reducer.signpost()` instruments a reducer with signposts so that you can gain insight into how long actions take to execute, and when effects are running.

    <img src="https://s3.amazonaws.com/pointfreeco-production/point-free-pointers/0044-signposts-cover.jpg" width="600">

## Supplementary libraries

One of the most important principles of the Composable Architecture is that side effects are never performed directly, but instead are wrapped in the `Effect` type, returned from reducers, and then the `Store` later performs the effect. This is crucial for simplifying how data flows through an application, and for gaining testability on the full end-to-end cycle of user action to effect execution.

However, this also means that many libraries and SDKs you interact with on a daily basis need to be retrofitted to be a little more friendly to the Composable Architecture style. That's why we'd like to ease the pain of using some of Apple's most popular frameworks by providing wrapper libraries that expose their functionality in a way that plays nicely with our library. So far we support:

* [`ComposableCoreLocation`](./Sources/ComposableCoreLocation/): A wrapper around `CLLocationManager` that makes it easy to use from a reducer, and easy to write tests for how your logic interacts with `CLLocationManager`'s functionality.
* [`ComposableCoreMotion`](./Sources/ComposableCoreMotion/): A wrapper around `CMMotionManager` that makes it easy to use from a reducer, and easy to write tests for how your logic interacts with `CMMotionManager`'s functionality.
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

* Why isn't `Store` thread-safe? <br> Why isn't `send` queued? <br> Why isn't `send` run on the main thread?
  <details>
    <summary>Expand to see answer</summary>

    When an action is sent to the `Store`, a reducer is run on the current state, and this process cannot be done from multiple threads. A possible work around is to use a queue in `send`s implementation, but this introduces a few new complications:

    1. If done simply with `DispatchQueue.main.async` you will incur a thread hop even when you are already on the main thread. This can lead to unexpected behavior in UIKit and SwiftUI, where sometimes you are required to do work synchronously, such as in animation blocks.

    2. It is possible to create a scheduler that performs its work immediately when on the main thread and otherwise uses `DispatchQueue.main.async` (_e.g._ see ReactiveSwift's [`UIScheduler`](https://github.com/ReactiveCocoa/ReactiveSwift/blob/f97db218c0236b0c6ef74d32adb3d578792969c0/Sources/Scheduler.swift)). This introduces a lot more complexity, and should probably not be adopted without having a very good reason.

    At the end of the day, we require `Store` to be used in much the same way that you interact with Apple's APIs. Just as `URLSession` delivers its results on a background thread, thus making you responsible for dispatching back to the main thread, the Composable Architecture makes you responsible for making sure to send actions on the main thread. If you are using an effect that may deliver its output on a non-main thread, you must explicitly perform `.receive(on:)` in order to force it back on the main thread.

    This approach makes the fewest number of assumptions about how effects are created and transformed, and prevents unnecessary thread hops and re-dispatching. It also provides some testing benefits. If your effects are not responsible for their own scheduling, then in tests all of the effects would run synchronously and immediately. You would not be able to test how multiple in-flight effects interleave with each other and affect the state of your application. However, by leaving scheduling out of the `Store` we get to test these aspects of our effects if we so desire, or we can ignore if we prefer. We have that flexibility.

    However, if you are still not a fan of our choice, then never fear! The Composable Architecture is flexible enough to allow you to introduce this functionality yourself if you so desire. It is possible to create a higher-order reducer that can force all effects to deliver their output on the main thread, regardless of where the effect does its work:

    ```swift
    extension Reducer {
      func receive<S: Scheduler>(on scheduler: S) -> Self {
        Self { state, action, environment in
          self(&state, action, environment)
            .receive(on: scheduler)
            .eraseToEffect()
        }
      }
    }
    ```

    You would probably still want something like a `UIScheduler` so that you don't needlessly perform thread hops.
  </details>

## Requirements

The Composable Architecture depends on the Combine framework, so it requires minimum deployment targets of iOS 13, macOS 10.15, Mac Catalyst 13, tvOS 13, and watchOS 6. If your application must support older OSes, there are forks for [ReactiveSwift](https://github.com/trading-point/reactiveswift-composable-architecture) and [RxSwift](https://github.com/dannyhertz/rxswift-composable-architecture) that you can adopt!

## Installation

You can add ComposableArchitecture to an Xcode project by adding it as a package dependency.

  1. From the **File** menu, select **Swift Packages › Add Package Dependency…**
  2. Enter "https://github.com/pointfreeco/swift-composable-architecture" into the package repository URL text field
  3. Depending on how your project is structured:
      - If you have a single application target that needs access to the library, then add **ComposableArchitecture** directly to your application.
      - If you want to use this library from multiple targets you must create a shared framework that depends on **ComposableArchitecture** and then depend on that framework in all of your targets. For an example of this, check out the [Tic-Tac-Toe](./Examples/TicTacToe) demo application, which splits lots of features into modules and consumes the static library in this fashion using the **TicTacToeCommon** framework.

## Documentation

The latest documentation for the Composable Architecture APIs is available [here](https://pointfreeco.github.io/swift-composable-architecture/).

## Help

If you want to discuss the Composable Architecture or have a question about how to use it to solve a particular problem, ask around on [its Swift forum](https://forums.swift.org/c/related-projects/swift-composable-architecture).

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
