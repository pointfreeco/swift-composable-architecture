# Testing

Learn how to write comprehensive and exhaustive tests for your features built in the Composable
Architecture.

The testability of features built in the Composable Architecture is the #1 priority of the library.
We never want to introduce new capabilities to the library that make testing more difficult.

* [Testing state changes][Testing-state-changes]
* [Testing effects][Testing-effects]
* [Designing dependencies][Designing-dependencies]
* [Unimplemented dependencies][Unimplemented-dependencies]

## Testing state changes

State changes are by far the simplest thing to test in features built with the library. A
``Reducer``'s first responsibility is to mutate the current state based on the action received into
the system. To test this we can technically run a piece of mutable state through the reducer and
then assert on how it changed after, like this:

```swift
struct State: Equatable { var count = 0 }
enum Action { case incrementButtonTapped, decrementButtonTapped }
struct Environment {}

let counter = Reducer<State, Action, Environment> { state, action, environment in
  switch action {
  case .incrementButtonTapped:
    state.count += 1
    return .none
  case .decrementButtonTapped:
    state.count -= 1
    return .none
  }
}

let environment = Environment()
var currentState = State(count: 0)

_ = reducer(&currentState, .incrementButtonTapped, environment)

XCTAssertEqual(
  currentState,
  State(count: 1)
)

_ = reducer(&currentState, .decrementButtonTapped, environment)

XCTAssertEqual(
  currentState,
  State(count: 0)
)
```

This will technically work, but it's a lot boilerplate for something that should be quite simple.

The library comes with a tool specifically designed to make testing like this much simpler and more
concise. It's called ``TestStore``, and it is constructed similarly to ``Store`` by providing the
initial state of the feature, the ``Reducer`` that run's the feature's logic, and an environment of
dependencies for the feature to use:

```swift
@MainActor
class CounterTests: XCTestCase {
  func testBasics() async {
    let store = TestStore(
      initialState: State(count: 0),
      reducer: counter,
      environment: Environment()
    )
  }
}
```

> Test cases that use ``TestStore`` should be annotated as `@MainActor` and test methods should be
> marked as `async` since most assertion helpers on ``TestStore`` can suspend.

Test stores have a ``TestStore/send(_:_:file:line:)-7vwv9`` method, but it behaves differently from
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

> The ``TestStore/send(_:_:file:line:)-7vwv9`` method is `async` for technical reasons that we do
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

> Note: Technically we could have written the mutation block in the following manner:
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
> ``TestStore/send(_:_:file:line:)-7vwv9``, the stronger your assertion will be. It is best to use
> simple, hard coded data for the mutation.

Test stores do expose a ``TestStore/state`` property, which can be useful for performing assertions
on computed properties you might have defined on your state. However, when inside the trailing
closure of ``TestStore/send(_:_:file:line:)-7vwv9``, the ``TestStore/state`` property is equal
to the state _before_ sending the action, not after. That prevents you from being able to use an
escape hatch to get around needing to actually describe the state mutation, like so:

```swift
store.send(.incrementButtonTapped) {
  $0 = store.state // 🛑 store.state is the previous state, not new state.
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

As a simple example, suppose we have a feature with a button such that when you tap it it starts
a timer that counts up until you reach 5, and then stops. This can be accomplished using the
``Effect/run(priority:operation:catch:file:fileID:line:)`` helper, which provides you an
asynchronous context to operate in and can send multiple actions back into the system:

```swift
struct State: Equatable { var count = 0 }
enum Action {  case startTimerButtonTapped, timerTick }
struct Environment {}

let reducer = Reducer<State, Action, Environment> { state, action, environment in
  enum TimerID {}

  switch action {
  case .startTimerButtonTapped:
    state.count = 0
    return .run { send in
      for _ in 1...5 {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        await send(.timerTick)
      }
    }

  case .timerTick:
    state.count += 1
    return .none
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
      initialState: State(count: 0),
      reducer: reducer,
      environment: Environment()
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
by the effect. We do this by using the ``TestStore/receive(_:timeout:_:file:line:)-88eyr`` method,
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
``TestStore/receive(_:timeout:_:file:line:)-88eyr`` only waits for a fraction of a second. This is
because typically you should not be performing real time-based asynchrony in effects, and instead
using a controlled entity, such as a scheduler or clock, that can be sped up in tests. We will
demonstrate this in a moment, so for now let's increase the timeout:

```swift
await store.receive(.timerTick, timeout: 2*NSEC_PER_SEC) {
  $0.count = 1
}
```

This assertion now passes, but the overall test is still failing because there are still more
actions to receive. The timer should tick 5 times in total, so we need five `receive` assertions:

```swift
await store.receive(.timerTick, timeout: 2*NSEC_PER_SEC) {
  $0.count = 1
}
await store.receive(.timerTick, timeout: 2*NSEC_PER_SEC) {
  $0.count = 2
}
await store.receive(.timerTick, timeout: 2*NSEC_PER_SEC) {
  $0.count = 3
}
await store.receive(.timerTick, timeout: 2*NSEC_PER_SEC) {
  $0.count = 4
}
await store.receive(.timerTick, timeout: 2*NSEC_PER_SEC) {
  $0.count = 5
}
```

Now the full test suite passes, and we have exhaustively proven how effects are executed in this
feature. If in the future we tweak the logic of the effect, like say have it emit some number of
times different from 5, then we will immediately get a test failure letting us know that we have
not properly asserted on how the features evolves over time.

However, there is something not ideal about how this feature is structured, and that is the fact
that we are doing actual, uncontrolled time-based asynchrony in the effect:

```swift
return .run { send in
  for _ in 1...5 {
    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
    await send(.timerTick)
  }
}
```

This means for our test to run we must actually wait for 5 real world seconds to pass so that we
can receive all of the actions from the timer. This makes our test suite far too slow. What if in
the future we need to test a feature that has a timer that emits hundreds or thousands of times?
We cannot hold up our test suite for minutes or hours just to test that one feature.

To fix this we need to hold onto a dependency in the feature's environment that aids in performing
time-based asynchrony, but in a way that is controllable. One way to do this is to add a Combine
scheduler to the environment:

```swift
import CombineSchedulers

struct Environment {
  var mainQueue: any SchedulerOf<DispatchQueue>
}
```

> To make use of controllable schedulers you must use the
[Combine Schedulers][gh-combine-schedulers] library, which is automatically included with the
Composable Architecture.

And then the timer effect in the reducer can make use of the scheduler to sleep rather than reaching
out to the uncontrollable `Task.sleep` method:

```swift
return .run { send in
  for _ in 1...5 {
    try await environment.mainQueue.sleep(for: .seconds(1))
    await send(.timerTick)
  }
}
```

> The `sleep(for:)` method on `Scheduler` is provided by the
[Combine Schedulers][gh-combine-schedulers] library.

By having a scheduler in the environment we can supply a controlled value in tests, such as an
immediate scheduler that does not suspend at all when you ask it to sleep:

```swift
let store = TestStore(
  initialState: State(count: 0),
  reducer: reducer,
  environment: Environment(mainQueue: .immediate)
)
```

With that small change we can drop the `timeout` arguments from the
``TestStore/receive(_:timeout:_:file:line:)-88eyr`` invocations:

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

## Designing dependencies

The [previous section][Testing-effects] shows the basics of testing effects in features, but only
for a simple time-based effect which was testable thanks to the tools that the
[Combine Schedulers][gh-combine-schedulers] library provides.

However, in general, the testability of a feature's effects is correlated with how easy it is to
control the dependencies your feature needs to do its job. If your feature needs to make network
requests, access to a location manager, or generate random numbers, then all of those dependencies
need to be designed in such a way that you can control them during tests so that you can make
assertions on how your feature interacts with those clients.

There are many ways to design controllable dependencies, and you can feel free to use any techniques
you feel comfortable with, but we will quickly sketch one such pattern.

Most dependencies can be modeled as an abstract interface to some endpoints that perform work
and return some data. Protocols are a common way to model such interfaces, but simple structs with
function properties can also work, and can reduce boilerplate.

For example, suppose you had a dependency that could make API requests to a server for fetching
a fact about a number. This can be modeled as a simple struct with a single function property:

```swift
struct NumberFactClient {
  var fetch: (Int) async throws -> String
}
```

This defines the interface to fetching a number fact, and we can create a "live" implementation of
the interface that makes an actual network request by constructing an instance, like so:

```swift
extension NumberFactClient {
  static let live = Self(
    fetch: { number in
      let (data, _) = try await URLSession.shared
        .data(from: URL(string: "http://numbersapi.com/\(number)/trivia")!)
      return String(decoding: data, as: UTF8.self)
    }
  )
}
```

This live implementation is appropriate to use when running the app in the simulator or on an actual
device.

We can also create a "mock" implementation of the interface that doesn't make a network request at
all and instead immediately returns a predictable string:

```swift
extension NumberFactClient {
  static let mock = Self(
    fetch: { number in "\(number) is a good number." }
  )
}
```

This mock implementation is appropriate to use in tests (and sometimes even previews) where you
do not want to make live network requests since that leaves you open to the vagaries of the outside
world that you cannot possibly predict.

For example, if you had a simple feature that allows you to increment and decrement a counter,
as well as fetch a fact for the current count, then you could test is roughly like so:

```swift
let store = TestStore(
  initialState: State(),
  reducer: reducer,
  environment: Environment(numberFact: .mock)
)

await store.send(.incrementButtonTapped) {
  $0.count = 1
}
await store.send(.factButtonTapped)
await store.receive(.factResponse("1 is a good number.")) {
  $0.fact = "1 is a good number."
}
```

Such a test can run immediately without making a network request to the outside world, and it will
pass deterministically 100% of the time.

Most, if not all, dependencies can be designed in this way, from API clients to location managers.
The Composable Architecture repo has [many examples][tca-examples] that demonstrate how to design
clients for very complex dependencies, such as network requests, download managers, web sockets,
speech recognition, and more.

## Unimplemented dependencies

Once you have designed your dependency in such a way that makes it easy to control, there is a
particular implementation of the dependency that can increase the strength of your tests. In the
[previous section][Designing-dependencies] we saw that we always want at least a "live"
implementation for using in the production version of the app, and a "mock" implementation for using
in tests, but there is another implementation that can be useful.

We call this the "unimplemented" implementation, which constructs an instance of the dependency
client whose endpoints have all been stubbed to invoke `XCTFail` so that if the endpoint is ever
used in a test it will trigger a test failure. This allows you to prove what parts of your
dependency is actually used in a test.

Not every test needs to use every endpoint of every dependency your feature has access to. By
providing the bare essentials of dependency endpoints that your test actually needs we can catch
in the future when a certain execution path of the feature starts using a new dependency that we
did not expect. This could either be due to a bug in the logic, or it could mean there is more logic
that we need to assert on in the test.

For example, suppose we were designing a client that could interface with a speech recognition API.
There would be an endpoint for requesting authorization to recognize speech on the device, an
endpoint for starting a new speech recognition task, and an endpoint for finishing the task:

```swift
struct SpeechClient {
  var finishTask: () async -> Void
  var requestAuthorization: @Sendable () async -> SpeechAuthorizationStatus
  var startTask: (Request) async -> AsyncThrowingStream<SpeechRecognitionResult, Error>
}
```

We can construct an instance of this client that stubs each endpoint as a function that simply
calls `XCTFail` under the hood:

```swift
import XCTestDynamicOverlay

extension SpeechClient {
  static let unimplemented = Self(
    finishTask: XCTUnimplemented("\(Self.self).finishTask"),
    requestAuthorization: XCTUnimplemented("\(Self.self).requestAuthorization"),
    startTask: XCTUnimplemented("\(Self.self).recognitionTask")
  )
}
```

> Note: In general, `XCTest` APIs cannot be used in code that is run in the simulator or on devices.
> To get around this we make use of our [XCTest Dynamic Overlay][gh-xctest-dynamic-overlay] library,
> which dynamically loads `XCTFail` to be available in all execution environments, not only tests.

Then in tests we start the store's environment with the unimplemented client, and override the bare
essentials of endpoints we expect to be called.

For example, if we were testing the flow in the feature where the user denies speech recognition
access, then we would not expect the `startTask` or `finishTask` endpoints to ever be called. That
would probably be a logical error, after all when the user denies permission those endpoints can't
do anything useful.

We can prove that this is the case by using the `.unimplemented` speech client in the test, and then
overriding only the `requestAuthorization` endpoint with an actual implementation:

```swift
func testDeniedAuthorization() async {
  let store = TestStore(
    initialState: State(),
    reducer: reducer,
    environment: Environment(speech: .unimplemented)
  )

  store.environment.speech.requestAuthorization = { .denied }

  …
}
```

You can make your tests much stronger by starting all dependencies in an "unimplemented" state, and
then only implementing the bare essentials of endpoints that your feature needs for the particular
flow you are testing. Then in the future, if your feature starts using new dependency endpoints you
will be instantly notified in tests and can figure out if that is expected or if a bug has been
introduced.

[Testing-state-changes]: #Testing-state-changes
[Testing-effects]: #Testing-effects
[Designing-dependencies]: #Designing-dependencies
[Unimplemented-dependencies]: #Unimplemented-dependencies
[gh-combine-schedulers]: http://github.com/pointfreeco/combine-schedulers
[gh-xctest-dynamic-overlay]: http://github.com/pointfreeco/xctest-dynamic-overlay
[tca-examples]: https://github.com/pointfreeco/swift-composable-architecture/tree/main/Examples
