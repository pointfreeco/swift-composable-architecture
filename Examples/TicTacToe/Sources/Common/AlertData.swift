public struct AlertData: Equatable, Identifiable {
  public let title: String

  public init(title: String) {
    self.title = title
  }

  public var id: String { self.title }
}
