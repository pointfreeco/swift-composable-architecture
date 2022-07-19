#  Getting ready for Swift concurrency

Learn how to write safe, concurrent effects using Swift structured concurrency.

## Sendable and @Sendable

There are 3 primary ways to create an effect in the library:

* ``Effect/task(priority:operation:catch:file:fileID:line:)``
  
  Creates an asynchronous context that can send a single action back into the system.

* ``Effect/run(priority:operation:catch:file:fileID:line:)``

  Creates an asynchronous context that can send zero or more actions back into the system.

* ``Effect/fireAndForget(priority:_:)``

  Creates an asynchronous context that can never send actions back into the system. 

Each of these effect constructors takes a `@Sendable` async closure, which restricts the types of closures you can use for your effects. In particular, the closure can only capture immutable `Sendable` values or isolated, mutable values.
