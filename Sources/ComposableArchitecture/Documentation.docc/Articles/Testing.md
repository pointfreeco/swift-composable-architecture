# Testing

Learn how to write comprehensive and exhaustive tests for your features built in the Composable
Architecture.

The testability of features built in the Composable Architecture is the #1 priority of the library.
It should be possible to test not only how state changes when actions are sent into the store,
but also how effects are executed and feed data back into the system.

<!--* [Testing state changes][Testing-state-changes]-->
<!--* [Testing effects][Testing-effects]-->
<!--* [Designing dependencies][Designing-dependencies]-->
<!--* [Unimplemented dependencies][Unimplemented-dependencies]-->

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

Test stores have a ``TestStore/send(_:_:file:line:)-6s1gq`` method, but it behaves differently from
stores and view stores. You provide an action to send into the system, but then you must also
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

> The ``TestStore/send(_:_:file:line:)-6s1gq`` method is `async` for technical reasons that we do
not have to worry about right now.

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
> ```
>
> …and the test would have still passed.
>
> However, this does not produce as strong of an assertion. It shows that the count did increment
> by one, but we haven't proven we know the precise value of `count` at each step of the way.
>
> In general, the less logic you have in the trailing closure of
> ``TestStore/send(_:_:file:line:)-6s1gq``, the stronger your assertion will be. It is best to use
> simple, hard coded data for the mutation.

Test stores do expose a ``TestStore/state`` property, which can be useful for performing assertions
on computed properties you might have defined on your state. For example, if `State` had a 
computed property for checking if `count` was prime, we could test it like so:

```swift
store.send(.incrementButtonTapped) {
  $0.count = 3
}
XCTAssertTrue(store.state.isPrime)
```

However, when inside the trailing closure of ``TestStore/send(_:_:file:line:)-6s1gq``, the 
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
``EffectPublisher/run(priority:operation:catch:file:fileID:line:)`` helper, which provides you with 
an asynchronous context to operate in and can send multiple actions back into the system:

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
test store does _not_ fail then it could be hiding potential bugs. Perhaps the effect is not
supposed to be running, or perhaps the data it feeds into the system later is wrong. The test store
requires all effects to finish.

To get this test passing we need to assert on the actions that are sent back into the system
by the effect. We do this by using the ``TestStore/receive(_:timeout:_:file:line:)-8yd62`` method,
which allows you to assert which action you expect to receive from an effect, as well as how the
state changes after receiving that effect:

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
``TestStore/receive(_:timeout:_:file:line:)-8yd62`` only waits for a fraction of a second. This is
because typically you should not be performing real time-based asynchrony in effects, and instead
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
``TestStore/receive(_:timeout:_:file:line:)-8yd62`` invocations:

```swift
await store.receive(.timerTick) {
  $0.count = 1
}
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

[Testing-state-changes]: #Testing-state-changes
[Testing-effects]: #Testing-effects
[Designing-dependencies]: #Designing-dependencies
[Unimplemented-dependencies]: #Unimplemented-dependencies
[gh-xctest-dynamic-overlay]: http://github.com/pointfreeco/xctest-dynamic-overlay
[tca-examples]: https://github.com/pointfreeco/swift-composable-architecture/tree/main/Examples
[gh-swift-clocks]: http://github.com/pointfreeco/swift-clocks
