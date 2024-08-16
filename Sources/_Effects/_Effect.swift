import Foundation

public struct _Effect<Action>: Sendable {
  fileprivate let operation: any EffectProtocol<Action>

  public static func sync(operation: @escaping @Sendable (SyncContinuation) -> Void) -> Self {
    Self(operation: Effects.Sync(operation: operation))
  }

  public static func async(
    operation: @escaping @Sendable (AsyncContinuation) async -> Void
  ) -> Self {
    Self(operation: Effects.Async(operation: operation))
  }

  public func run(
    onAction: @escaping @Sendable (Action) -> Void,
    onTermination: @escaping @Sendable (Termination) -> Void
  ) -> Task {
    operation.subscribe(receiveAction: onAction, receiveTermination: onTermination)
  }

  public func merge(with other: Self) -> Self {
    func open(
      _ first: some EffectProtocol<Action>,
      _ second: some EffectProtocol<Action>
    ) -> Self {
      Self(operation: Effects.Merge(first: first, second: second))
    }
    return open(operation, other.operation)
  }

  public func concatenate(with other: Self) -> Self {
    func open(
      _ first: some EffectProtocol<Action>,
      _ second: some EffectProtocol<Action>
    ) -> Self {
      Self(operation: Effects.Concatenate(first: first, second: second))
    }
    return open(operation, other.operation)
  }

  public func map<T>(_ transform: @escaping @Sendable (Action) -> T) -> _Effect<T> {
    func open(_ operation: some EffectProtocol<Action>) -> _Effect<T> {
      _Effect<T>(operation: Effects.Map(base: operation, transform: transform))
    }
    return open(operation)
  }

  public enum Termination {
    case finished
    case cancelled
  }

  public struct Task: Sendable {
    private let storage = Storage()
    public init(_ onCancel: @escaping @Sendable () -> Void) {
      self.storage.onCancel = onCancel
    }
    public func cancel() {
      storage.onCancel?()
    }
    private class Storage: @unchecked Sendable {
      var onCancel: (@Sendable () -> Void)?
      deinit {
        onCancel?()
      }
    }
  }

  public struct AsyncContinuation: Sendable {
    private let send: @MainActor @Sendable (Action) -> Void
    private let storage = Storage()
    init(_ send: @escaping @MainActor @Sendable (Action) -> Void) {
      self.send = send
    }
    public var onTermination: @Sendable (Termination) -> Void {
      get { storage.onTermination ?? { @Sendable _ in } }
      nonmutating set { storage.onTermination = newValue }
    }
    @MainActor
    public func callAsFunction(_ action: Action) {
      send(action)
    }
    fileprivate func cancel() {
      storage.cancel()
    }
    fileprivate func finish() {
      storage.finish()
    }
    private final class Storage: @unchecked Sendable {
      var terminal: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _terminal
      }
      var onTermination: (@Sendable (Termination) -> Void)? {
        get { terminate }
        set {
          _lock.lock()
          defer { _lock.unlock() }
          _onTermination = newValue
        }
      }
      private let _lock = NSLock()
      private var _terminal = false
      private var _onTermination: (@Sendable (Termination) -> Void)? = nil
      deinit {
        cancel()
      }
      func terminate(_ termination: Termination) {
        switch termination {
        case .cancelled: cancel()
        case .finished: finish()
        }
      }
      func cancel() {
        _lock.lock()
        let handler = _onTermination
        _onTermination = nil
        _lock.unlock()
        handler?(.cancelled)
        finish()
      }
      func finish() {
        _lock.lock()
        let handler = _onTermination
        _onTermination = nil
        _terminal = true
        _lock.unlock()
        handler?(.finished)
      }
    }
  }

  public struct SyncContinuation: Sendable {
    private let send: @Sendable (Action) -> Void
    private let storage = Storage()
    init(_ send: @escaping @Sendable (Action) -> Void) {
      self.send = send
    }
    public var onTermination: @Sendable (Termination) -> Void {
      get { storage.onTermination ?? { @Sendable _ in } }
      nonmutating set { storage.onTermination = newValue }
    }
    public func callAsFunction(_ action: Action) {
      send(action)
    }
    public func cancel() {
      storage.cancel()
    }
    public func finish() {
      storage.finish()
    }
    private final class Storage: @unchecked Sendable {
      var terminal: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _terminal
      }
      var onTermination: (@Sendable (Termination) -> Void)? {
        get {
          print("!!!")
          return terminate
        }
        set {
          _lock.lock()
          defer { _lock.unlock() }
          _onTermination = newValue
        }
      }
      private let _lock = NSLock()
      private var _terminal = false
      private var _onTermination: (@Sendable (Termination) -> Void)? = nil
      deinit {
        cancel()
      }
      func terminate(_ termination: Termination) {
        switch termination {
        case .cancelled: cancel()
        case .finished: finish()
        }
      }
      func cancel() {
        _lock.lock()
        let handler = _onTermination
        _onTermination = nil
        _lock.unlock()
        handler?(.cancelled)
        finish()
      }
      func finish() {
        _lock.lock()
        let handler = _onTermination
        _onTermination = nil
        _terminal = true
        _lock.unlock()
        handler?(.finished)
      }
    }
  }
}

extension _Effect where Action: Sendable {
  public var actions: AsyncThrowingStream<Action, Error> {
    AsyncThrowingStream { continuation in
      let task = self.run {
        continuation.yield($0)
      } onTermination: { termination in
        switch termination {
        case .cancelled:
          continuation.finish(throwing: CancellationError())
        case .finished:
          continuation.finish()
        }
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}

private protocol EffectProtocol<Action>: Sendable {
  associatedtype Action
  func receive(_ subscriber: some EffectSubscriberProtocol<Action>)
}

private protocol EffectSubscriberProtocol<Action>: Sendable {
  associatedtype Action
  func receive(action: Action)
  func receive(termination: _Effect<Action>.Termination)
}

private final class EffectSubscriber<Action>: EffectSubscriberProtocol, @unchecked Sendable {
  private let receiveAction: @Sendable (Action) -> Void
  private let receiveTermination: @Sendable (_Effect<Action>.Termination) -> Void
  private let lock = NSLock()
  private var isFinished = false
  init(
    receiveAction: @escaping @Sendable (Action) -> Void,
    receiveTermination: @escaping @Sendable (_Effect<Action>.Termination) -> Void
  ) {
    self.receiveAction = receiveAction
    self.receiveTermination = receiveTermination
  }
  func receive(action: Action) {
    receiveAction(action)
  }
  func receive(termination: _Effect<Action>.Termination) {
    lock.lock()
    guard !isFinished else {
      lock.unlock()
      return
    }
    isFinished = true
    lock.unlock()
    receiveTermination(termination)
  }
}

extension EffectProtocol {
  func subscribe(
    receiveAction: @escaping @Sendable (Action) -> Void,
    receiveTermination: @escaping @Sendable (_Effect<Action>.Termination) -> Void
  ) -> _Effect<Action>.Task {
    let subscriber = EffectSubscriber(
      receiveAction: receiveAction,
      receiveTermination: receiveTermination
    )
    receive(subscriber)
    return _Effect<Action>.Task {
      subscriber.receive(termination: .cancelled)
    }
  }
}

extension _Effect {
  public static var none: Self {
    Self(operation: Effects.None())
  }

  public static func merge(_ effects: _Effect...) -> Self {
    merge(effects)
  }
  public static func merge(_ effects: [_Effect]) -> Self {
    effects.reduce(.none) {
      $0.merge(with: $1)
    }
  }
  public static func concatenate(_ effects: _Effect...) -> Self {
    concatenate(effects)
  }
  public static func concatenate(_ effects: [_Effect]) -> Self {
    effects.reduce(.none) {
      $0.concatenate(with: $1)
    }
  }
}

private enum Effects {
  struct None<Action>: EffectProtocol {
    func receive(_ subscriber: some EffectSubscriberProtocol<Action>) {
      subscriber.receive(termination: .finished)
    }
  }

  struct Sync<Action>: EffectProtocol {
    let operation: @Sendable (_Effect<Action>.SyncContinuation) -> Void
    func receive(_ subscriber: some EffectSubscriberProtocol<Action>) {
      let continuation = _Effect<Action>.SyncContinuation(subscriber.receive)
      continuation.onTermination = subscriber.receive
      operation(continuation)
    }
  }

  struct Async<Action>: EffectProtocol {
    class Box<T> {
      var value: T
      init(_ value: T) {
        self.value = value
      }
    }

    let operation: @Sendable (_Effect<Action>.AsyncContinuation) async -> Void
    func receive(_ subscriber: some EffectSubscriberProtocol<Action>) {
      let continuation = _Effect<Action>.AsyncContinuation {
        subscriber.receive(action: $0)
      }
      let task = Task { @MainActor in
        await operation(continuation)
        continuation.finish()
      }
      continuation.onTermination = {
        task.cancel()
        subscriber.receive(termination: $0)
      }
    }
  }

  struct Merge<
    First: EffectProtocol,
    Second: EffectProtocol<First.Action>
  >: EffectProtocol {
    typealias Action = First.Action

    let first: First
    let second: Second

    func receive(_ subscriber: some EffectSubscriberProtocol<Action>) {
      first.receive(subscriber)
      second.receive(subscriber)
    }
  }

  struct Concatenate<
    First: EffectProtocol,
    Second: EffectProtocol<First.Action>
  >: EffectProtocol {
    typealias Action = First.Action

    let first: First
    let second: Second

    func receive(_ subscriber: some EffectSubscriberProtocol<Action>) {
      first.receive(FirstSubscriber(base: subscriber) { second.receive(subscriber) })
    }

    struct FirstSubscriber<Base: EffectSubscriberProtocol<Action>>: EffectSubscriberProtocol {
      let base: Base
      let onFinish: @Sendable () -> Void
      func receive(action: Action) {
        base.receive(action: action)
      }
      func receive(termination: _Effect<Action>.Termination) {
        switch termination {
        case .cancelled:
          base.receive(termination: .cancelled)
        case .finished:
          onFinish()
        }
      }
    }
  }

  struct Map<Base: EffectProtocol, Action>: EffectProtocol {
    let base: Base
    let transform: @Sendable (Base.Action) -> Action
    func receive(_ subscriber: some EffectSubscriberProtocol<Action>) {
      base.receive(Subscriber(subscriber: subscriber, transform: transform))
    }
    struct Subscriber<BaseSubscriber: EffectSubscriberProtocol<Action>>: EffectSubscriberProtocol {
      let subscriber: BaseSubscriber
      let transform: @Sendable (Base.Action) -> Action
      func receive(action: Base.Action) {
        subscriber.receive(action: transform(action))
      }
      func receive(termination: _Effect<Base.Action>.Termination) {
        switch termination {
        case .cancelled:
          subscriber.receive(termination: .cancelled)
        case .finished:
          subscriber.receive(termination: .finished)
        }
      }
    }
  }
}
