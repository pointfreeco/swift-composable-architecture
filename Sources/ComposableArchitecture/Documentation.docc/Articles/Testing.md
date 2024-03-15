# Testing

Learn how to write comprehensive and exhaustive tests for your features built in the Composable
Architecture.

The testability of features built in the Composable Architecture is the #1 priority of the library.
It should be possible to test not only how state changes when actions are sent into the store, but
also how effects are executed and feed data back into the system.

* [Testing state changes][Testing-state-changes]
* [Testing effects][Testing-effects]
* [Non-exhaustive testing][Non-exhaustive-testing]
* [Testing gotchas](#Testing-gotchas)

## Testing state changes

State changes are by far the simplest thing to test in features built with the library. A
``Reducer``'s first responsibility is to mutate the current state based on the action received into
the system. To test this we can technically run a piece of mutable state through the reducer and
then assert on how it changed after, like this:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable {
    var count = 0
  }
  enum Action {
    case incrementButtonTapped
    case decrementButtonTapped
  }
  var body: some Reduce<State, Action> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.count += 1
        return .none
      case .decrementButtonTapped:
        state.count -= 1
        return .none
      }
    }
  }
}

func testBasics() {
  let feature = Feature()
  var currentState = Feature.State(count: 0)
  _ = feature.reduce(into: &currentState, action: .incrementButtonTapped)
  XCTAssertEqual(
    currentState,
    State(count: 1)
  )

  _ = feature.reduce(into: &currentState, action: .decrementButtonTapped)
  XCTAssertEqual(
    currentState,
    State(count: 0)
  )
}
```

This will technically work, but it's a lot boilerplate for something that should be quite simple.

The library comes with a tool specifically designed to make testing like this much simpler and more
concise. It's called ``TestStore``, and it is constructed similarly to ``Store`` by providing the
initial state of the feature and the ``Reducer`` that runs the feature's logic:

```swift
class CounterTests: XCTestCase {
  @MainActor
  func testBasics() async {
    let store = TestStore(initialState: Feature.State(count: 0)) {
      Feature()
    }
  }
}
```

> Tip: Tests that use ``TestStore`` should be annotated as `@MainActor` and marked as `async` since
> most assertion helpers on ``TestStore`` can suspend.

Test stores have a ``TestStore/send(_:assert:file:line:)-2co21`` method, but it behaves differently from
stores and view stores. You provide an action to send into the system, but then you must also
provide a trailing closure to describe how the state of the feature changed after sending the
action:

```swift
await store.send(.incrementButtonTapped) {
  // ...
}
```

This closure is handed a mutable variable that represents the state of the feature _before_ sending
the action, and it is your job to make the appropriate mutations to it to get it into the shape
it should be after sending the action:

```swift
await store.send(.incrementButtonTapped) {
  $0.count = 1
}
```

> The ``TestStore/send(_:assert:file:line:)-2co21`` method is `async` for technical reasons that we
> do not have to worry about right now.

If your mutation is incorrect, meaning you perform a mutation that is different from what happened
in the ``Reducer``, then you will get a test failure with a nicely formatted message showing exactly
what part of the state does not match:

```swift
await store.send(.incrementButtonTapped) {
  $0.count = 999
}
```

> ❌ Failure: A state change does not match expectation: …
>
> ```diff
> - TestStoreTests.State(count: 999)
> + TestStoreTests.State(count: 1)
> ```
>
> (Expected: −, Actual: +)

You can also send multiple actions to emulate a script of user actions and assert each step of the
way how the state evolved:

```swift
await store.send(.incrementButtonTapped) {
  $0.count = 1
}
await store.send(.incrementButtonTapped) {
  $0.count = 2
}
await store.send(.decrementButtonTapped) {
  $0.count = 1
}
```

> Tip: Technically we could have written the mutation block in the following manner:
>
> ```swift
> await store.send(.incrementButtonTapped) {
>   $0.count += 1
> }
> await store.send(.decrementButtonTapped) {
>   $0.count -= 1
> }
> ```
>
> …and the test would have still passed.
>
> However, this does not produce as strong of an assertion. It shows that the count did increment
> by one, but we haven't proven we know the precise value of `count` at each step of the way.
>
> In general, the less logic you have in the trailing closure of
> ``TestStore/send(_:assert:file:line:)-2co21``, the stronger your assertion will be. It is best to
> use simple, hard-coded data for the mutation.

Test stores do expose a ``TestStore/state`` property, which can be useful for performing assertions
on computed properties you might have defined on your state. For example, if `State` had a 
computed property for checking if `count` was prime, we could test it like so:

```swift
store.send(.incrementButtonTapped) {
  $0.count = 3
}
XCTAssertTrue(store.state.isPrime)
```

However, when inside the trailing closure of ``TestStore/send(_:assert:file:line:)-2co21``, the
``TestStore/state`` property is equal to the state _before_ sending the action, not after. That
prevents you from being able to use an escape hatch to get around needing to actually describe the
state mutation, like so:

```swift
store.send(.incrementButtonTapped) {
  $0 = store.state  // ❌ store.state is the previous, not current, state.
}
```

## Testing effects

Testing state mutations as shown in the previous section is powerful, but is only half the story
when it comes to testing features built in the Composable Architecture. The second responsibility of
``Reducer``s, after mutating state from an action, is to return an ``Effect`` that encapsulates a
unit of work that runs in the outside world and feeds data back into the system.

Effects form a major part of a feature's logic. They can perform network requests to external
services, load and save data to disk, start and stop timers, interact with Apple frameworks (Core
Location, Core Motion, Speech Recognition, etc.), and more.

As a simple example, suppose we have a feature with a button such that when you tap it, it starts
a timer that counts up until you reach 5, and then stops. This can be accomplished using the
``Effect/run(priority:operation:catch:fileID:line:)`` helper on ``Effect``, which provides you with
an asynchronous context to operate in and can send multiple actions back into the system:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable {
    var count = 0
  }
  enum Action {
    case startTimerButtonTapped
    case timerTick
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .startTimerButtonTapped:
        state.count = 0
        return .run { send in
          for _ in 1...5 {
            try await Task.sleep(for: .seconds(1))
            await send(.timerTick)
          }
        }

      case .timerTick:
        state.count += 1
        return .none
      }
    }
  }
}
```

To test this we can start off similar to how we did in the [previous section][Testing-state-changes]
when testing state mutations:

```swift
class TimerTests: XCTestCase {
  @MainActor
  func testBasics() async {
    let store = TestStore(initialState: Feature.State(count: 0)) {
      Feature()
    }
  }
}
```

With the basics set up, we can send an action into the system to assert on what happens, such as the
`.startTimerButtonTapped` action. This time we don't actually expect state to change at first
because when starting the timer we don't change state, and so in this case we can leave off the
trailer closure:

```swift
await store.send(.startTimerButtonTapped)
```

However, if we run the test as-is with no further interactions with the test store, we get a
failure:

> ❌ Failure: An effect returned for this action is still running. It must complete before the end
> of the test. …

This is happening because ``TestStore`` requires you to exhaustively prove how the entire system
of your feature evolves over time. If an effect is still running when the test finishes and the
test store did _not_ fail then it could be hiding potential bugs. Perhaps the effect is not
supposed to be running, or perhaps the data it feeds into the system later is wrong. The test store
requires all effects to finish.

To get this test passing we need to assert on the actions that are sent back into the system
by the effect. We do this by using the ``TestStore/receive(_:timeout:assert:file:line:)-6325h``
method, which allows you to assert which action you expect to receive from an effect, as well as how
the state changes after receiving that effect:

```swift
await store.receive(\.timerTick) {
  $0.count = 1
}
```

> Note: We are using key path syntax `\.timerTick` to specify the case of the action we expect to 
> receive. This works because the ``ComposableArchitecture/Reducer()`` macro automatically applies
> the `@CasePathable` macro to the `Action` enum, and `@CasePathable` comes from our
> [CasePaths][swift-case-paths] library which brings key path syntax to enum cases.

However, if we run this test we still get a failure because we asserted a `timerTick` action was
going to be received, but after waiting around for a small amount of time no action was received:

> ❌ Failure: Expected to receive an action, but received none after 0.1 seconds.

This is because our timer is on a 1 second interval, and by default
``TestStore/receive(_:timeout:assert:file:line:)-6325h`` only waits for a fraction of a second. This
is because typically you should not be performing real time-based asynchrony in effects, and instead
using a controlled entity, such as a clock, that can be sped up in tests. We will demonstrate this
in a moment, so for now let's increase the timeout:

```swift
await store.receive(\.timerTick, timeout: .seconds(2)) {
  $0.count = 1
}
```

This assertion now passes, but the overall test is still failing because there are still more
actions to receive. The timer should tick 5 times in total, so we need five `receive` assertions:

```swift
await store.receive(\.timerTick, timeout: .seconds(2)) {
  $0.count = 1
}
await store.receive(\.timerTick, timeout: .seconds(2)) {
  $0.count = 2
}
await store.receive(\.timerTick, timeout: .seconds(2)) {
  $0.count = 3
}
await store.receive(\.timerTick, timeout: .seconds(2)) {
  $0.count = 4
}
await store.receive(\.timerTick, timeout: .seconds(2)) {
  $0.count = 5
}
```

Now the full test suite passes, and we have exhaustively proven how effects are executed in this
feature. If in the future we tweak the logic of the effect, like say have it emit 10 times instead 
of 5, then we will immediately get a test failure letting us know that we have not properly
asserted on how the features evolve over time.

However, there is something not ideal about how this feature is structured, and that is the fact
that we are doing actual, uncontrolled time-based asynchrony in the effect:

```swift
return .run { send in
  for _ in 1...5 {
    try await Task.sleep(for: .seconds(1))  // ⬅️
    await send(.timerTick)
  }
}
```

This means for our test to run we must actually wait for 5 real world seconds to pass so that we
can receive all of the actions from the timer. This makes our test suite far too slow. What if in
the future we need to test a feature that has a timer that emits hundreds or thousands of times?
We cannot hold up our test suite for minutes or hours just to test that one feature.

To fix this we need to add a dependency to the reducer that aids in performing time-based
asynchrony, but in a way that is controllable. One way to do this is to add a clock as a
`@Dependency` to the reducer:

```swift
import Clocks

@Reducer
struct Feature {
  struct State { /* ... */ }
  enum Action { /* ... */ }
  @Dependency(\.continuousClock) var clock
  // ...
}
```

> Tip: To make use of controllable clocks you must use the [Clocks][gh-swift-clocks] library, which
> is automatically included with the Composable Architecture.

And then the timer effect in the reducer can make use of the clock to sleep rather than reaching
out to the uncontrollable `Task.sleep` method:

```swift
return .run { send in
  for _ in 1...5 {
    try await self.clock.sleep(for: .seconds(1))
    await send(.timerTick)
  }
}
```

> Tip: The `sleep(for:)` method on `Clock` is provided by the [Swift Clocks][gh-swift-clocks]
> library.

By having a clock as a dependency in the feature we can supply a controlled version in tests, such
as an immediate clock that does not suspend at all when you ask it to sleep:

```swift
let store = TestStore(initialState: Feature.State(count: 0)) {
  Feature()
} withDependencies: {
  $0.continuousClock = ImmediateClock()
}
```

With that small change we can drop the `timeout` arguments from the
``TestStore/receive(_:timeout:assert:file:line:)-6325h`` invocations:

```swift
await store.receive(\.timerTick) {
  $0.count = 1
}
await store.receive(\.timerTick) {
  $0.count = 2
}
await store.receive(\.timerTick) {
  $0.count = 3
}
await store.receive(\.timerTick) {
  $0.count = 4
}
await store.receive(\.timerTick) {
  $0.count = 5
}
```

…and the test still passes, but now does so immediately.

The more time you take to control the dependencies your features use, the easier it will be to
write tests for your features. To learn more about designing dependencies and how to best leverage
dependencies, read the <doc:DependencyManagement> article.

## Non-exhaustive testing

The previous sections describe in detail how to write tests in the Composable Architecture that
exhaustively prove how the entire feature evolves over time. You must assert on how every piece
of state changes, how every effect feeds data back into the system, and you must even make sure
that all effects complete before the test store is deallocated. This can be powerful, but it can
also be a nuisance, especially for highly composed features. This is why sometimes you may want
to test in a non-exhaustive style.

> Tip: The concept of "non-exhaustive test store" was first introduced by
> [Krzysztof Zabłocki][merowing.info] in a [blog post][exhaustive-testing-in-tca] and
> [conference talk][Composable-Architecture-at-Scale], and then later became integrated into the
> core library.

This style of testing is most useful for testing the integration of multiple features where you want
to focus on just a certain slice of the behavior. Exhaustive testing can still be important to use
for leaf node features, where you truly do want to assert on everything happening inside the
feature.
 
For example, suppose you have a tab-based application where the 3rd tab is a login screen. The user 
can fill in some data on the screen, then tap the "Submit" button, and then a series of events
happens to  log the user in. Once the user is logged in, the 3rd tab switches from a login screen 
to a profile screen, _and_ the selected tab switches to the first tab, which is an activity screen.

When writing tests for the login feature we will want to do that in the exhaustive style so that we
can prove exactly how the feature would behave in production. But, suppose we wanted to write an
integration test that proves after the user taps the "Login" button that ultimately the selected
tab switches to the first tab.

In order to test such a complex flow we must test the integration of multiple features, which means
dealing with complex, nested state and effects. We can emulate this flow in a test by sending
actions that mimic the user logging in, and then eventually assert that the selected tab switched
to activity:

```swift
let store = TestStore(initialState: AppFeature.State()) {
  AppFeature()
}

// 1️⃣ Emulate user tapping on submit button.
await store.send(\.login.submitButtonTapped) {
  // 2️⃣ Assert how all state changes in the login feature
  $0.login?.isLoading = true
  // ...
}

// 3️⃣ Login feature performs API request to login, and
//    sends response back into system.
await store.receive(\.login.loginResponse.success) {
// 4️⃣ Assert how all state changes in the login feature
  $0.login?.isLoading = false
  // ...
}

// 5️⃣ Login feature sends a delegate action to let parent
//    feature know it has successfully logged in.
await store.receive(\.login.delegate.didLogin) {
// 6️⃣ Assert how all of app state changes due to that action.
  $0.authenticatedTab = .loggedIn(
    Profile.State(...)
  )
  // ...
  // 7️⃣ *Finally* assert that the selected tab switches to activity.
  $0.selectedTab = .activity
}
```

Doing this with exhaustive testing is verbose, and there are a few problems with this:

  * We need to be intimately knowledgeable in how the login feature works so that we can assert
    on how its state changes and how its effects feed data back into the system.
  * If the login feature were to change its logic we may get test failures here even though the
    logic we are actually trying to test doesn't really care about those changes.
  * This test is very long, and so if there are other similar but slightly different flows we want
    to test we will be tempted to copy-and-paste the whole thing, leading to lots of duplicated,
    fragile tests.

Non-exhaustive testing allows us to test the high-level flow that we are concerned with, that of
login causing the selected tab to switch to activity, without having to worry about what is
happening inside the login feature. To do this, we can turn off ``TestStore/exhaustivity`` in the
test store, and then just assert on what we are interested in:

```swift
let store = TestStore(initialState: AppFeature.State()) {
  AppFeature()
}
store.exhaustivity = .off  // ⬅️

await store.send(\.login.submitButtonTapped)
await store.receive(\.login.delegate.didLogin) {
  $0.selectedTab = .activity
}
```

In particular, we did not assert on how the login's state changed or how the login's effects fed
data back into the system. We just assert that when the "Submit" button is tapped that eventually
we get the `didLogin` delegate action and that causes the selected tab to flip to activity. Now
the login feature is free to make any change it wants to make without affecting this integration
test.

Using ``Exhaustivity/off`` for ``TestStore/exhaustivity`` causes all un-asserted changes to pass
without any notification. If you would like to see what test failures are being suppressed without
actually causing a failure, you can use ``Exhaustivity/off(showSkippedAssertions:)``:

```swift
let store = TestStore(initialState: AppFeature.State()) {
  AppFeature()
}
store.exhaustivity = .off(showSkippedAssertions: true)  // ⬅️

await store.send(\.login.submitButtonTapped)
await store.receive(\.login.delegate.didLogin) {
  $0.selectedTab = .activity
}
```

When this is run you will get grey, informational boxes on each assertion where some change wasn't
fully asserted on:

> ◽️ Expected failure: A state change does not match expectation: …
>
> ```diff
>   AppFeature.State(
>     authenticatedTab: .loggedOut(
>       Login.State(
> -       isLoading: false
> +       isLoading: true,
>         …
>       )
>     )
>   )
> ```
>
> Skipped receiving .login(.loginResponse(.success))
>
> A state change does not match expectation: …
>
> ```diff
>   AppFeature.State(
> -   authenticatedTab: .loggedOut(…)
> +   authenticatedTab: .loggedIn(
> +     Profile.State(…)
> +   ),
>     …
>   )
> ```
>
> (Expected: −, Actual: +)

The test still passes, and none of these notifications are test failures. They just let you know
what things you are not explicitly asserting against, and can be useful to see when tracking down
bugs that happen in production but that aren't currently detected in tests.

#### Understanding non-exhaustive testing

It can be important to understand how non-exhaustive testing works under the hood because it does
limit the ways in which you can assert on state changes.

When you construct an _exhaustive_ test store, which is the default, the `$0` used inside the
trailing closure of ``TestStore/send(_:assert:file:line:)-2co21`` represents the state _before_ the
action is sent:

```swift
let store = TestStore(/* ... */)
// ℹ️ "on" is the default so technically this is not needed
store.exhaustivity = .on

store.send(.buttonTapped) {
  $0  // Represents the state *before* the action was sent
}
```

This forces you to apply any mutations necessary to `$0` to match the state _after_ the action
is sent.

Non-exhaustive test stores flip this on its head. In such a test store, the `$0` handed to the
trailing closure of `send` represents the state _after_ the action was sent:

```swift
let store = TestStore(/* ... */)
store.exhaustivity = .off

store.send(.buttonTapped) {
  $0  // Represents the state *after* the action was sent
}
```

This means you don't have to make any mutations to `$0` at all and the assertion will already pass.
But, if you do make a mutation, then it must match what is already in the state, thus allowing you
to assert on only the state changes you are interested in.

However, this difference between how ``TestStore`` behaves when run in exhaustive mode versus
non-exhaustive mode does restrict the kinds of mutations you can make inside the trailing closure of
`send`. For example, suppose you had an action in your feature that removes the last element of a
collection:

```swift
case .removeButtonTapped:
  state.values.removeLast()
  return .none
```

To test this in an exhaustive store it is completely fine to do this:

```swift
await store.send(.removeButtonTapped) {
  $0.values.removeLast()
}
```

This works because `$0` is the state before the action is sent, and so we can remove the last
element to prove that the reducer does the same work.

However, in a non-exhaustive store this will not work:

```swift
store.exhaustivity = .off
await store.send(.removeButtonTapped) {
  $0.values.removeLast()  // ❌
}
```

This will either fail, or possibly even crash the test suite. This is because in a non-exhaustive
test store, `$0` in the trailing closure of `send` represents the state _after_ the action has been
sent, and so the last element has already been removed. By executing `$0.values.removeLast()` we are
just removing an additional element from the end.

So, for non-exhaustive test stores you cannot use "relative" mutations for assertions. That is, you
cannot mutate via methods like `removeLast`, `append`, and anything that incrementally applies a
mutation. Instead you must perform an "absolute" mutation, where you fully replace the collection
with its final value:

```swift
store.exhaustivity = .off
await store.send(.removeButtonTapped) {
  $0.values = []
}
```

Or you can weaken the assertion by asserting only on the count of its elements rather than the
content of the element:

```swift
store.exhaustivity = .off
await store.send(.removeButtonTapped) {
  XCTAssertEqual($0.values.count, 0)
}
```

Further, when using non-exhaustive test stores that also show skipped assertions (via
``Exhaustivity/off(showSkippedAssertions:)``), then there is another caveat to keep in mind. In
such test stores, the trailing closure of ``TestStore/send(_:assert:file:line:)-2co21`` is invoked
_twice_ by the test store. First with `$0` representing the state after the action is sent to see if
it does not match the true state, and then again with `$0` representing the state before the action
is sent so that we can show what state assertions were skipped.

Because the test store can invoke your trailing assertion closure twice you must be careful if your
closure performs any side effects, because those effects will be executed twice. For example,
suppose you have a domain model that uses the controllable `@Dependency(\.uuid)` to generate a UUID:

```swift
struct Model: Equatable {
  let id: UUID
  init() {
    @Dependency(\.uuid) var uuid
    self.id = uuid()
  }
}
```

This is a perfectly fine to pattern to adopt in the Composable Architecture, but it does cause
trouble when using non-exhaustive test stores and showing skipped assertions. To see this, consider
the following simple reducer that appends a new model to an array when an action is sent:

```swift
@Reducer
struct Feature {
  struct State: Equatable {
    var values: [Model] = []
  }
  enum Action {
    case addButtonTapped
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        state.values.append(Model())
        return .none
      }
    }
  }
}
```

We'd like to be able to write a test for this by asserting that when the `addButtonTapped` action
is sent a model is append to the `values` array:

```swift
func testAdd() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.uuid = .incrementing
  }
  store.exhaustivity = .off(showSkippedAssertions: true)

  await store.send(.addButtonTapped) {
    $0.values = [Model()]
  }
}
```

While we would expect this simple test to pass, it fails when `showSkippedAssertions` is set to
`true`:

> ❌ Failure: A state change does not match expectation: …
>
> ```diff
>   TestStoreNonExhaustiveTests.Feature.State(
>     values: [
>       [0]: TestStoreNonExhaustiveTests.Model(
> -       id: UUID(00000000-0000-0000-0000-000000000001)
> +       id: UUID(00000000-0000-0000-0000-000000000000)
>       )
>     ]
>   )
> ```
>
> (Expected: −, Actual: +)

This is happening because the trailing closure is invoked twice, and the side effect that is
executed when the closure is first invoked is bleeding over into when it is invoked a second time.

In particular, when the closure is evaluated the first time it causes `Model()` to be constructed,
which secretly generates the next auto-incrementing UUID. Then, when we run the closure again
_another_ `Model()` is constructed, which causes another auto-incrementing UUID to be generated,
and that value does not match our expectations.

If you want to use the `showSkippedAssertions` option for
``Exhaustivity/off(showSkippedAssertions:)`` then you should avoid performing any kind of side
effect in `send`, including using `@Dependency` directly in your models' initializers. Instead
force those values to be provided at the moment of initializing the model:

```swift
struct Model: Equatable {
  let id: UUID
  init(id: UUID) {
    self.id = id
  }
}
```

And then move the responsibility of generating new IDs to the reducer:

```swift
@Reducer
struct Feature {
  // ...
  @Dependency(\.uuid) var uuid
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        state.values.append(Model(id: self.uuid()))
        return .none
      }
    }
  }
}
```

And now you can write the test more simply by providing the ID explicitly:

```swift
await store.send(.addButtonTapped) {
  $0.values = [
    Model(id: UUID(0))
  ]
}
```

And it works if you send the action multiple times:

```swift
await store.send(.addButtonTapped) {
  $0.values = [
    Model(id: UUID(0))
  ]
}
await store.send(.addButtonTapped) {
  $0.values = [
    Model(id: UUID(0)),
    Model(id: UUID(1))
  ]
}
```

## Testing gotchas

### Testing host application

This is not well known, but when an application target runs tests it actually boots up a simulator
and runs your actual application entry point in the simulator. This means while tests are running,
your application's code is separately also running. This can be a huge gotcha because it means you
may be unknowingly making network requests, tracking analytics, writing data to user defaults or to
the disk, and more.

This usually flies under the radar and you just won't know it's happening, which can be problematic.
But, once you start using this library and start controlling your dependencies, the problem can
surface in a very visible manner. Typically, when a dependency is used in a test context without
being overridden, a test failure occurs. This makes it possible for your test to pass successfully,
yet for some mysterious reason the test suite fails. This happens because the code in the _app
host_ is now running in a test context, and accessing dependencies will cause test failures.

This only happens when running tests in a _application target_, that is, a target that is
specifically used to launch the application for a simulator or device. This does not happen when
running tests for frameworks or SPM libraries, which is yet another good reason to modularize
your code base.

However, if you aren't in a position to modularize your code base right now, there is a quick
fix. Our [XCTest Dynamic Overlay][xctest-dynamic-overlay-gh] library, which is transitively included
with this library, comes with a property you can check to see if tests are currently running. If
they are, you can omit the entire entry point of your application:

```swift
import SwiftUI
import XCTestDynamicOverlay

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      if !_XCTIsTesting {
        // Your real root view
      }
    }
  }
}
```

That will allow tests to run in the application target without your actual application code
interfering.

### Statically linking your tests target to ComposableArchitecture

If you statically link the `ComposableArchitecture` module to your tests target, its implementation 
may clash with the implementation that is statically linked to the app itself. The most usually 
manifests by getting mysterious test failures telling you that you are using live dependencies in 
your tests even though you have overridden your dependencies. 

In such cases Xcode will display multiple warnings in the console similar to:

> Class _TtC12Dependencies[…] is implemented in both […] and […].
> One of the two will be used. Which one is undefined.

The solution is to remove the static link to `ComposableArchitecture` from your test target, as you 
transitively get access to it through the app itself. In Xcode, go to "Build Phases" and remove
"ComposableArchitecture" from the "Link Binary With Libraries" section. When using SwiftPM, remove 
the "ComposableArchitecture" entry from the `testTarget`'s' `dependencies` array in `Package.swift`.

[xctest-dynamic-overlay-gh]: http://github.com/pointfreeco/xctest-dynamic-overlay
[Testing-state-changes]: #Testing-state-changes
[Testing-effects]: #Testing-effects
[gh-combine-schedulers]: http://github.com/pointfreeco/combine-schedulers
[gh-xctest-dynamic-overlay]: http://github.com/pointfreeco/xctest-dynamic-overlay
[tca-examples]: https://github.com/pointfreeco/swift-composable-architecture/tree/main/Examples
[gh-swift-clocks]: http://github.com/pointfreeco/swift-clocks
[merowing.info]: https://www.merowing.info
[exhaustive-testing-in-tca]: https://www.merowing.info/exhaustive-testing-in-tca/
[Composable-Architecture-at-Scale]: https://vimeo.com/751173570
[Non-exhaustive-testing]: #Non-exhaustive-testing
[swift-case-paths]: http://github.com/pointfreeco/swift-case-paths
