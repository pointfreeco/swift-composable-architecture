import Combine
import ComposableArchitecture
import CoreMotion

public struct MotionManager {
    
    public enum Action: Equatable {
        case didUpdateAcceleration(CMAcceleration)
    }
    
    var create: (AnyHashable) -> Effect<Action, Never> = { _ in _unimplemented("create") }

    var destroy: (AnyHashable) -> Effect<Never, Never> = { _ in _unimplemented("destroy") }

    var startAccelerometerUpdates: (AnyHashable, OperationQueue, @escaping CMAccelerometerHandler) -> Effect<Never, Never> = { _,_,_  in
        _unimplemented("startAccelerometerUpdates")
    }
    
    var stopAccelerometerUpdates: (AnyHashable) -> Effect<Never, Never> = { _ in
        _unimplemented("stopAccelerometerUpdates")
    }
    
    /// Creates a `CMMotionManager` for the given identifier.
    ///
    /// - Parameter id: A unique identifier for the underlying `CMMotionManager`.
    /// - Returns: An effect of `MotionManager.Action`s.
    public func create(id: AnyHashable) -> Effect<Action, Never> {
      self.create(id)
    }

    /// Tears a `CMMotionManager` down for the given identifier.
    ///
    /// - Parameter id: A unique identifier for the underlying `CMMotionManager`.
    /// - Returns: A fire-and-forget effect.
    public func destroy(id: AnyHashable) -> Effect<Never, Never> {
      self.destroy(id)
    }
    
    public  func startAccelerometerUpdates(id: AnyHashable,
                                           to: OperationQueue,
                                           withHandler: @escaping CMAccelerometerHandler) -> Effect<Never, Never> {
        self.startAccelerometerUpdates(id, to, withHandler)
    }

    public func stopAccelerometerUpdates(id: AnyHashable) -> Effect<Never, Never> {
        self.stopAccelerometerUpdates(id)
    }
}



extension MotionManager {
    public struct Properties: Equatable {
        var acceleartion: CMAcceleration? = nil
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
          var isEqual = true
          #if os(iOS) || targetEnvironment(macCatalyst)
            isEqual =
              isEqual
              && lhs.acceleartion == rhs.acceleartion
          #endif
          return isEqual
        }
    }
}
