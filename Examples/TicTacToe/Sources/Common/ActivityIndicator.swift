import SwiftUI

public struct ActivityIndicator: UIViewRepresentable {
  public init() {}

  public func makeUIView(context: Context) -> UIActivityIndicatorView {
    let view = UIActivityIndicatorView()
    view.startAnimating()
    return view
  }

  public func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}
