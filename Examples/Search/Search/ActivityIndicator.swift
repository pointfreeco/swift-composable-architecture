import SwiftUI

// SwiftUI doesn't have a view for activity indicators, so we make UIActivityIndicatorView
// accessible from SwiftUI.

public struct ActivityIndicator: UIViewRepresentable {
  public init() {}

  public func makeUIView(context: Context) -> UIActivityIndicatorView {
    let view = UIActivityIndicatorView()
    view.startAnimating()
    return view
  }

  public func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}
