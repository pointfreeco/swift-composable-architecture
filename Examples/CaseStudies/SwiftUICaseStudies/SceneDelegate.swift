import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    self.window = (scene as? UIWindowScene).map(UIWindow.init(windowScene:))
    self.window?.rootViewController = UIHostingController(
      rootView: ContentView_Previews.previews
//        RootView(
//        store: .init(
//          initialState: RootState(),
//          reducer: rootReducer,
//          environment: .live
//        )
//      )
    )
    self.window?.makeKeyAndVisible()
  }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    true
  }
}












import ComposableArchitecture
import SwiftUI

extension Reducer {
  public func navigates<Route, DestinationState, DestinationAction, DestinationEnvironment>(
    destination: Reducer<DestinationState, DestinationAction, DestinationEnvironment>,
    tag: CasePath<Route, DestinationState>,
    selection: WritableKeyPath<State, Route?>,
    onDismiss: DestinationAction? = nil,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    environment toDestinationEnvironment: @escaping (Environment) -> DestinationEnvironment
  ) -> Self {
    Self { state, action, environment in

      let previousSelection = state[keyPath: selection]
      let previousDestinationState = previousSelection.flatMap(tag.extract(from:))
      let previousTag = previousDestinationState != nil
        ? previousSelection.flatMap(enumTag)
        : nil
      var effects: [Effect<Action, Never>] = []

      effects.append(
        destination
          .pullback(
            state: tag,
            action: /.self,
            environment: toDestinationEnvironment
          )
          .optional()
          .pullback(
            state: selection,
            action: toPresentationAction.appending(path: /PresentationAction.presented),
            environment: { $0 }
          )
          .run(&state, action, environment)
      )

      effects.append(
        self
          .run(&state, action, environment)
      )

      if
        let route = state[keyPath: selection],
        tag.extract(from: route) != nil,
        case .some(.dismiss) = toPresentationAction.extract(from: action)
      {
        state[keyPath: selection] = nil
      }
      if
        let onDismiss = onDismiss,
        var previousDestinationState = previousDestinationState,
        let previousTag = previousTag,
        previousTag != state[keyPath: selection].flatMap(enumTag)
      {
        effects.append(
          destination.run(
            &previousDestinationState,
            onDismiss,
            toDestinationEnvironment(environment)
          )
            .map(toPresentationAction.appending(path: /PresentationAction.presented).embed(_:))
        )
      }

      return .merge(effects)
    }
  }
}

public struct NavigationLinkStore<Route, State, Action, Label, Destination>: View
where
  Label: View,
  Destination: View
{
  let destination: Destination
  let label: () -> Label
  let selection: Store<Bool, PresentationAction<Action>>

  public init<Content>(
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Content,
    tag: @escaping (Route) -> State?,
    selection: Store<Route?, PresentationAction<Action>>,
    @ViewBuilder label: @escaping () -> Label
  ) where Destination == IfLetStore<State, Action, Content?> {
    self.destination = IfLetStore<State, Action, Content?>(
      selection.scope(
        state: { $0.flatMap(tag) },
        action: PresentationAction.presented
      ),
      then: destination
    )
    self.label = label
    self.selection = selection.scope(state: { $0.flatMap(tag) != nil })
  }

  public var body: some View {
    WithViewStore(self.selection) { viewStore in
      NavigationLink(
        destination: self.destination,
        isActive: viewStore
          .binding(send: { $0 ? .present : .dismiss })
          .removeDuplicates(),
        label: self.label
      )
    }
  }
}

extension Binding {
  public func removeDuplicates() -> Binding where Value: Equatable {
    return .init(
      get: {
        self.wrappedValue
      },
      set: { newValue, transaction in
        guard newValue != self.wrappedValue else { return }
        if transaction.animation != nil {
          withTransaction(transaction) {
            self.wrappedValue = newValue
          }
        } else {
          self.wrappedValue = newValue
        }
      }
    )
  }
}







func enumTag<Case>(_ `case`: Case) -> UInt32? {
  let metadataPtr = unsafeBitCast(type(of: `case`), to: UnsafeRawPointer.self)
  let kind = metadataPtr.load(as: Int.self)
  let isEnumOrOptional = kind == 0x201 || kind == 0x202
  guard isEnumOrOptional else { return nil }
  let vwtPtr = (metadataPtr - MemoryLayout<UnsafeRawPointer>.size).load(as: UnsafeRawPointer.self)
  let vwt = vwtPtr.load(as: EnumValueWitnessTable.self)
  return withUnsafePointer(to: `case`) { vwt.getEnumTag($0, metadataPtr) }
}

struct EnumValueWitnessTable {
  let f1, f2, f3, f4, f5, f6, f7, f8: UnsafeRawPointer
  let f9, f10: Int
  let f11, f12: UInt32
  let getEnumTag: @convention(c) (UnsafeRawPointer, UnsafeRawPointer) -> UInt32
  let f13, f14: UnsafeRawPointer
}


import ComposableArchitecture
import SwiftUI

public enum PresentationAction<Action> {
  case dismiss
  case presented(Action)
  case present
}

extension PresentationAction: Equatable where Action: Equatable {}
extension PresentationAction: Hashable where Action: Hashable {}

