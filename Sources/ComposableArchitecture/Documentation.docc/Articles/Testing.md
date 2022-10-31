# Testing

Learn how to write comprehensive and exhaustive tests for your features built in the Composable
Architecture.

The testability of features built in the Composable Architecture is the #1 priority of the library.
It should be possible to test not only how state changes when actions are sent into the store,
but also how effects are executed and feed data back into the system.

* [Testing state changes][Testing-state-changes]
* [Testing effects][Testing-effects]
* [Non-exhaustive testing][Non-exhaustive-testing]

## Testing state changes

State changes are by far the simplest thing to test in features built with the library. A
``Reducer``'s first responsibility is to mutate the current state based on the action received into
the system. To test this we can technically run a piece of mutable state through the reducer and
then assert on how it changed after, like this:

```swift
struct Feature: ReducerProtocol {
  struct State: Equatable { var count = 0 }
  enum Action { case incrementButtonTapped, decrementButtonTapped }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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
initial state of the feature and the ``Reducer`` that run's the feature's logic:

```swift
@MainActor
class CounterTests: XCTestCase {
  func testBasics() async {
    let store = TestStore(
      initialState: Feature.State(count: 0),
      reducer: Feature()
    )
  }
}
```

> Tip: Test cases that use ``TestStore`` should be annotated as `@MainActor` and test methods should 
be marked as `async` since most assertion helpers on ``TestStore`` can suspend.

Test stores have a ``TestStore/send(_:assert:file:line:)-1ax61`` method, but it behaves differently
from stores and view stores. You provide an action to send into the system, but then you must also
provide a trailing closure to describe how the state of the feature changed after sending the
action:

```swift
await store.send(.incrementButtonTapped) {
  …
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

> The ``TestStore/send(_:assert:file:line:)-1ax61`` method is `async` for technical reasons that we
> do not have to worry about right now.

If your mutation is incorrect, meaning you perform a mutation that is different from what happened
in the ``Reducer``, then you will get a test failure with a nicely formatted message showing exactly
what part of the state does not match:

```swift
await store.send(.incrementButtonTapped) {
  $0.count = 999
}
```

```
🛑 testSomething(): A state change does not match expectation: …

  − TestStoreTests.State(count: 999)
  + TestStoreTests.State(count: 1)

(Expected: −, Actual: +)
```

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
> ``TestStore/send(_:assert:file:line:)-1ax61``, the stronger your assertion will be. It is best to
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

However, when inside the trailing closure of ``TestStore/send(_:assert:file:line:)-1ax61``, the 
``TestStore/state`` property is equal to the state _before_ sending the action, not after. That 
prevents you from being able to use an escape hatch to get around needing to actually describe the 
state mutation, like so:

```swift
store.send(.incrementButtonTapped) {
  $0 = store.state // 🛑 store.state is the previous state, not new state.
}
```

## Testing effects

Testing state mutations as shown in the previous section is powerful, but is only half the story
when it comes to testing features built in the Composable Architecture. The second responsibility of
``Reducer``s, after mutating state from an action, is to return an ``EffectTask`` that encapsulates 
a unit of work that runs in the outside world and feeds data back into the system.

Effects form a major part of a feature's logic. They can perform network requests to external
services, load and save data to disk, start and stop timers, interact with Apple frameworks (Core
Location, Core Motion, Speech Recognition, etc.), and more.

As a simple example, suppose we have a feature with a button such that when you tap it, it starts
a timer that counts up until you reach 5, and then stops. This can be accomplished using the
``EffectPublisher/run(priority:operation:catch:file:fileID:line:)`` helper on ``EffectTask``, 
which provides you with an asynchronous context to operate in and can send multiple actions back 
into the system:

```swift
struct Feature: ReducerProtocol {
  struct State: Equatable { var count = 0 }
  enum Action { case startTimerButtonTapped, timerTick }
  enum TimerID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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
```

To test this we can start off similar to how we did in the [previous section][Testing-state-changes]
when testing state mutations:

```swift
@MainActor
class TimerTests: XCTestCase {
  func testBasics() async {
    let store = TestStore(
      initialState: Feature.State(count: 0),
      reducer: Feature()
    )
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

```
🛑 testSomething(): An effect returned for this action is still running.
   It must complete before the end of the test. …
```

This is happening because ``TestStore`` requires you to exhaustively prove how the entire system
of your feature evolves over time. If an effect is still running when the test finishes and the
test store did _not_ fail then it could be hiding potential bugs. Perhaps the effect is not
supposed to be running, or perhaps the data it feeds into the system later is wrong. The test store
requires all effects to finish.

To get this test passing we need to assert on the actions that are sent back into the system
by the effect. We do this by using the ``TestStore/receive(_:timeout:assert:file:line:)-1rwdd``
method, which allows you to assert which action you expect to receive from an effect, as well as how
the state changes after receiving that effect:

```swift
await store.receive(.timerTick) {
  $0.count = 1
}
```

However, if we run this test we still get a failure because we asserted a `timerTick` action was
going to be received, but after waiting around for a small amount of time no action was received:

```
🛑 testSomething(): Expected to receive an action, but received none after 0.1 seconds.
```

This is because our timer is on a 1 second interval, and by default
``TestStore/receive(_:timeout:assert:file:line:)-1rwdd`` only waits for a fraction of a second. This
is because typically you should not be performing real time-based asynchrony in effects, and instead
using a controlled entity, such as a clock, that can be sped up in tests. We will demonstrate this 
in a moment, so for now let's increase the timeout:

```swift
await store.receive(.timerTick, timeout: .seconds(2)) {
  $0.count = 1
}
```

This assertion now passes, but the overall test is still failing because there are still more
actions to receive. The timer should tick 5 times in total, so we need five `receive` assertions:

```swift
await store.receive(.timerTick, timeout: .seconds(2)) {
  $0.count = 1
}
await store.receive(.timerTick, timeout: .seconds(2)) {
  $0.count = 2
}
await store.receive(.timerTick, timeout: .seconds(2)) {
  $0.count = 3
}
await store.receive(.timerTick, timeout: .seconds(2)) {
  $0.count = 4
}
await store.receive(.timerTick, timeout: .seconds(2)) {
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
    try await Task.sleep(for: .seconds(1)) // ⬅️
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

struct Feature: ReducerProtocol {
  struct State { … }
  enum Action { … }
  @Dependency(\.continuousClock) var clock
}
```

> Tip: To make use of controllable clocks you must use the [Clocks][gh-swift-clocks] library, which is 
automatically included with the Composable Architecture.

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

> Tip: The `sleep(for:)` method on `Clock` is provided by the
[Swift Clocks][gh-swift-clocks] library.

By having a clock as a dependency in the feature we can supply a controlled version in tests, such 
as an immediate clock that does not suspend at all when you ask it to sleep:

```swift
let store = TestStore(
  initialState: Feature.State(count: 0),
  reducer: Feature()
)

store.dependencies.continuousClock = ImmediateClock()
```

With that small change we can drop the `timeout` arguments from the
``TestStore/receive(_:timeout:assert:file:line:)-1rwdd`` invocations:

```swift
await store.receive(.timerTick) {
  $0.count = 1
}
await store.receive(.timerTick) {
  $0.count = 2
}
await store.receive(.timerTick) {
  $0.count = 3
}
await store.receive(.timerTick) {
  $0.count = 4
}
await store.receive(.timerTick) {
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
[Krzysztof Zabłocki][merowing.info] in a [blog post][exhaustive-testing-in-tca] and 
[conference talk][Composable-Architecture-at-Scale], and then later became integrated into the
core library.

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
let store = TestStore(
  initialState: App.State(),
  reducer: App()
)

// 1️⃣ Emulate user tapping on submit button.
await store.send(.login(.submitButtonTapped)) {
  // 2️⃣ Assert how all state changes in the login feature
  $0.login?.isLoading = true
  …
}

// 3️⃣ Login feature performs API request to login, and
//    sends response back into system.
await store.receive(.login(.loginResponse(.success))) {
// 4️⃣ Assert how all state changes in the login feature
  $0.login?.isLoading = false
  …
}

// 5️⃣ Login feature sends a delegate action to let parent
//    feature know it has successfully logged in.
await store.receive(.login(.delegate(.didLogin))) {
// 6️⃣ Assert how all of app state changes due to that action.
  $0.authenticatedTab = .loggedIn(
    Profile.State(...)
  )
  …
  // 7️⃣ *Finally* assert that the selected tab switches to activity.
  $0.selectedTab = .activity
}
```

Doing this with exhaustive testing is verbose, and there are a few problems with this:

* We need to be intimately knowledgeable in how the login feature works so that we can assert
on how its state changes and how its effects feed data back into the system. 
* If the login feature were to change its logic we may get test failures here even though the logic 
we are acutally trying to test doesn't really care about those changes.
* This test is very long, and so if there are other similar but slightly different flows we want to
test we will be tempted to copy-and-paste the whole thing, leading to lots of duplicated, fragile
tests.

Non-exhaustive testing allows us to test the high-level flow that we are concerned with, that of
login causing the selected tab to switch to activity, without having to worry about what is 
happening inside the login feature. To do this, we can turn off ``TestStore/exhaustivity`` in the
test store, and then just assert on what we are interested in:

```swift
let store = TestStore(
  initialState: App.State(),
  reducer: App()
)
store.exhaustivity = .off // ⬅️

await store.send(.login(.submitButtonTapped))
await store.receive(.login(.delegate(.didLogin))) {
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
let store = TestStore(
  initialState: App.State(),
  reducer: App()
)
store.exhaustivity = .off(showSkippedAssertions: true) // ⬅️

await store.send(.login(.submitButtonTapped))
await store.receive(.login(.delegate(.didLogin))) {
  $0.selectedTab = .activity
}
```

When this is run you will get grey, informational boxes on each assertion where some change wasn't
fully asserted on:

```
◽️ A state change does not match expectation: …

     App.State(
       authenticatedTab: .loggedOut(
         Login.State(
   −       isLoading: false
   +       isLoading: true,
           …
         )
       )
     )
   
   (Expected: −, Actual: +)

◽️ Skipped receiving .login(.loginResponse(.success))

◽️ A state change does not match expectation: …

     App.State(
   −   authenticatedTab: .loggedOut(…)
   +   authenticatedTab: .loggedIn(
   +     Profile.State(…)
   +   ),
       …
     )
   
   (Expected: −, Actual: +)
```

The test still passes, and none of these notifications are test failures. They just let you know
what things you are not explicitly asserting against, and can be useful to see when tracking down
bugs that happen in production but that aren't currently detected in tests.

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
