# Standups

This project demonstrates how to build a complex, real world application that deals with many forms
of navigation (_e.g._, sheets, drill-downs, alerts), many side effects (timers, speech recognizer,
data persistence), and do so in a way that is testable and modular.

The inspiration for this application comes Apple's [Scrumdinger][scrumdinger] tutorial:

> This module guides you through the development of Scrumdinger, an iOS app that helps users manage
> their daily scrums. To help keep scrums short and focused, Scrumdinger uses visual and audio cues
> to indicate when and how long each attendee should speak. The app also displays a progress screen
> that shows the time remaining in the meeting and creates a transcript that users can refer to
> later.

The Scrumdinger app is one of Apple's most interesting code samples as it deals with many real
world problems that one faces in application development. It shows off many types of navigation,
it deals with complex effects such as timers and speech recognition, and it persists application
data to disk.

However, it is not necessarily built in the most ideal way. It uses mostly fire-and-forget style
navigation, which means you can't easily deep link into any screen of the app, which is handy for
push notifications and opening URLs. It also uses uncontrolled dependencies, including file system
access, timers and a speech recognizer, which makes it nearly impossible to write automated tests
and even hinders the ability to preview the app in Xcode previews.

But, the simplicity of Apple's Scrumdinger codebase is not a defect. In fact, it's a feature!
Apple's sample code is viewed by hundreds of thousands of developers across the world, and so its
goal is to be as approachable as possible in order to teach the basics of SwiftUI. But, that doesn't mean there isn't room for improvement.

## Composable Standups

Our Standups application is a rebuild of Apple's Scrumdinger application, but with a focus on
modern, best practices for SwiftUI development. We faithfully recreate the Scrumdinger, but with
some key additions:

 1. Identifiers are made type safe using our [Tagged library][tagged-gh]. This prevents us from
    writing nonsensical code, such as comparing a `Standup.ID` to a `Attendee.ID`.
 2. Instead of using bare arrays in feature logic we use an "identified" array from our
    [IdentifiedCollections][identified-collections-gh] library. This allows you to read and modify
    elements of the collection via their ID rather than positional index, which can be error-prone
    and lead to bugs or crashes.
 3. _All_ navigation is driven off of state, including sheets, drill-downs and alerts. This makes
    it possible to deep link into any screen of the app by just constructing a piece of state and
    handing it off to SwiftUI.
 4. Further, each view represents its navigation destinations as a single enum, which gives us
    compile time proof that two destinations cannot be active at the same time. This cannot be
    accomplished with default SwiftUI tools, but can be done easily with the tools that the
    Composable Architecture provides.
 5. All side effects are controlled. This includes access to the file system for persistence, access
    to time-based asynchrony for timers, access to speech recognition APIs, and even the creation
    of dates and UUIDs. This allows us to run our application in specific execution contexts, which
    is very useful in tests and Xcode previews. We accomplish this using our
    [Dependencies][dependencies-gh] library.
 6. The project includes a full test suite. Since all of navigation is driven off of state, and
    because we controlled all dependencies, we can write very comprehensive and nuanced tests. For
    example, we can write a unit test that proves that when a standup meeting's timer runs out the
    screen pops off the stack and a new transcript is added to the standup. Such a test would be
    very difficult, if not impossible, without controlling dependencies.

[scrumdinger]: https://developer.apple.com/tutorials/app-dev-training/getting-started-with-scrumdinger
[scrumdinger-dl]: https://docs-assets.developer.apple.com/published/1ea2eec121b90031e354288912a76357/TranscribingSpeechToText.zip
[tagged-gh]: http://github.com/pointfreeco/swift-tagged
[identified-collections-gh]: http://github.com/pointfreeco/swift-identified-collections 
[dependencies-gh]: http://github.com/pointfreeco/swift-dependencies 
