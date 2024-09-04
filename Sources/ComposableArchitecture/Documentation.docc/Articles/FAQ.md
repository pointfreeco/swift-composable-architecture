# Frequently asked questions

A collection of some of the most common questions and comments people have concerning the library.

## Overview

We often see articles and discussions online concerning the Composable Architecture (TCA for short) that are outdated or slightly misinformed. Often these articles and discussions focus solely on “cons” of using TCA without giving time to what “pros” are unlocked by embracing any “cons” should they still exist in the latest version of TCA. 

However, focusing only on “cons” is missing the forest from the trees. As an analogy, one could write a scathing article about the “cons” of value types in Swift, including the fact that they lack a stable identity like classes do. But that would be missing one of their greatest strengths, which is their ability to be copied and compared in a lightweight way!

App architecture is filled with trade-offs, and it is important to think deeply about what one gains and loses with each choice they make. We have collected some of the most common issues brought up here in order to dispel some myths:

* [Should TCA be used for every kind of app?](#Should-TCA-be-used-for-every-kind-of-app)
* [Should I adopt a 3rd party library for my app’s architecture?](#Should-I-adopt-a-3rd-party-library-for-my-apps-architecture)
* [Does TCA go against the grain of SwiftUI?](#Does-TCA-go-against-the-grain-of-SwiftUI)
* [Isn't TCA just a port of Redux? Is there a need for a library?](#Isnt-TCA-just-a-port-of-Redux-Is-there-a-need-for-a-library)
* [Do features built in TCA have a lot of boilerplate?](#Do-features-built-in-TCA-have-a-lot-of-boilerplate)
* [Isn't maintaining a separate enum of “actions” unnecessary work?](#Isnt-maintaining-a-separate-enum-of-actions-unnecessary-work)
* [Are TCA features inefficient because all of an app’s state is held in one massive type?](#Are-TCA-features-inefficient-because-all-of-an-apps-state-is-held-in-one-massive-type)
  * [Does that cause views to over-render?](#Does-that-cause-views-to-over-render)
  * [Are large value types expensive to mutate?](#Are-large-value-types-expensive-to-mutate)
  * [Can large value types cause stack overflows?](#Can-large-value-types-cause-stack-overflows)
* [Don't TCA features have excessive “ping-ponging”?](#Dont-TCA-features-have-excessive-ping-ponging)
* [If features are built with value types, doesn't that mean they cannot share state since value types are copied?](#If-features-are-built-with-value-types-doesnt-that-mean-they-cannot-share-state-since-value-types-are-copied)
* [Do I need a Point-Free subscription to learn or use TCA?](#Do-I-need-a-Point-Free-subscription-to-learn-or-use-TCA)
* [Do I need to be familiar with "functional programming" to use TCA?](#Do-I-need-to-be-familiar-with-functional-programming-to-use-TCA)

### Should TCA be used for every kind of app?

We do not recommend people use TCA when they are first learning Swift or SwiftUI. TCA is not a substitute or replacement for SwiftUI, but rather is meant to be paired with SwiftUI. You will need to be familiar with all of SwiftUI's standard concepts to wield TCA correctly.

We also don't think TCA really shines when building simple “reader” apps that mostly load JSON from the network and display it. Such apps don’t tend to have much in the way of nuanced logic or complex side effects, and so the benefits of TCA aren’t as clear.

In general it can be fine to start a project with vanilla SwiftUI (with a concentration on concise domain modeling), and then transition to TCA later if there is a need for any of its powers.

### Should I adopt a 3rd party library for my app’s architecture?

Adopting a 3rd party library is a big decision that should be had by you and your team after thoughtful discussion and consideration. We cannot make that decision for you. 🙂

But the "not invented here" mentality cannot be the _sole_ reason to not adopt a library. If a library's core tenets align with your priorities for building your app, then adopting a library can be a sensible choice. It would be better to coalesce on a well-defined set of tools with a consistent history of maintenance and a strong community than to glue together many "tips and tricks" found in blog posts scattered around the internet. 

Blog posts tend to be written from the perspective of something that was interesting and helpful in a particular moment, but it doesn't necessarily stand the test of time. How many blog posts have been vetted for the many real world edge cases one actually encouters in app development? How many blog post techniques are still used by their authors 4 years later? How many blog posts have follow-up retrospectives describing how the technique worked in practice and evolved over time?

So, in comparison, we do not feel the adoption of a 3rd party library is significantly riskier than adopting ideas from blog posts, but it is up to you and your team to figure out your priorities for your application.

### Does TCA go against the grain of SwiftUI?

We actually feel that TCA complements SwiftUI quite well! The design of TCA has been heavily inspired by SwiftUI, and so you will find a lot of similarities:

* TCA features can minimally and implicitly observe minimal state changes just as in SwiftUI, but one uses the [`@ObservableState`][observation-state-docs] macro to do so, which is like Swift's `@Observable`. We even [back-ported][observation-backport-article] Swift's observation tools so that they could be used with iOS 16 and earlier.
* One composes TCA features together much like one composes SwiftUI features, by implementing a [`body`][reducer-body-docs] property and using result builder syntax.
* Dependencies are declared using the [`@Dependency`][dependency-management-article] property wrapper, which behaves much like SwiftUI's `@Environment` property wrapper, but it works outside of views.
* The library's [state sharing][sharing-state-article] tools work a lot like SwiftUI's `@Binding` tool, but it works outside of views and it is 100% testable.

We also feel that often TCA allows one to even more fully embrace some of the super powers of SwiftUI:

* TCA apps are allowed to use Swift's observation tools with value types, whereas vanilla SwiftUI is limited to only reference types. The author of the observation proposal even intended for `@Observable` to work with value types but ultimately had to abandon it due to limitations of Swift. But we are able to overcome those limitations thanks to the [`Store`][store-docs] type.
* Navigation in TCA uses all of the same tools from vanilla SwiftUI, such as `sheet(item:)`, `popover(item:)`, and even `NavigationStack`. But we also provide tools for [driving navigation][navigation-article] from more concise domains, such as enums and optionals.
* TCA allows one to “hot swap” a feature’s logic and behavior for alternate versions, with essentially no extra work. For example when showing a “placeholder” version of a UI using SwiftUI’s `redacted` API, you can [swap the feature’s logic](https://www.pointfree.co/collections/swiftui/redactions) for an “inert” version that does nothing when interacted with.
* TCA features tend to be easier to view in Xcode previews because [dependencies are controlled][dependency-management-article] from the beginning. There are many dependencies that don't work in previews (_e.g._ location managers), and some that are dangerous to use in previews (_e.g._ analytics clients), but one does not need to worry about that when controlling dependencies properly.
* TCA features can be fully tested, including how dependencies execute and feed data back into the system, all without needing to run a UI test.

And the more familiar you are with SwiftUI and its patterns, the better you will be able to leverage the Composable Architecture. We’ve never said that you must abandon SwiftUI in order to use TCA, and in fact we think the opposite is true!

### Isn't TCA just a port of Redux? Is there a need for a library?

While TCA certainly shares some ideas and terminology with Redux, the two libraries are quite different. First, Redux is a JavaScript library, not a Swift library, and it was never meant to be an opinionated and cohesive solution to many app architecture problems. It focused on a particular problem, and stuck with it.

TCA broadened the focus to include tools for a lot of common problems one runs into with app architecture, such as:

* …tools for concise domain modeling.
* Allowing one to embrace value types fully instead of reference types.
* A full suite of tools are provided for integrating with Apple’s platforms (SwiftUI, UIKit, AppKit, _etc._), including [navigation][navigation-article].
* A powerful [dependency management system][dependency-management-article] for controlling and propagating dependencies throughout your app.
* A [testing tool][testing-article] that makes it possible to exhaustively test how your feature behaves with user actions, including how side effects execute and feed data back into the system.
* …and more!

Redux does not provide tools itself for any of the above problems.

And you can certainly opt to build your own TCA-inspired library instead of depending directly on TCA, and in fact many large companies do just that. But it is also worth considering if it is worth losing out on the continual development and improvements TCA makes over the years. With each major release of iOS we have made sure to keep TCA up-to-date, including concurrency tools, `NavigationStack`, and [Swift 5.9’s observation tools][migration-1.7-article] (of which we even [back-ported][observation-backport-article] so that they could be used all the way back to iOS 13), [state sharing][sharing-state-article] tools, and more. And further you will be missing out on the community of thousands of developers that use TCA and frequent our GitHub discussions and [Slack](http://pointfree.co/slack-invite).

### Do features built in TCA have a lot of boilerplate?

Often people complain of boilerplate in TCA, especially with regards a legacy concept known as “view stores”. Those were objects that allowed views to observe the minimal amount of state in a view, and they were [deprecated a long time ago][migration-1.7-article] after Swift 5.9 released with the Observation framework. Features built with modern TCA do not need to worry about view stores and instead can access state directly off of stores and the view will observe the minimal amount of state, just as in vanilla SwiftUI.

In our experience, a standard TCA feature should not require very many more lines of code than an equivalent vanilla SwiftUI feature, and if you write tests or integrate features together using the tools TCA provides, it should require much *less* code than the equivalent vanilla code.

### Isn't maintaining a separate enum of “actions” unnecessary work?

Modeling user actions with an enum rather than methods defined on some object is certainly a big decision to make, and some people find it off-putting, but it wasn’t made just for the fun of it. There are massive benefits one gains from having a data description of every action in your application:

- It fully decouples the logic of your feature from the view of your feature, even more than a dedicated `@Observable` model class can. You can write a reducer that wraps an existing reducer and “tweaks” the underlying reducer’s logic in anyway it sees fit. 

  For example, in our open source word game, [isowords](http://github.com/pointfreeco/isowords), we have an onboarding feature that runs the game feature inside, but with additional logic layered on. Since each action in the game has a simple enum description we are able to intercept any action and execute some additional logic. For example, when the user submits a word during onboarding we can inspect which word they submitted as well as which step of the onboarding process they are on in order to figure out if they should proceed to the next step:

  ```swift
  case .game(.submitButtonTapped):
  switch state.step {
  case
    .step5_SubmitGame where state.game.selectedWordString == "GAME",
    .step8_FindCubes where state.game.selectedWordString == "CUBES",
    .step12_CubeIsShaking where state.game.selectedWordString == "REMOVE",
    .step16_FindAnyWord where dictionary.contains(state.game.selectedWordString, .en):

  state.step.next()
  ```

  This is quite complex logic that was easy to implement thanks to the enum description of actions. And on top of that, it was all 100% unit testable.

- Having a data type of all actions in your feature makes it possible to write powerful debugging tools. For example, the `_printChanges()` reducer operator gives you insight into every action that enters the system, and prints a nicely formatted message showing exactly how state changed when the action was processed:

  ```
  received action:
    AppFeature.Action.syncUpsList(.addSyncUpButtonTapped)
    AppFeature.State(
      _path: [:],
      _syncUpsList: SyncUpsList.State(
  -     _destination: nil,
  +     _destination: .add(
  +       SyncUpForm.State(
  +         …
  +       )
  +     ),
        _syncUps: #1 […]
      )
    )
  ```

  You can also create a tool, [`signpost`][signpost-docs], that automatically instruments every action of your feature with signposts to find any potential performance problems in your app. And 3rd parties have built their own tools for tracking and instrumenting features, all thanks to the fact that there is a data representation of every action in the app.

- Having a data type of all actions in your feature also makes it possible to write exhaustive tests on every aspect of your feature. Using something known as a [`TestStore`][test-store-docs] you can emulate user flows by sending it actions and asserting how state changes each step of the way. And further, you must also assert on how effects feed their data back into the system by asserting on actions received:

  ```swift
  store.send(.refreshButtonTapped) {
    $0.isLoading = true
  }
  store.receive(\.userResponse) {
    $0.currentUser = User(id: 42, name: "Blob")
    $0.isLoading = false
  }
  ```

  Again this is only possible thanks to the data type of all actions in the feature. See  for more information on testing in TCA.

<!-- TODO: Navigation tools? -->

### Are TCA features inefficient because all of an app’s state is held in one massive type?

This comes up often, but this misunderstands how real world features are actually modeled in practice. An app built with TCA does not literally hold onto the state of every possible screen of the app all at once. In reality most features of an app are not presented at once, but rather incrementally. Features are presented in sheets, drill-downs and other forms of navigation, and those forms of navigation are gated by optional state. This means if a feature is not presented, then its state is `nil`, and hence not represented in the app state.

* ##### Does that cause views to over-render?

  In reality views re-compute the minimal number of times based off of what state is accessed in the view, just as it does in vanilla SwiftUI with the `@Observable` macro. But because we [back-ported][observation-backport-article] the observation framework to iOS 13 you can make use of the tools today, and not wait until you can drop iOS 16 support.

<!-- [ ] Other redux libraries-->

* ##### Are large value types expensive to mutate?

  This doesn’t really seem to be the case with in-place mutation in Swift. Mutation _via_ `inout` has been quite efficient from our testing, and there’s a chance that Swift’s new borrowing and consuming tools will allow us to make it even more efficient.

* ##### Can large value types cause stack overflows?

  While it is true that large value types can overflow the stack, in practice this does not really happen if you are using the navigation tools of the library. The navigation tools insert a heap allocated, copy-on-write wrapper at each presentation node of your app’s state. So if feature A can present feature B, then feature A’s state does not literally contain feature B’s state.

### Don't TCA features have excessive “ping-ponging"?

There have been complaints of action “ping-ponging”, where one wants to perform multiple effects and so has to send multiple actions:

```swift
case .refreshButtonTapped:
  return .run { send in 
    await send(.userResponse(apiClient.fetchCurrentUser()))
  }
case let .userResponse(response):
  return .run { send in 
    await send(.moviesResponse(apiClient.fetchMovies(userID: response.id)))
  }
case let .moviesResponse(response):
  // Do something with response
```

However, this is really only necessary if you specifically need to intermingle state mutations *and* async operations. If you only need to execute multiple async operations with no state mutations in between, then all of that work can go into a single effect:

```swift
case .refreshButtonTapped:
  return .run { send in 
    let userResponse = await apiClient.fetchCurrentUser()    
    let moviesResponse = await apiClient.fetchMovies(userID: userResponse.id)
    await send(.moviesResponse(moviesResponse))
  }
```

And if you really do need to perform state mutations between each of these asynchronous operations then you will incur a bit of ping-ponging. But, [as mentioned above](#Maintaining-a-separate-enum-of-actions-is-unnecessary-work), there are great benefits to having a data description of actions, such as an extreme decoupling of logic from the view, powerful debugging tools, the ability to test every aspect of your feature, and more. If you were to try to reproduce those abilities in a non-TCA app you would be inevitably led to the same ping-ponging.

<!-- TODO: We should be able to completely eliminate ping-ponging in TCA 2.0 -->

### If features are built with value types, doesn't that mean they cannot share state since value types are copied?

This *used* to be true, but in [version 1.10][migration-1.10-article] of the library we released all new [state sharing][sharing-state-article] tools that allow you to easily share state between multiple features, and even persist state to external systems, such as user defaults and the file system. 

Further, one of the dangers of introducing shared state to an app, any app, is that it can make it difficult to understand since it introduces reference semantics into your domain. But we put in extra work to make sure that shared state remains 100% testable, and even _exhaustively_ testable, which makes it far easier to keep track of how shared state is mutated in your features.

### Do I need a Point-Free subscription to learn or use TCA?

While we do release a lot of material on our website that is subscriber-only, we also release a _ton_ of material completely for free. The [documentation][tca-docs] for TCA contains numerous articles and tutorials, including a [massive tutorial][sync-ups-tutorial] building a complex app from scratch that demonstrates domain modeling, navigation, dependencies, testing, and more.

### Do I need to be familiar with "functional programming" to use TCA?

TCA does not describe itself as a "functional programming" library, and never has. At the end of the day Swift is not a functional language, and so there is no way to force functional patterns at  compile time, such as "pure" functions. And so familiarity of "functional programming" is not necessary.

However, certain concepts of functional programming languages are quite important to us, and we have used those concepts to guide aspects of the library. For example, a core tenet of the library is to build as much of your domain using value types, which are easy to understand and behaviorless, as opposed to reference types, which allow for "action at a distance". The library also values  separating side effects from pure logic transformations. This allows for great testability, 
including how side effects execute and feed data back into the system.

However, one does not need to have any prior experience with these concepts. The ideas are imbued into the library and documentation, and so you will gain experience by simply following our materials and demo apps.

[observation-backport-article]: <doc:ObservationBackport>
[dependency-management-article]: <doc:DependencyManagement>
[sharing-state-article]: <doc:SharingState>
[navigation-article]: <doc:Navigation>
[testing-article]: <doc:Testing>
[migration-1.7-article]: <doc:MigratingTo1.7>
[migration-1.10-article]: <doc:MigratingTo1.10>
[sync-ups-tutorial]: <doc:BuildingSyncUps>
[tca-docs]: <doc:ComposableArchitecture> 
[observation-state-docs]: <doc:ObservableState()>
[reducer-body-docs]: <doc:Reducer/body-20w8t>
[store-docs]: <doc:Store>
[signpost-docs]: <doc:Reducer/signpost(_:log:)>
[test-store-docs]: <doc:TestStore>
