# Migrating to 1.10

Update your code to make use of the new state sharing tools in the library, such as the ``Shared``
property wrapper, and the ``AppStorageKey`` and ``FileStorageKey`` persistence strategies.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. This version of the library only introduced new 
APIs and did not deprecate any existing APIs.

> Important: Before following this migration guide be sure you have fully migrated to the newest
> tools of version 1.9. See <doc:MigrationGuides> for more information.

## Sharing state

The new tools added are concerned with allowing one to seamlessly share state with many parts of an 
application that is easy to understand, and most importantly, testable. See the dedicated 
<doc:SharingState> article for more information on how to use these new tools. 

To share state in one feature with another feature, simply use the ``Shared`` property wrapper:

```swift
@ObservableState
struct State {
  @Shared var signUpData: SignUpData
  // ...
}
```

This will require that `SignUpData` be passed in from the parent, and any changes made to this state
will be instantly observed by all features holding onto it.

Further, there are persistence strategies one can employ in `@Shared`. For example, if you want any
changes of `signUpData` to be automatically persisted to the file system you can use the
``PersistenceReaderKey/fileStorage(_:)`` and specify a URL:

```swift
@ObservableState
struct State {
  @Shared(.fileStorage(URL(/* ... */) var signUpData = SignUpData()
  // ...
}
```

Upon app launch the `signUpData` will be populated from disk, and any changes made to `signUpData`
will automatically be persisted to disk. Further, if the disk version changes, all instances of 
`signUpData` in the application will automatically update.

There is another persistence strategy for storing simple data types in user defaults, called
``PersistenceReaderKey/appStorage(_:)-4l5b``. It can refer to a value in user defaults by a string
key:

```swift
@ObservableState 
struct State {
  @Shared(.appStorage("isOn")) var isOn = false
  // ...
}
```

Similar to ``PersistenceReaderKey/fileStorage(_:)``, upon launch of the application the initial
value of `isOn` will be populated from user defaults, and any change to `isOn` will be automatically
persisted to user defaults. Further, if the user defaults value changes, all instances of `isOn`
in the application will automatically update.

That is the basics of sharing data. Be sure to see the dedicated <doc:SharingState> article
for more detailed information.
