//
//  Cancellation.swift
//  Demo
//
//  Created by Håvard Fossli on 07/01/2021.
//  Copyright © 2021 Darrarski. All rights reserved.
//

import Combine
import Foundation
import ComposableArchitecture

fileprivate var bags: [AnyHashable: CancellationBag] = [:]
fileprivate let bagsLock = NSRecursiveLock()
fileprivate let cancellablesLock = NSRecursiveLock()

public final class CancellationBag {
  fileprivate var children: [CancellationBag] = []
  fileprivate var cancellationCancellables: [AnyHashable: Set<AnyCancellable>] = [:]
  fileprivate let id: AnyHashable
  
  public static var global: CancellationBag = {
    struct GlobalID: Hashable {}
    return CancellationBag.bag(id: GlobalID())
  }()
  
  private init(id: AnyHashable) {
    self.id = id
  }
  
  public static func bag(id: AnyHashable, childOf parent: CancellationBag? = nil) -> CancellationBag {
    let bag = bagsLock.sync { () -> CancellationBag in
      if let bag = bags[id] {
        return bag
      } else {
        let bag = CancellationBag(id: id)
        bags[id] = bag
        return bag
      }
    }
    if let parent = parent {
      return bag.asChild(of: parent)
    }
    return bag
  }
  
  public func cancelAll() {
    cancellablesLock.sync {
      self.children.forEach {
        $0.cancelAll()
      }
      self.cancellationCancellables.forEach {
        $1.forEach {
          $0.cancel()
        }
      }
    }
  }
  
  public func cancel(id: AnyHashable) {
    cancellablesLock.sync {
      self.cancellationCancellables[id]?.forEach { $0.cancel() }
    }
  }
  
  public func asChild(of parent: CancellationBag) -> CancellationBag {
    bagsLock.sync {
      guard !parent.children.contains(where: { $0.id == self.id }) else {
        return
      }
      parent.children.append(self)
    }
    return self
  }
}


extension CancellationBag {
  public static func autoId(childOf parent: CancellationBag? = nil, file: StaticString = #file, line: UInt = #line, column: UInt = #column) -> CancellationBag {
    struct IdByFileAndLine: Hashable {
      var file: String
      var line: UInt
      var column: UInt
    }
    let id = IdByFileAndLine(file: String(describing: file), line: line, column: column)
    let bag = CancellationBag.bag(id: id)
    if let parent = parent {
      return bag.asChild(of: parent)
    }
    return bag
  }
}

extension Effect {
  /// Turns an effect into one that is capable of being canceled.
  ///
  /// To turn an effect into a cancellable one you must provide an identifier, which is used in
  /// `Effect.cancel(id:)` to identify which in-flight effect should be canceled. Any hashable
  /// value can be used for the identifier, such as a string, but you can add a bit of protection
  /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
  ///
  ///     struct LoadUserId: Hashable {}
  ///
  ///     case .reloadButtonTapped:
  ///       // Start a new effect to load the user
  ///       return environment.loadUser
  ///         .map(Action.userResponse)
  ///         .cancellable(id: LoadUserId(), cancelInFlight: true)
  ///
  ///     case .cancelButtonTapped:
  ///       // Cancel any in-flight requests to load the user
  ///       return .cancel(id: LoadUserId())
  ///
  /// - Parameters:
  ///   - id: The effect's identifier.
  ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
  ///     canceled before starting this new one.
  /// - Returns: A new effect that is capable of being canceled by an identifier.
  public func cancellable(id: AnyHashable, cancelInFlight: Bool = false, bag: CancellationBag = .global) -> Effect {
    let effect = Deferred { () -> Publishers.HandleEvents<PassthroughSubject<Output, Failure>> in
      cancellablesLock.lock()
      defer { cancellablesLock.unlock() }
      
      let subject = PassthroughSubject<Output, Failure>()
      let cancellable = self.subscribe(subject)
      
      var cancellationCancellable: AnyCancellable!
      cancellationCancellable = AnyCancellable {
        cancellablesLock.sync {
          subject.send(completion: .finished)
          cancellable.cancel()
          bag.cancellationCancellables[id]?.remove(cancellationCancellable)
          if bag.cancellationCancellables[id]?.isEmpty == .some(true) {
            bag.cancellationCancellables[id] = nil
          }
        }
      }
      
      bag.cancellationCancellables[id, default: []].insert(
        cancellationCancellable
      )
      
      return subject.handleEvents(
        receiveCompletion: { _ in cancellationCancellable.cancel() },
        receiveCancel: cancellationCancellable.cancel
      )
    }
    .eraseToEffect()
    
    return cancelInFlight ? .concatenate(.cancel(id: id), effect) : effect
  }
  
  /// An effect that will cancel any currently in-flight effect with the given identifier.
  ///
  /// - Parameter id: An effect identifier.
  /// - Returns: A new effect that will cancel any currently in-flight effect with the given
  ///   identifier.
  public static func cancel(id: AnyHashable, bag: CancellationBag = .global) -> Effect {
    return .fireAndForget {
      bag.cancel(id: id)
    }
  }
  
  public static func cancelAll(bag: CancellationBag = .global) -> Effect {
    return .fireAndForget {
      bag.cancelAll()
    }
  }
}
