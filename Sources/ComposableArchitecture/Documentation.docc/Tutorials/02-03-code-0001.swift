struct CounterView: View {
  let store: StoreOf<CounterFeature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {
        // ...

        Button(viewStore.isTimerRunning ? "Stop timer" : "Start timer") {
          viewStore.send(.toggleTimerButtonTapped)
        }
        .font(.largeTitle)
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(10)

        // ...
      }
    }
  }
}
