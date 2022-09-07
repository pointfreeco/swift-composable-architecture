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
      from: "0.39.0"
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
* **Environment**: A type that holds any dependencies the feature needs, such as API clients,
    analytics clients, etc.
* **Reducer**: A function that describes how to evolve the current state of the app to the next
    state given an action. The reducer is also responsible for returning any effects that should be
    run, such as API requests, which can be done by returning an `Effect` value.
* **Store**: The runtime that actually drives your feature. You send all user actions to the store
    so that the store can run the reducer and effects, and you can observe state changes in the
    store so that you can update UI.

The benefits of doing this is that you will instantly unlock testability of your feature, and you
will be able to break large, complex features into smaller domains that can be glued together.

As a basic example, consider a UI that shows a number along with "+" and "−" buttons that increment
and decrement the number. To make things interesting, suppose there is also a button that when
tapped makes an API request to fetch a random fact about that number and then displays the fact in
an alert.

The state of this feature would consist of an integer for the current count, as well as an optional
string that represents the title of the alert we want to show (optional because `nil` represents not
showing an alert):

```swift
struct AppState: Equatable {
  var count = 0
  var numberFactAlert: String?
}
```

Next we have the actions in the feature. There are the obvious actions, such as tapping the
decrement button, increment button, or fact button. But there are also some slightly non-obvious
ones, such as the action of the user dismissing the alert, and the action that occurs when we
receive a response from the fact API request:

```swift
enum AppAction: Equatable {
  case factAlertDismissed
  case decrementButtonTapped
  case incrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(TaskResult<String>)
}
```

Next we model the environment of dependencies this feature needs to do its job. In particular, to 
fetch a number fact we can model an async throwing function from `Int` to `String`:

```swift
struct AppEnvironment {
  var numberFact: (Int) async throws -> String
}
```

Next, we implement a reducer that implements the logic for this domain. It describes how to change
the current state to the next state, and describes what effects need to be executed. Some actions
don't need to execute effects, and they can return `.none` to represent that:

```swift
let appReducer = Reducer<
  AppState,
  AppAction,
  AppEnvironment
> { state, action, environment in
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
        TaskResult { try await environment.numberFact(count) }
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
```

And then finally we define the view that displays the feature. It holds onto a
`Store<AppState, AppAction>` so that it can observe all changes to the state and re-render, and we
can send all user actions to the store so that state changes. We must also introduce a struct
wrapper around the fact alert to make it `Identifiable`, which the `.alert` view modifier requires:

```swift
struct AppView: View {
  let store: Store<AppState, AppAction>

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

It's important to note that we were able to implement this entire feature without having a real,
live effect at hand. This is important because it means features can be built in isolation without
building their dependencies, which can help compile times.

Once we are ready to display this view, for example in the app's entry point, we can construct a 
store. This is the moment where we need to supply the dependencies, including the `numberFact` 
endpoint that actually reaches out into the real world to fetch the fact:

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
```

And that is enough to get something on the screen to play around with. It's definitely a few more
steps than if you were to do this in a vanilla SwiftUI way, but there are a few benefits. It gives
us a consistent manner to apply state mutations, instead of scattering logic in some observable
objects and in various action closures of UI components. It also gives us a concise way of
expressing side effects. And we can immediately test this logic, including the effects, without
doing much additional work.

## Testing your feature

To test, you first create a `TestStore` with the same information that you would to create a regular
`Store`, except this time we can supply test-friendly dependencies. In particular, we can now use a 
`numberFact` implementation that immediately returns a value we control rather than reaching out 
into the real world:

```swift
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

Once the test store is created we can use it to make an assertion of an entire user flow of steps.
Each step of the way we need to prove that state changed how we expect. Further, if a step causes an
effect to be executed, which feeds data back into the store, we must assert that those actions were
received properly.

The test below has the user increment and decrement the count, then they ask for a number fact, and
the response of that effect triggers an alert to be shown, and then dismissing the alert causes the
alert to go away.

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

That is the basics of building and testing a feature in the Composable Architecture. There are _a
lot_ more things to be explored, such as composition, modularity, adaptability, and complex effects.
