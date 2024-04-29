# The Composable Architecture

[![CI](https://github.com/pointfreeco/swift-composable-architecture/workflows/CI/badge.svg)](https://github.com/pointfreeco/swift-composable-architecture/actions?query=workflow%3ACI)
[![Slack](https://img.shields.io/badge/slack-chat-informational.svg?label=Slack&logo=slack)](https://www.pointfree.co/slack-invite)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpointfreeco%2Fswift-composable-architecture%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/pointfreeco/swift-composable-architecture)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpointfreeco%2Fswift-composable-architecture%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/pointfreeco/swift-composable-architecture)

The Composable Architecture (TCA, for short) is a library for building applications in a consistent 
and understandable way, with composition, testing, and ergonomics in mind. It can be used in 
SwiftUI, UIKit, and more, and on any Apple platform (iOS, macOS, tvOS, and watchOS).

* [What is the Composable Architecture?](#what-is-the-composable-architecture)
* [Learn more](#learn-more)
* [Examples](#examples)
* [Basic usage](#basic-usage)
* [Documentation](#documentation)
* [Community](#community)
* [Installation](#installation)
* [Translations](#translations)

## What is the Composable Architecture?

This library provides a few core tools that can be used to build applications of varying purpose and 
complexity. It provides compelling stories that you can follow to solve many problems you encounter 
day-to-day when building applications, such as:

* **State management**
  <br> How to manage the state of your application using simple value types, and share state across 
  many screens so that mutations in one screen can be immediately observed in another screen.

* **Composition**
  <br> How to break down large features into smaller components that can be extracted to their own, 
  isolated modules and be easily glued back together to form the feature.

* **Side effects**
  <br> How to let certain parts of the application talk to the outside world in the most testable 
  and understandable way possible.

* **Testing**
  <br> How to not only test a feature built in the architecture, but also write integration tests 
  for features that have been composed of many parts, and write end-to-end tests to understand how 
  side effects influence your application. This allows you to make strong guarantees that your 
  business logic is running in the way you expect.

* **Ergonomics**
  <br> How to accomplish all of the above in a simple API with as few concepts and moving parts as 
  possible.

## Learn More

The Composable Architecture was designed over the course of many episodes on 
[Point-Free][pointfreeco], a video series exploring functional programming and the Swift language, 
hosted by [Brandon Williams][mbrandonw] and [Stephen Celis][stephencelis].

You can watch all of the episodes [here][tca-episode-collection], as well as a dedicated, [multipart
tour][tca-tour] of the architecture from scratch.

<a href="https://www.pointfree.co/collections/tours/composable-architecture-1-0">
  <img alt="video poster image" src="https://d3rccdn33rt8ze.cloudfront.net/episodes/0243.jpeg" width="600">
</a>

## Examples

[![Screen shots of example applications](https://d3rccdn33rt8ze.cloudfront.net/composable-architecture/demos.png)](./Examples)

This repo comes with _lots_ of examples to demonstrate how to solve common and complex problems with 
the Composable Architecture. Check out [this](./Examples) directory to see them all, including:

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
* [SyncUps app](./Examples/SyncUps)
* [Tic-Tac-Toe](./Examples/TicTacToe)
* [Todos](./Examples/Todos)
* [Voice memos](./Examples/VoiceMemos)

Looking for something more substantial? Check out the source code for [isowords][gh-isowords], an 
iOS word search game built in SwiftUI and the Composable Architecture.

## Basic Usage

> [!Note] 
> For a step-by-step interactive tutorial, be sure to check out [Meet the Composable
> Architecture][meet-tca].

To build a feature using the Composable Architecture you define some types and values that model 
your domain:

* **State**: A type that describes the data your feature needs to perform its logic and render its 
UI.
* **Action**: A type that represents all of the actions that can happen in your feature, such as 
user actions, notifications, event sources and more.
* **Reducer**: A function that describes how to evolve the current state of the app to the next 
state given an action. The reducer is also responsible for returning any effects that should be 
run, such as API requests, which can be done by returning an `Effect` value.
* **Store**: The runtime that actually drives your feature. You send all user actions to the store 
so that the store can run the reducer and effects, and you can observe state changes in the store 
so that you can update UI.

The benefits of doing this are that you will instantly unlock testability of your feature, and you 
will be able to break large, complex features into smaller domains that can be glued together.

As a basic example, consider a UI that shows a number along with "+" and "−" buttons that increment 
and decrement the number. To make things interesting, suppose there is also a button that when 
tapped makes an API request to fetch a random fact about that number and displays it in the view.

To implement this feature we create a new type that will house the domain and behavior of the 
feature, and it will be annotated with the `@Reducer` macro:

```swift
import ComposableArchitecture

@Reducer
struct Feature {
}
```

In here we need to define a type for the feature's state, which consists of an integer for the 
current count, as well as an optional string that represents the fact being presented:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var numberFact: String?
  }
}
```

> [!Note] 
> We've applied the `@ObservableState` macro to `State` in order to take advantage of the
> observation tools in the library.

We also need to define a type for the feature's actions. There are the obvious actions, such as 
tapping the decrement button, increment button, or fact button. But there are also some slightly 
non-obvious ones, such as the action that occurs when we receive a response from the fact API 
request:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable { /* ... */ }
  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
    case numberFactButtonTapped
    case numberFactResponse(String)
  }
}
```

And then we implement the `body` property, which is responsible for composing the actual logic and 
behavior for the feature. In it we can use the `Reduce` reducer to describe how to change the
current state to the next state, and what effects need to be executed. Some actions don't need to
execute effects, and they can return `.none` to represent that:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable { /* ... */ }
  enum Action { /* ... */ }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        return .none

      case .incrementButtonTapped:
        state.count += 1
        return .none

      case .numberFactButtonTapped:
        return .run { [count = state.count] send in
          let (data, _) = try await URLSession.shared.data(
            from: URL(string: "http://numbersapi.com/\(count)/trivia")!
          )
          await send(
            .numberFactResponse(String(decoding: data, as: UTF8.self))
          )
        }

      case let .numberFactResponse(fact):
        state.numberFact = fact
        return .none
      }
    }
  }
}
```

And then finally we define the view that displays the feature. It holds onto a `StoreOf<Feature>` 
so that it can observe all changes to the state and re-render, and we can send all user actions to 
the store so that state changes:

```swift
struct FeatureView: View {
  let store: StoreOf<Feature>

  var body: some View {
    Form {
      Section {
        Text("\(store.count)")
        Button("Decrement") { store.send(.decrementButtonTapped) }
        Button("Increment") { store.send(.incrementButtonTapped) }
      }

      Section {
        Button("Number fact") { store.send(.numberFactButtonTapped) }
      }
      
      if let fact = store.numberFact {
        Text(fact)
      }
    }
  }
}
```

It is also straightforward to have a UIKit controller driven off of this store. You can observe
state changes in the store in `viewDidLoad`, and then populate the UI components with data from
the store. The code is a bit longer than the SwiftUI version, so we have collapsed it here:

<details>
  <summary>Click to expand!</summary>

  ```swift
  class FeatureViewController: UIViewController {
    let store: StoreOf<Feature>

    init(store: StoreOf<Feature>) {
      self.store = store
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()

      let countLabel = UILabel()
      let decrementButton = UIButton()
      let incrementButton = UIButton()
      let factLabel = UILabel()
      
      // Omitted: Add subviews and set up constraints...
      
      observe { [weak self] in
        guard let self 
        else { return }
        
        countLabel.text = "\(self.store.text)"
        factLabel.text = self.store.numberFact
      }
    }

    @objc private func incrementButtonTapped() {
      self.store.send(.incrementButtonTapped)
    }
    @objc private func decrementButtonTapped() {
      self.store.send(.decrementButtonTapped)
    }
    @objc private func factButtonTapped() {
      self.store.send(.numberFactButtonTapped)
    }
  }
  ```
</details>

Once we are ready to display this view, for example in the app's entry point, we can construct a 
store. This can be done by specifying the initial state to start the application in, as well as 
the reducer that will power the application:

```swift
import ComposableArchitecture

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      FeatureView(
        store: Store(initialState: Feature.State()) {
          Feature()
        }
      )
    }
  }
}
```

And that is enough to get something on the screen to play around with. It's definitely a few more 
steps than if you were to do this in a vanilla SwiftUI way, but there are a few benefits. It gives 
us a consistent manner to apply state mutations, instead of scattering logic in some observable 
objects and in various action closures of UI components. It also gives us a concise way of 
expressing side effects. And we can immediately test this logic, including the effects, without 
doing much additional work.

### Testing

> [!Note] 
> For more in-depth information on testing, see the dedicated [testing][testing-article] article. 

To test use a `TestStore`, which can be created with the same information as the `Store`, but it 
does extra work to allow you to assert how your feature evolves as actions are sent:

```swift
@MainActor
func testFeature() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  }
}
```

Once the test store is created we can use it to make an assertion of an entire user flow of steps. 
Each step of the way we need to prove that state changed how we expect. For example, we can 
simulate the user flow of tapping on the increment and decrement buttons:

```swift
// Test that tapping on the increment/decrement buttons changes the count
await store.send(.incrementButtonTapped) {
  $0.count = 1
}
await store.send(.decrementButtonTapped) {
  $0.count = 0
}
```

Further, if a step causes an effect to be executed, which feeds data back into the store, we must 
assert on that. For example, if we simulate the user tapping on the fact button we expect to 
receive a fact response back with the fact, which then causes the `numberFact` state to be 
populated:

```swift
await store.send(.numberFactButtonTapped)

await store.receive(\.numberFactResponse) {
  $0.numberFact = ???
}
```

However, how do we know what fact is going to be sent back to us?

Currently our reducer is using an effect that reaches out into the real world to hit an API server, 
and that means we have no way to control its behavior. We are at the whims of our internet 
connectivity and the availability of the API server in order to write this test.

It would be better for this dependency to be passed to the reducer so that we can use a live 
dependency when running the application on a device, but use a mocked dependency for tests. We can 
do this by adding a property to the `Feature` reducer:

```swift
@Reducer
struct Feature {
  let numberFact: (Int) async throws -> String
  // ...
}
```

Then we can use it in the `reduce` implementation:

```swift
case .numberFactButtonTapped:
  return .run { [count = state.count] send in 
    let fact = try await self.numberFact(count)
    await send(.numberFactResponse(fact))
  }
```

And in the entry point of the application we can provide a version of the dependency that actually 
interacts with the real world API server:

```swift
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      FeatureView(
        store: Store(initialState: Feature.State()) {
          Feature(
            numberFact: { number in
              let (data, _) = try await URLSession.shared.data(
                from: URL(string: "http://numbersapi.com/\(number)")!
              )
              return String(decoding: data, as: UTF8.self)
            }
          )
        }
      )
    }
  }
}
```

But in tests we can use a mock dependency that immediately returns a deterministic, predictable 
fact: 

```swift
@MainActor
func testFeature() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature(numberFact: { "\($0) is a good number Brent" })
  }
}
```

With that little bit of upfront work we can finish the test by simulating the user tapping on the 
fact button, and thenreceiving the response from the dependency to present the fact:

```swift
await store.send(.numberFactButtonTapped)

await store.receive(\.numberFactResponse) {
  $0.numberFact = "0 is a good number Brent"
}
```

We can also improve the ergonomics of using the `numberFact` dependency in our application. Over 
time the application may evolve into many features, and some of those features may also want access 
to `numberFact`, and explicitly passing it through all layers can get annoying. There is a process 
you can follow to “register” dependencies with the library, making them instantly available to any 
layer in the application.

> [!Note] 
> For more in-depth information on dependency management, see the dedicated
> [dependencies][dependencies-article] article. 

We can start by wrapping the number fact functionality in a new type:

```swift
struct NumberFactClient {
  var fetch: (Int) async throws -> String
}
```

And then registering that type with the dependency management system by conforming the client to
the `DependencyKey` protocol, which requires you to specify the live value to use when running the
application in simulators or devices:

```swift
extension NumberFactClient: DependencyKey {
  static let liveValue = Self(
    fetch: { number in
      let (data, _) = try await URLSession.shared
        .data(from: URL(string: "http://numbersapi.com/\(number)")!
      )
      return String(decoding: data, as: UTF8.self)
    }
  )
}

extension DependencyValues {
  var numberFact: NumberFactClient {
    get { self[NumberFactClient.self] }
    set { self[NumberFactClient.self] = newValue }
  }
}
```

With that little bit of upfront work done you can instantly start making use of the dependency in 
any feature by using the `@Dependency` property wrapper:

```diff
 @Reducer
 struct Feature {
-  let numberFact: (Int) async throws -> String
+  @Dependency(\.numberFact) var numberFact
   
   …

-  try await self.numberFact(count)
+  try await self.numberFact.fetch(count)
 }
```

This code works exactly as it did before, but you no longer have to explicitly pass the dependency 
when constructing the feature's reducer. When running the app in previews, the simulator or on a 
device, the live dependency will be provided to the reducer, and in tests the test dependency will 
be provided.

This means the entry point to the application no longer needs to construct dependencies:

```swift
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      FeatureView(
        store: Store(initialState: Feature.State()) {
          Feature()
        }
      )
    }
  }
}
```

And the test store can be constructed without specifying any dependencies, but you can still 
override any dependency you need to for the purpose of the test:

```swift
let store = TestStore(initialState: Feature.State()) {
  Feature()
} withDependencies: {
  $0.numberFact.fetch = { "\($0) is a good number Brent" }
}

// ...
```

That is the basics of building and testing a feature in the Composable Architecture. There are 
_a lot_ more things to be explored, such as composition, modularity, adaptability, and complex 
effects. The [Examples](./Examples) directory has a bunch of projects to explore to see more 
advanced usages.

## Documentation

The documentation for releases and `main` are available here:

* [`main`](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/)
* [1.10.0](https://pointfreeco.github.io/swift-composable-architecture/1.10.0/documentation/composablearchitecture/) ([migration guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.10))

<details>
  <summary>
  Other versions
  </summary>

  * [1.9.0](https://pointfreeco.github.io/swift-composable-architecture/1.9.0/documentation/composablearchitecture/) ([migration guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.9))
  * [1.8.0](https://pointfreeco.github.io/swift-composable-architecture/1.8.0/documentation/composablearchitecture/) ([migration guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.8))
  * [1.7.0](https://pointfreeco.github.io/swift-composable-architecture/1.7.0/documentation/composablearchitecture/) ([migration guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7))
  * [1.6.0](https://pointfreeco.github.io/swift-composable-architecture/1.6.0/documentation/composablearchitecture/) ([migration guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.6))
  * [1.5.0](https://pointfreeco.github.io/swift-composable-architecture/1.5.0/documentation/composablearchitecture/) ([migration guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5))
  * [1.4.0](https://pointfreeco.github.io/swift-composable-architecture/1.4.0/documentation/composablearchitecture/) ([migration guide](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4))
  * [1.3.0](https://pointfreeco.github.io/swift-composable-architecture/1.3.0/documentation/composablearchitecture/)
  * [1.2.0](https://pointfreeco.github.io/swift-composable-architecture/1.2.0/documentation/composablearchitecture/)
  * [1.1.0](https://pointfreeco.github.io/swift-composable-architecture/1.1.0/documentation/composablearchitecture/)
  * [1.0.0](https://pointfreeco.github.io/swift-composable-architecture/1.0.0/documentation/composablearchitecture/)
  * [0.59.0](https://pointfreeco.github.io/swift-composable-architecture/0.59.0/documentation/composablearchitecture/)
  * [0.58.0](https://pointfreeco.github.io/swift-composable-architecture/0.58.0/documentation/composablearchitecture/)
  * [0.57.0](https://pointfreeco.github.io/swift-composable-architecture/0.57.0/documentation/composablearchitecture/)
</details>

<br>

There are a number of articles in the documentation that you may find helpful as you become more 
comfortable with the library:

* [Getting started][getting-started-article]
* [Dependencies][dependencies-article]
* [Testing][testing-article]
* [Navigation][navigation-article]
* [Sharing state][sharing-state-article]
* [Performance][performance-article]
* [Concurrency][concurrency-article]
* [Bindings][bindings-article]

## Community

If you want to discuss the Composable Architecture or have a question about how to use it to solve 
a particular problem, there are a number of places you can discuss with fellow 
[Point-Free](http://www.pointfree.co) enthusiasts:

* For long-form discussions, we recommend the [discussions][gh-discussions] tab of this repo.
* For casual chat, we recommend the [Point-Free Community slack](http://pointfree.co/slack-invite).

## Installation

You can add ComposableArchitecture to an Xcode project by adding it as a package dependency.

  1. From the **File** menu, select **Add Package Dependencies...**
  2. Enter "https://github.com/pointfreeco/swift-composable-architecture" into the package 
     repository URL text field
  3. Depending on how your project is structured:
      - If you have a single application target that needs access to the library, then add 
        **ComposableArchitecture** directly to your application.
      - If you want to use this library from multiple Xcode targets, or mix Xcode targets and SPM 
        targets, you must create a shared framework that depends on **ComposableArchitecture** and 
        then depend on that framework in all of your targets. For an example of this, check out the 
        [Tic-Tac-Toe](./Examples/TicTacToe) demo application, which splits lots of features into 
        modules and consumes the static library in this fashion using the **tic-tac-toe** Swift 
        package.

## Companion libraries

The Composable Architecture is built with extensibility in mind, and there are a number of
community-supported libraries available to enhance your applications:

* [Composable Architecture Extras](https://github.com/Ryu0118/swift-composable-architecture-extras):
  A companion library to the Composable Architecture.
* [TCAComposer](https://github.com/mentalflux/tca-composer): A macro framework for generating
  boiler-plate code in the Composable Architecture.
* [TCACoordinators](https://github.com/johnpatrickmorgan/TCACoordinators): The coordinator pattern
  in the Composable Architecture.

If you'd like to contribute a library, please [open a
PR](https://github.com/pointfreeco/swift-composable-architecture/edit/main/README.md) with a link
to it!

## Translations

The following translations of this README have been contributed by members of the community:

* [Arabic](https://gist.github.com/NorhanBoghdadi/1b98d55c02b683ddef7e05c2ebcccd47)
* [French](https://gist.github.com/nikitamounier/0e93eb832cf389db12f9a69da030a2dc)
* [Hindi](https://gist.github.com/akashsoni01/b358ee0b3b747167964ef6946123c88d)
* [Indonesian](https://gist.github.com/wendyliga/792ea9ac5cc887f59de70a9e39cc7343)
* [Italian](https://gist.github.com/Bellaposa/5114e6d4d55fdb1388e8186886d48958)
* [Japanese](https://gist.github.com/Achoo-kr/2d0712deb77f78b3379551ac7baea3e4)
* [Korean](https://gist.github.com/Achoo-kr/5d8936d12e71028fcc4a7c5e078ca038)
* [Polish](https://gist.github.com/MarcelStarczyk/6b6153051f46912a665c32199f0d1d54)
* [Portuguese](https://gist.github.com/SevioCorrea/2bbf337cd084a58c89f2f7f370626dc8)
* [Russian](https://gist.github.com/artyom-ivanov/ed0417fd1f008f0492d3431c033175df)
* [Simplified Chinese](https://gist.github.com/sh3l6orrr/10c8f7c634a892a9c37214f3211242ad)
* [Spanish](https://gist.github.com/pitt500/f5e32fccb575ce112ffea2827c7bf942)
* [Ukrainian](https://gist.github.com/barabashd/33b64676195ce41f4bb73c327ea512a8)

If you'd like to contribute a translation, please [open a
PR](https://github.com/pointfreeco/swift-composable-architecture/edit/main/README.md) with a link 
to a [Gist](https://gist.github.com)!

## FAQ

* How does the Composable Architecture compare to Elm, Redux, and others?
  <details>
    <summary>Expand to see answer</summary>
    The Composable Architecture (TCA) is built on a foundation of ideas popularized by the Elm 
    Architecture (TEA) and Redux, but made to feel at home in the Swift language and on Apple's 
    platforms.

    In some ways TCA is a little more opinionated than the other libraries. For example, Redux is 
    not prescriptive with how one executes side effects, but TCA requires all side effects to be 
    modeled in the `Effect` type and returned from the reducer.

    In other ways TCA is a little more lax than the other libraries. For example, Elm controls what 
    kinds of effects can be created via the `Cmd` type, but TCA allows an escape hatch to any kind 
    of effect since `Effect` wraps around an async operation.

    And then there are certain things that TCA prioritizes highly that are not points of focus for 
    Redux, Elm, or most other libraries. For example, composition is very important aspect of TCA, 
    which is the process of breaking down large features into smaller units that can be glued 
    together. This is accomplished with reducer builders and operators like `Scope`, and it aids in 
    handling complex features as well as modularization for a better-isolated code base and improved 
    compile times.
  </details>

## Credits and thanks

The following people gave feedback on the library at its early stages and helped make the library 
what it is today:

Paul Colton, Kaan Dedeoglu, Matt Diephouse, Josef Doležal, Eimantas, Matthew Johnson, George 
Kaimakas, Nikita Leonov, Christopher Liscio, Jeffrey Macko, Alejandro Martinez, Shai Mishali, Willis 
Plummer, Simon-Pierre Roy, Justin Price, Sven A. Schmidt, Kyle Sherman, Petr Šíma, Jasdev Singh, 
Maxim Smirnov, Ryan Stone, Daniel Hollis Tavares, and all of the [Point-Free][pointfreeco] 
subscribers 😁.

Special thanks to [Chris Liscio](https://twitter.com/liscio) who helped us work through many strange 
SwiftUI quirks and helped refine the final API.

And thanks to [Shai Mishali](https://github.com/freak4pc) and the
[CombineCommunity](https://github.com/CombineCommunity/CombineExt/) project, from which we took 
their implementation of `Publishers.Create`, which we use in `Effect` to help bridge delegate and 
callback-based APIs, making it much easier to interface with 3rd party frameworks.

## Other libraries

The Composable Architecture was built on a foundation of ideas started by other libraries, in 
particular [Elm](https://elm-lang.org) and [Redux](https://redux.js.org/).

There are also many architecture libraries in the Swift and iOS community. Each one of these has 
their own set of priorities and trade-offs that differ from the Composable Architecture.

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

[pointfreeco]: https://www.pointfree.co
[mbrandonw]: https://twitter.com/mbrandonw
[stephencelis]: https://twitter.com/stephencelis
[tca-episode-collection]: https://www.pointfree.co/collections/composable-architecture
[tca-tour]: https://www.pointfree.co/collections/tours/composable-architecture-1-0
[gh-isowords]: https://github.com/pointfreeco/isowords
[gh-discussions]: https://github.com/pointfreeco/swift-composable-architecture/discussions
[swift-forum]: https://forums.swift.org/c/related-projects/swift-composable-architecture
[testing-article]: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/testing
[dependencies-article]: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/dependencymanagement
[getting-started-article]: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/gettingstarted
[navigation-article]: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/navigation
[performance-article]: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/performance
[concurrency-article]: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/swiftconcurrency
[bindings-article]: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/bindings
[sharing-state-article]: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/sharingstate
[meet-tca]: https://pointfreeco.github.io/swift-composable-architecture/main/tutorials/meetcomposablearchitecture
