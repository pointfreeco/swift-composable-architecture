struct CounterPreview: PreviewProvider {
  static var previews: some View {
    CounterView(
      store: Store(initialState: CounterFeature.State()) {
        // CounterFeature()
      }
    )
  }
}
