#if os(iOS)
import Combine
import ComposableArchitecture
import CoreMotion

public struct MotionManager {
    
    public enum Action: Equatable {
        case didUpdateAcceleration(CMAcceleration)
        case didUpdateDeviceMotion(CMDeviceMotion)
    }

    public struct Error: Swift.Error, Equatable {
      public let error: NSError

      public init(_ error: Swift.Error) {
        self.error = error as NSError
      }
    }
    
    var create: (AnyHashable) -> Effect<Action, Never> = { _ in _unimplemented("create") }

    var destroy: (AnyHashable) -> Effect<Never, Never> = { _ in _unimplemented("destroy") }

    var startAccelerometerUpdates: (AnyHashable) -> Effect<Never, Never> = { _  in
        _unimplemented("startAccelerometerUpdates")
    }
    
    var stopAccelerometerUpdates: (AnyHashable) -> Effect<Never, Never> = { _ in
        _unimplemented("stopAccelerometerUpdates")
    }
    
    var startDeviceMotionUpdates: (AnyHashable) -> Effect<Never, Never> = { _  in
        _unimplemented("startDeviceMotionUpdates")
    }
    
    var stopDeviceMotionUpdates: (AnyHashable) -> Effect<Never, Never> = { _ in
        _unimplemented("stopDeviceMotionUpdates")
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
        
    public var deviceMotionUpdateInterval: () -> TimeInterval = {
        _unimplemented("deviceMotionUpdateInterval")
    }

    public func startAccelerometerUpdates(id: AnyHashable) -> Effect<Never, Never> {
        self.startAccelerometerUpdates(id)
    }

    public func stopAccelerometerUpdates(id: AnyHashable) -> Effect<Never, Never> {
        self.stopAccelerometerUpdates(id)
    }
    
    
    public func startDeviceMotionUpdates(id: AnyHashable) -> Effect<Never, Never> {
        self.startDeviceMotionUpdates(id)
    }

    public func stopDeviceMotionUpdates(id: AnyHashable) -> Effect<Never, Never> {
        self.stopDeviceMotionUpdates(id)
    }
    
    var set: (AnyHashable, Properties) -> Effect<Never, Never> = { _, _ in _unimplemented("set") }
        
    public func set(
      id: AnyHashable,
      deviceMotionUpdateInterval: TimeInterval? = nil
    ) -> Effect<Never, Never> {
      self.set(
        id,
        Properties(
          deviceMotionUpdateInterval: deviceMotionUpdateInterval
        )
      )
    }
}



extension MotionManager {
    public struct Properties: Equatable {        
        var deviceMotionUpdateInterval: TimeInterval? = nil
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
          var isEqual = true
            isEqual =
              isEqual
                && lhs.deviceMotionUpdateInterval == rhs.deviceMotionUpdateInterval

          return isEqual
        }
        
        public init(
          deviceMotionUpdateInterval: TimeInterval? = nil
        ) {
          self.deviceMotionUpdateInterval = deviceMotionUpdateInterval
        }
    }
}

#endif
