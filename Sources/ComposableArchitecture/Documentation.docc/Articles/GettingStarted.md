# Getting started

Learn how to integrate the Composable Architecture into your project and write your first 
application.

## Adding the Composable Architecture as a dependency

To use the Composable Architecture in a SwiftPM project, add it to the dependencies of your
Package.swift and specify the `ComposableArchitecture` product in any targets that need access to 
the library:

```swift
let package = Package(
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      from: "1.0.0"
    ),
  ],
  targets: [
    .target(
      name: "<target-name>",
      dependencies: [
        .product(
          name: "ComposableArchitecture",
          package: "swift-composable-architecture"
        )
      ]
    )
  ]
)
```

## Writing your first feature

> Note: For a step-by-step interactive tutorial, be sure to check out 
> <doc:MeetComposableArchitecture>.

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
    so that the store can run the reducer and effects, and you can observe state changes in the
    store so that you can update UI.

The benefits of doing this are that you will instantly unlock testability of your feature, and you
will be able to break large, complex features into smaller domains that can be glued together.

As a basic example, consider a UI that shows a number along with "+" and "−" buttons that increment 
and decrement the number. To make things interesting, suppose there is also a button that when 
tapped makes an API request to fetch a random fact about that number and displays it in the view.

To implement this feature we create a new type that will house the domain and behavior of the 
feature, and it will be annotated with the [`@Reducer`](<doc:Reducer()>) macro:

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

> Note: We've applied the `@ObservableState` macro to `State` in order to take advantage of the
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

## Testing your feature

> Note: For more in-depth information on testing, see the dedicated <doc:Testing> 
article.

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

> Note: For more in-depth information on dependency management, see the dedicated
<doc:DependencyManagement> article. 

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
_a lot_ more things to be explored. Be sure to check out the <doc:MeetComposableArchitecture> 
tutorial, as well as dedicated articles on <doc:DependencyManagement>, <doc:Testing>, 
<doc:Navigation>, <doc:Performance>, and more. Also, the [Examples][examples] directory has 
a bunch of projects to explore to see more advanced usages.

[examples]: https://github.com/pointfreeco/swift-composable-architecture/tree/main/Examples
