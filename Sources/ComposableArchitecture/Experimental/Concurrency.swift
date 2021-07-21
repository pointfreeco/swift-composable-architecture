import Combine
import SwiftUI

#if compiler(>=5.5)
  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  extension ViewStore {
    public func send(
      _ action: Action,
      while predicate: @escaping (State) -> Bool
    ) async {
      self.send(action)
      await self.suspend(while: predicate)
    }

    public func send(
      _ action: Action,
      animation: Animation?,
      while predicate: @escaping (State) -> Bool
    ) async {
      withAnimation(animation) { self.send(action) }
      await self.suspend(while: predicate)
    }

    public func suspend(while predicate: @escaping (State) -> Bool) async {
      var cancellable: Cancellable?
      try? await withTaskCancellationHandler(
        handler: { [cancellable] in cancellable?.cancel() },
        operation: {
          try Task.checkCancellation()
          try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            guard !Task.isCancelled else {
              continuation.resume(throwing: CancellationError())
              return
            }
            cancellable = self.publisher
              .filter { !predicate($0) }
              .prefix(1)
              .sink { _ in
                continuation.resume()
                _ = cancellable
              }
          }
        }
      )
    }
  }
#endif
