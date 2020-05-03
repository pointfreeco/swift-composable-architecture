import ComposableArchitecture
import CoreMotion
import SwiftUI

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
        Spacer(minLength: 100)

        ZStack {
          plot(buffer: viewStore.z, scale: 40)
        }

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
    AppView(
      store: Store(
        initialState: AppState(
          isRecording: false,
          z: (1...350)
            .map { sin(Double($0) / 10) }
        ),
        reducer: appReducer,
        environment: .init(motionClient: .live)
      )
    )
  }
}
