public enum TestCase: String, CaseIterable, Identifiable, RawRepresentable {
  case escapedWithViewStore = "Escaped WithViewStore"
  case forEachBinding = "ForEach Binding"
  case navigationStackBinding = "NavigationStack Binding"
  case presentation

  public var id: Self { self }
}
