#if os(iOS)
import Combine
import ComposableArchitecture
import CoreMotion

extension MotionManager {
    
    public static let live: MotionManager = { () -> MotionManager in
        var manager = MotionManager()
        
        manager.deviceMotionUpdateInterval = {
            CMMotionManager().deviceMotionUpdateInterval
        }
        
        manager.create = { id in
            Effect.run { subscriber in
                let manager = CMMotionManager()
                
                
                dependencies[id] = Dependencies(
                    manager: manager,
                    subscriber: subscriber,
                    queue: OperationQueue.main
                )
                
                return AnyCancellable {
                    dependencies[id] = nil
                }
            }
        }
        
        manager.destroy = { id in
            .fireAndForget {
                dependencies[id]?.subscriber.send(completion: .finished)
                dependencies[id] = nil
            }
        }
        
        manager.set = { id, properties in
          .fireAndForget {
            guard let manager = dependencies[id]?.manager else { return }
            
            if let deviceMotionUpdateInterval = properties.deviceMotionUpdateInterval {
                manager.deviceMotionUpdateInterval = deviceMotionUpdateInterval
            }
            
            }
        }
        
        manager.startAccelerometerUpdates = { id in
            .fireAndForget {
                guard let dependency = dependencies[id] else { return }
                dependency.manager
                    .startAccelerometerUpdates(to: dependency.queue,
                                               withHandler: { (data, error) in
                                                guard let acceleration = data?.acceleration else { return }
                                                dependency.subscriber.send(.didUpdateAcceleration(acceleration))
                    })
            }
        }
    
        manager.stopAccelerometerUpdates = { id in
            .fireAndForget {
                dependencies[id]?.manager.stopAccelerometerUpdates()
            }
        }
    
        manager.startDeviceMotionUpdates = { id in
            .fireAndForget {
                guard let dependency = dependencies[id] else { return }
                dependency.manager.startDeviceMotionUpdates(to: dependency.queue, withHandler: { (data, error) in
                    guard let data = data else { return }
                    dependency.subscriber.send(.didUpdateDeviceMotion(data))
                })
            }
        }
        
        manager.stopDeviceMotionUpdates = { id in
            .fireAndForget {
                dependencies[id]?.manager.stopDeviceMotionUpdates()
            }
        }
        return manager
    }()
}

private struct Dependencies {
    let manager: CMMotionManager
    let subscriber: Effect<MotionManager.Action, Never>.Subscriber
    let queue: OperationQueue
}

private var dependencies: [AnyHashable: Dependencies] = [:]
#endif
