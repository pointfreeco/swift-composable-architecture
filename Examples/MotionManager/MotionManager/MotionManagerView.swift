import ComposableArchitecture
import CoreMotion
import SwiftUI

private let readMe = """
  This demonstrates how to work with the MotionManager API from Apple's Motion framework.

  Unfortunately the Motion APIs are not available in SwiftUI previews or simulators. However, \
  thanks to how the Composable Architecture models its dependencies and effects, it is trivial \
  to substitute a mock MotionClient into the SwiftUI preview so that we can still play around with \
  its basic functionality.

  Here we are creating a mock MotionClient that simulates motion data by running a timer that emits \
  sinusoidal values.
  """

struct AppState: Equatable {
  var alertTitle: String?
  var isRecording = false
  var z: [Double] = []
}

enum AppAction: Equatable {
  case alertDismissed
  case motionClient(Result<MotionClient.Action, MotionClient.Error>)
  case onAppear
  case recordingButtonTapped
}

struct AppEnvironment {
  var motionClient: MotionClient
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  struct MotionClientId: Hashable {}

  switch action {
  case .alertDismissed:
    state.alertTitle = nil
    return .none

  case .motionClient(.failure):
    state.alertTitle =
      "We encountered a problem with the motion manager. Make sure you run this demo on a real device, not the simulator."
    state.isRecording = false
    return .none

  case let .motionClient(.success(.motionUpdate(motion))):
    state.z.append(
      motion.gravity.x * motion.userAcceleration.x
        + motion.gravity.y * motion.userAcceleration.y
        + motion.gravity.z * motion.userAcceleration.z
    )
    state.z.removeFirst(max(0, state.z.count - 350))
    return .none

  case .onAppear:
    return environment.motionClient.create(id: MotionClientId())
      .catchToEffect()
      .map(AppAction.motionClient)

  case .recordingButtonTapped:
    state.isRecording.toggle()
    return state.isRecording
      ? environment.motionClient.startDeviceMotionUpdates(id: MotionClientId())
        .fireAndForget()
      : environment.motionClient.stopDeviceMotionUpdates(id: MotionClientId())
        .fireAndForget()
  }
}

struct AppView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        Text(readMe)
          .multilineTextAlignment(.leading)
          .layoutPriority(1)

        Spacer(minLength: 100)

        plot(buffer: viewStore.z, scale: 40)

        Button(action: { viewStore.send(.recordingButtonTapped) }) {
          HStack {
            Image(
              systemName: viewStore.isRecording
                ? "stop.circle.fill" : "arrowtriangle.right.circle.fill"
            )
            .font(.title)
            Text(viewStore.isRecording ? "Stop Recording" : "Start Recording")
          }
          .foregroundColor(.white)
          .padding()
          .background(viewStore.isRecording ? Color.red : .blue)
          .cornerRadius(16)
        }
      }
      .padding()
      .onAppear { viewStore.send(.onAppear) }
      .alert(
        item: viewStore.binding(
          get: { $0.alertTitle.map(AppAlert.init(title:)) },
          send: .alertDismissed
        )
      ) { alert in
        Alert(title: Text(alert.title))
      }
    }
  }
}

struct AppAlert: Identifiable {
  var title: String
  var id: String { self.title }
}

func plot(buffer: [Double], scale: Double) -> Path {
  Path { path in
    let baseline: Double = 50
    let size: Double = 3
    for (offset, value) in buffer.enumerated() {
      let point = CGPoint(x: Double(offset) - size / 2, y: baseline - value * scale - size / 2)
      let rect = CGRect(origin: point, size: CGSize(width: size, height: size))
      path.addEllipse(in: rect)
    }
  }
}

struct AppView_Previews: PreviewProvider {
  static var previews: some View {
    // Since MotionManager isn't usable in SwiftUI previews or simulators we create one that just
    // sends a bunch of data on some sine curves.
    var isStarted = false
    let mockMotionClient = MotionClient(
      create: { id in
        Effect.timer(id: id, every: 0.01, on: DispatchQueue.main)
          .filter { _ in isStarted }
          .map { time in
            let t = Double(time.dispatchTime.uptimeNanoseconds) / 500_000_000.0
            return .motionUpdate(
              .init(
                gravity: .init(x: sin(2 * t), y: -cos(-t), z: sin(3 * t)),
                userAcceleration: .init(x: -cos(-3 * t), y: sin(2 * t), z: -cos(t))
              )
            )
        }
        .setFailureType(to: MotionClient.Error.self)
        .eraseToEffect()
    },
      startDeviceMotionUpdates: { _ in .fireAndForget { isStarted = true } },
      stopDeviceMotionUpdates: { _ in .fireAndForget { isStarted = false } }
    )

    return AppView(
      store: Store(
        initialState: AppState(
          z: (1...350).map {
            2 * sin(Double($0) / 20) + cos(Double($0) / 8)
          }
        ),
        reducer: appReducer,
        environment: .init(motionClient: mockMotionClient)
      )
    )
  }
}
