#if !os(macOS)
import CasePaths
import SwiftUI
import UIKit

public extension Reducer where State: Equatable {
  /// Attaches the `opensURL` logic to your existing feature reducer, returning a new reducer.
  ///
  /// Can be used in conjunction with the `.opensURL` view modifier to automatically open
  /// external URLs driven by your application state.
  ///
  /// To use this high-level reducer, you first need to embed it into your feature. This requires:
  ///
  /// * A `URL?` property  on your state that represents the URL you want to open.
  /// * An action in your feature's action enum that wraps `OpenURLViewAction`
  ///
  /// For example, given the following domain:
  ///
  ///     struct FeatureState: Equatable {
  ///         var urlToOpen: URL?
  ///     }
  ///
  ///     enum FeatureAction: Equatable {
  ///         case tappedOpenLinkButton
  ///         case openURL(OpenURLViewAction)
  ///     }
  ///
  /// You can then attach the open URL reducer to your feature's reducer, providing a key path
  /// to the URL and a case path for the action:
  ///
  ///     let featureReducer = Reducer<FeatureState, FeatureAction, Void> { state, action in
  ///         switch action {
  ///         case .tappedOpenLinkButton:
  ///             state.urlToOpen = URL(string: "http://www.example.com")
  ///             return .none
  ///         case .openURL:
  ///             return .none
  ///         }
  ///     }
  ///     .opensURL(\.urlToOpen, action: /FeatureAction.openURL)
  ///
  /// The above reducer will set the URL to be opened when the feature's view sends the `tappedOpenLinkButton`.
  ///
  /// To actually open the URL, the corresponding feature view needs to use the `.opensURL` view modifier, passing
  /// in a store scoped to the `URL` state and `OpenURLViewAction` action:
  ///
  ///     struct FeatureView: View {
  ///         let store: Store<FeatureState, FeatureAction>
  ///
  ///         var body: some View {
  ///             WithViewStore(store) { viewStore in
  ///                 Button("Open example.com") {
  ///                     viewStore.send(.tappedOpenLinkButton)
  ///                 }
  ///             }
  ///             .opensURL(
  ///                 store.scope(
  ///                     state: \.urlToOpen,
  ///                     action: /FeatureAction.openURL
  ///                 )
  ///             )
  ///         }
  ///     }
  ///
  /// Now, when the `urlToOpen` property is set to a `URL` value, it will automatically open and fire an action
  /// back into the store to indicate it was opened, which will set the `urlToOpen` property back to `nil`.
  ///
  /// - Note: A check will be made before attempting to open the URL that opening that URL is supported - if not, the action
  /// `OpenURLViewAction.urlNotSupported` will be sent to the store.
  ///
  /// You can handle this action in your own feature reducer if you want to provide some kind of fallback option.
  ///
  /// - Parameters:
  ///     - state: a key path to the URL that should be opened.
  ///     - action: the `CasePath` to the action that embeds the `OpenURLViewAction` in your domain.
  ///
  func opensURL(
    state: WritableKeyPath<State, URL?>,
    action: CasePath<Action, OpenURLViewAction>
  ) -> Self {
    Reducer<URL?, OpenURLViewAction, Void> { state, action, _ in
      switch action {
      case .openedURL:
        state = nil
        return .none
      case .urlNotSupported:
        return .none
      }
    }
    .pullback(
      state: state,
      action: action,
      environment: { _ in () }
    )
    .combined(with: self)
  }
}

/// Represents the domain of opening URLs and can be embedded in your feature domain actions.
///
public enum OpenURLViewAction: Equatable {
  /// Sent by the component to the store to indicate if URL was opened.
  case openedURL(Bool)

  /// Indicates the URL given cannot be opened on this platform.
  case urlNotSupported
}

@available(macOS, unavailable)
private struct OpenURLViewModifier: ViewModifier {
  let store: Store<URL?, OpenURLViewAction>
  let viewStore: ViewStore<URL?, OpenURLViewAction>

  init(store: Store<URL?, OpenURLViewAction>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  func body(content: Content) -> some View {
    // There appears to be a bug with `.onReceive` in a ViewModifier,
    // where it doesn't seem to fire correctly unless you append the
    // `.onAppear()` modifier first.
    content.onAppear().onReceive(viewStore.publisher) { newValue in
      if let url = newValue {
        if canOpenURL(url) {
          openURL(url) { viewStore.send(.openedURL($0)) }
        } else {
          viewStore.send(.urlNotSupported)
        }
      }
    }
  }

  private func openURL(_ url: URL, completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, macCatalyst 14, tvOS 14, *) {
      URLOpener_OpenURLAction(url: url).open(completion: completion)
    } else {
      URLOpener_UIApplication(url: url).open(completion: completion)
    }
  }

  private func canOpenURL(_ url: URL) -> Bool {
    UIApplication.shared.canOpenURL(url)
  }

  struct URLOpener_UIApplication {
    let url: URL

    func open(completion: @escaping (Bool) -> Void) {
      UIApplication.shared.open(url, completionHandler: completion)
    }
  }

  @available(iOS 14, *)
  @available(macCatalyst 14, *)
  @available(tvOS 14, *)
  struct URLOpener_OpenURLAction {
    let url: URL

    @Environment(\.openURL) var openURL

    func open(completion: @escaping (Bool) -> Void) {
      openURL(url, completion: completion)
    }
  }
}

public extension View {
  /// Attaches automatic URL opening behaviour to your view.
  ///
  /// This will attach a view modifier to your view that observes the `URL` state on the provided store and
  /// automatically opens it when the `URL` becomes non-nil, before dispatching an action back to the store
  /// to indicate the URL was opened and reset the `URL` back to `nil`.
  ///
  /// - Parameters:
  ///     - store: A store scoped to the `URL` and `OpenURLViewAction` embedded in your feature domain.
  ///
  func opensURL(_ store: Store<URL?, OpenURLViewAction>) -> some View {
    modifier(OpenURLViewModifier(store: store))
  }
}
#endif
