import ComposableArchitecture
import SwiftUI

struct DownloadComponentState<ID: Equatable>: Equatable {
  var alert: DownloadAlert?
  let id: ID
  var mode: Mode
  let url: URL
}

struct DownloadAlert: Equatable, Identifiable {
  var primaryButton: Button
  var secondaryButton: Button
  var title: String

  var id: String { self.title }

  struct Button: Equatable {
    var action: DownloadComponentAction
    var label: String
    var type: `Type`

    enum `Type` {
      case cancel
      case `default`
      case destructive
    }

    func toSwiftUI(action: @escaping (DownloadComponentAction) -> Void) -> Alert.Button {
      switch self.type {
      case .cancel:
        return .cancel(Text(self.label)) { action(self.action) }
      case .default:
        return .default(Text(self.label)) { action(self.action) }
      case .destructive:
        return .destructive(Text(self.label)) { action(self.action) }
      }
    }
  }
}

enum Mode: Equatable {
  case downloaded
  case downloading(progress: Double)
  case notDownloaded
  case startingToDownload

  var progress: Double {
    if case let .downloading(progress) = self { return progress }
    return 0
  }

  var isDownloading: Bool {
    switch self {
    case .downloaded, .notDownloaded:
      return false
    case .downloading, .startingToDownload:
      return true
    }
  }
}

enum DownloadComponentAction: Equatable {
  case alert(AlertAction)
  case buttonTapped
  case downloadClient(Result<DownloadClient.Action, DownloadClient.Error>)

  enum AlertAction: Equatable {
    case cancelButtonTapped
    case deleteButtonTapped
    case dismiss
    case nevermindButtonTapped
  }
}

struct DownloadComponentEnvironment {
  var downloadClient: DownloadClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

extension Reducer {
  func downloadable<ID: Hashable>(
    state: WritableKeyPath<State, DownloadComponentState<ID>>,
    action: CasePath<Action, DownloadComponentAction>,
    environment: @escaping (Environment) -> DownloadComponentEnvironment
  ) -> Reducer {
    .combine(
      Reducer<DownloadComponentState<ID>, DownloadComponentAction, DownloadComponentEnvironment> {
        state, action, environment in
        switch action {
        case .alert(.cancelButtonTapped):
          state.mode = .notDownloaded
          state.alert = nil
          return environment.downloadClient.cancel(state.id)
            .fireAndForget()

        case .alert(.deleteButtonTapped):
          state.alert = nil
          state.mode = .notDownloaded
          return .none

        case .alert(.nevermindButtonTapped),
          .alert(.dismiss):
          state.alert = nil
          return .none

        case .buttonTapped:
          switch state.mode {
          case .downloaded:
            state.alert = deleteAlert
            return .none

          case .downloading:
            state.alert = cancelAlert
            return .none

          case .notDownloaded:
            state.mode = .startingToDownload
            return environment.downloadClient
              .download(state.id, state.url)
              .throttle(for: 1, scheduler: environment.mainQueue, latest: true)
              .catchToEffect()
              .map(DownloadComponentAction.downloadClient)

          case .startingToDownload:
            state.alert = cancelAlert
            return .none
          }

        case .downloadClient(.success(.response)):
          state.mode = .downloaded
          state.alert = nil
          return .cancel(id: ThrottleId(id: state.id))

        case let .downloadClient(.success(.updateProgress(progress))):
          state.mode = .downloading(progress: progress)
          return .none

        case .downloadClient(.failure):
          state.mode = .notDownloaded
          state.alert = nil
          return .cancel(id: ThrottleId(id: state.id))
        }
      }
      .pullback(state: state, action: action, environment: environment),
      self
    )
  }
}

private struct ThrottleId<ID>: Hashable where ID: Hashable {
  var id: ID
}

private let deleteAlert = DownloadAlert(
  primaryButton: .init(
    action: .alert(.deleteButtonTapped),
    label: "Delete",
    type: .destructive
  ),
  secondaryButton: nevermindButton,
  title: "Do you want to delete this map from your offline storage?"
)

private let cancelAlert = DownloadAlert(
  primaryButton: .init(
    action: .alert(.cancelButtonTapped),
    label: "Cancel",
    type: .destructive
  ),
  secondaryButton: nevermindButton,
  title: "Do you want to cancel downloading this map?"
)

let nevermindButton = DownloadAlert.Button(
  action: .alert(.nevermindButtonTapped),
  label: "Nevermind",
  type: .default
)

struct DownloadComponent<ID: Equatable>: View {
  let store: Store<DownloadComponentState<ID>, DownloadComponentAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Button(action: { viewStore.send(.buttonTapped) }) {
        if viewStore.mode == .downloaded {
          Image(systemName: "checkmark.circle")
            .accentColor(Color.blue)
        } else if viewStore.mode.progress > 0 {
          ZStack {
            CircularProgressView(value: viewStore.mode.progress)
              .frame(width: 16, height: 16)

            Rectangle()
              .frame(width: 6, height: 6)
              .foregroundColor(Color.black)
          }
        } else if viewStore.mode == .notDownloaded {
          Image(systemName: "icloud.and.arrow.down")
            .accentColor(Color.black)
        } else if viewStore.mode == .startingToDownload {
          ZStack {
            ActivityIndicator()

            Rectangle()
              .frame(width: 6, height: 6)
              .foregroundColor(Color.black)
          }
        }
      }
      .alert(
        item: viewStore.binding(get: { $0.alert }, send: .alert(.dismiss))
      ) { alert in
        Alert(
          title: Text(alert.title),
          primaryButton: alert.primaryButton.toSwiftUI(action: viewStore.send),
          secondaryButton: alert.secondaryButton.toSwiftUI(action: viewStore.send)
        )
      }
    }
  }
}

struct DownloadComponent_Previews: PreviewProvider {
  static var previews: some View {
    DownloadList_Previews.previews
  }
}
