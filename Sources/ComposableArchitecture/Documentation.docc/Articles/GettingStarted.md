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
      from: "0.42.0"
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

To build a feature using the Composable Architecture you define some types and values that model
your domain:

* **State**: A type that describes the data your feature needs to perform its logic and render its
    UI.
* **Action**: A type that represents all of the actions that can happen in your feature, such as
    user actions, notifications, event sources and more.
* **Reducer**: A function that describes how to evolve the current state of the app to the next
    state given an action. The reducer is also responsible for returning any effects that should be
    run, such as API requests, which can be done by returning an `EffectTask` value.
* **Store**: The runtime that actually drives your feature. You send all user actions to the store
    so that the store can run the reducer and effects, and you can observe state changes in the
    store so that you can update UI.

The benefits of doing this are that you will instantly unlock testability of your feature, and you
will be able to break large, complex features into smaller domains that can be glued together.

As a basic example, consider a UI that shows a number along with "+" and "−" buttons that increment 
and decrement the number. To make things interesting, suppose there is also a button that when 
tapped makes an API request to fetch a random fact about that number and then displays the fact in 
an alert.

To implement this feature we create a new type that will house the domain and behavior of the 
feature by conforming to ``ReducerProtocol``:

```swift
struct Feature: ReducerProtocol {
}
```

In here we need to define a type for the feature's state, which consists of an integer for the 
current count, as well as an optional string that represents the title of the alert we want to show 
(optional because `nil` represents not showing an alert):

```swift
struct Feature: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var numberFactAlert: String?
  }
}
```

We also need to define a type for the feature's actions. There are the obvious actions, such as 
tapping the decrement button, increment button, or fact button. But there are also some slightly 
non-obvious ones, such as the action of the user dismissing the alert, and the action that occurs 
when we receive a response from the fact API request:

```swift
struct Feature: ReducerProtocol {
  struct State: Equatable { … }
  enum Action: Equatable {
    case factAlertDismissed
    case decrementButtonTapped
    case incrementButtonTapped
    case numberFactButtonTapped
    case numberFactResponse(TaskResult<String>)
  }
}
```

And then we implement the ``ReducerProtocol/reduce(into:action:)-8yinq`` method which is responsible 
for handling the actual logic and  behavior for the feature. It describes how to change the current 
state to the next state, and describes what effects need to be executed. Some actions don't need to 
execute effects, and they can return `.none` to represent that:

```swift
struct Feature: ReducerProtocol {
  struct State: Equatable { … }
  enum Action: Equatable { … }
  
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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
        return .task { [count = state.count] in 
          await .numberFactResponse(
            TaskResult { 
              String(
                decoding: try await URLSession.shared
                  .data(from: URL(string: "http://numbersapi.com/\(count)/trivia")!).0,
                as: UTF8.self
              )
            }
          )
        }

      case let .numberFactResponse(.success(fact)):
        state.numberFactAlert = fact
        return .none

      case .numberFactResponse(.failure):
        state.numberFactAlert = "Could not load a number fact :("
        return .none
      } 
    }
  }
}
```

And then finally we define the view that displays the feature. It holds onto a `StoreOf<Feature>` 
so that it can observe all changes to the state and re-render, and we can send all user actions to 
the store so that state changes. We must also introduce a struct wrapper around the fact alert to 
make it `Identifiable`, which the `.alert` view modifier requires:

```swift
struct FeatureView: View {
  let store: StoreOf<Feature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
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

It is also straightforward to have a UIKit controller driven off of this store. You subscribe to the 
store in `viewDidLoad` in order to update the UI and show alerts. The code is a bit longer than the 
SwiftUI version:

```swift
class FeatureViewController: UIViewController {
  let viewStore: ViewStoreOf<Feature>
  var cancellables: Set<AnyCancellable> = []

  init(store: StoreOf<Feature>) {
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

Once we are ready to display this view, for example in the app's entry point, we can construct a 
store. This can be done by specifying the initial state to start the application in, as well as the 
reducer that will power the application:

```swift
@main
struct MyApp: App {
  var body: some Scene {
    FeatureView(
      store: Store(
        initialState: Feature.State(),
        reducer: Feature()
      )
    )
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

To test use a ``TestStore``, which can be created with the same information as the ``Store``, but it 
does extra work to allow you to assert how your feature evolves as actions are sent:

```swift
@MainActor
func testFeature() async {
  let store = TestStore(
    initialState: Feature.State(),
    reducer: Feature()
  )
}
```

Once the test store is created we can use it to make an assertion of an entire user flow of steps. 
Each step of the way we need to prove that state changed how we expect. For example, we can simulate 
the user flow of tapping on the increment and decrement buttons:

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
receive a fact response back with the fact, which then causes the alert to show:

```swift
await store.send(.numberFactButtonTapped)

await store.receive(.numberFactResponse(.success("???"))) {
  $0.numberFactAlert = "???"
}
```

However, how do we know what fact is going to be sent back to us?

Currently our reducer is using an effect that reaches out into the real world to hit an API server, 
and that means we have no way to control its behavior. We are at the whims of our internet 
connectivity and the availability of the API server in order to write this test.

It would be better for this dependency to be passed to the reducer so that we can use a live 
dependency when running the application on a device, but use a mocked dependency for tests. We 
can do this by adding a property to the `Feature` reducer:

```swift
struct Feature: ReducerProtocol {
  let numberFact: (Int) async throws -> String
  …
}
```

Then we can use it in the `reduce` implementation:

```swift
case .numberFactButtonTapped:
  return .task { [count = state.count] in 
    await .numberFactResponse(TaskResult { try wait self.numberFact(count) })
  }
```

And in the entry point of the application we can provide a version of the dependency that actually 
interacts with the real world API server:

```swift
@main
struct MyApp: App {
  var body: some Scene {
    FeatureView(
      store: Store(
        initialState: Feature.State(),
        reducer: Feature(
          numberFact: { number in
            let (data, _) = try await URLSession.shared
              .data(from: .init(string: "http://numbersapi.com/\(number)")!)
            return String(decoding: data, as: UTF8.self)
          }
        )
      )
    )
  }
}
```

But in tests we can use a mock dependency that immediately returns a deterministic, predictable fact: 

```swift
@MainActor
func testFeature() async {
  let store = TestStore(
    initialState: Feature.State(),
    reducer: Feature(
      numberFact: { "\($0) is a good number Brent" }
    )
  )
}
```

With that little bit of upfront work we can finish the test by simulating the user tapping on the 
fact button, receiving the response from the dependency to trigger the alert, and then dismissing 
the alert:

```swift
await store.send(.numberFactButtonTapped)

await store.receive(.numberFactResponse(.success("0 is a good number Brent"))) {
  $0.numberFactAlert = "0 is a good number Brent"
}

await store.send(.factAlertDismissed) {
  $0.numberFactAlert = nil
}
```

We can also improve the ergonomics of using the `numberFact` dependency in our application. Over 
time the application may evolve into many features, and some of those features may also want access 
to `numberFact`, and explicitly passing it through all layers can get annoying. There is a process 
you can follow to “register” dependencies with the library, making them instantly available to any 
layer in the application.

We can start by wrapping the number fact functionality in a new type:

```swift
struct NumberFactClient {
  var fetch: (Int) async throws -> String
}
```

And then registering that type with the dependency management system, which is quite similar to 
how SwiftUI's environment values works, except you specify the live implementation of the 
dependency to be used by default:

```swift
private enum NumberFactClientKey: DependencyKey {
  static let liveValue = NumberFactClient(
    fetch: { number in
      let (data, _) = try await URLSession.shared
        .data(from: .init(string: "http://numbersapi.com/\(number)")!)
      return String(decoding: data, as: UTF8.self)
    }
  )
}

extension DependencyValues {
  var numberFact: NumberFactClient {
    get { self[NumberFactClientKey.self] }
    set { self[NumberFactClientKey.self] = newValue }
  }
}
```

With that little bit of upfront work done you can instantly start making use of the dependency in 
any feature:

```swift
struct Feature: ReducerProtocol {
  struct State { … }
  enum Action { … }
  @Dependency(\.numberFact) var numberFact
  …
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
    FeatureView(
      store: Store(
        initialState: Feature.State(),
        reducer: Feature()
      )
    )
  }
}
```

And the test store can be constructed without specifying any dependencies, but you can still 
override any dependency you need to for the purpose of the test:

```swift
let store = TestStore(
  initialState: Feature.State(),
  reducer: Feature()
)

store.dependencies.numberFact.fetch = { "\($0) is a good number Brent" }

await store.send(.numberFactButtonTapped)
await store.receive(.numberFactResponse(.success("0 is a good number Brent"))) {
  $0.numberFactAlert = "0 is a good number Brent"
}
```

That is the basics of building and testing a feature in the Composable Architecture. There are 
_a lot_ more things to be explored, such as <doc:DependencyManagement>, <doc:Performance>,
<doc:SwiftConcurrency> and more about <doc:Testing>. Also, the [Examples][examples] directory has 
a bunch of projects to explore to see more advanced usages.

[examples]: https://github.com/pointfreeco/swift-composable-architecture/tree/main/Examples
