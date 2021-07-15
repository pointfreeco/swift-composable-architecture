import SwiftUI

class PullToRefreshViewModel: ObservableObject {
  @Published var count = 0
  @Published var fact: String? = nil
  
  @Published private var task: Task<String, Error>?
  let fetch: (Int) async throws -> String

  init(fetch: @escaping (Int) async throws -> String) {
    self.fetch = fetch
  }
  
  var isLoading: Bool {
    self.task != nil
  }

  func incrementButtonTapped() {
    self.count += 1
  }

  func decrementButtonTapped() {
    self.count -= 1
  }

  @MainActor
  func getFact() async {
    self.fact = nil
    
    self.task = Task<String, Error> {
      try await self.fetch(self.count)
    }
    defer { self.task = nil }

    do {
      let fact = try await task?.value
      withAnimation {
        self.fact = fact
      }

    } catch {
      // TODO: do some error handling
    }
  }
  
  func cancelButtonTapped() {
    self.task?.cancel()
    self.task = nil
  }
}

struct VanillaPullToRefreshView: View {
  @ObservedObject var viewModel: PullToRefreshViewModel

  var body: some View {
    List {
      HStack {
        Button("-") { self.viewModel.decrementButtonTapped() }
        Text("\(self.viewModel.count)")
        Button("+") { self.viewModel.incrementButtonTapped() }
      }
      .buttonStyle(.plain)

      if let fact = self.viewModel.fact {
        Text(fact)
      }
      if self.viewModel.isLoading {
        Button("Cancel") {
          self.viewModel.cancelButtonTapped()
        }
      }
    }
    .refreshable {
      await self.viewModel.getFact()
    }
  }
}

struct VanillaPullToRefreshView_Previews: PreviewProvider {
  static var previews: some View {
    VanillaPullToRefreshView(
      viewModel: .init(
        fetch: { count in
          await Task.sleep(2 * NSEC_PER_SEC)

          let (data, _) = try await URLSession.shared.data(from: .init(string: "http://numbersapi.com/\(count)/trivia")!)

          return String(decoding: data, as: UTF8.self)
        }
      )
    )
  }
}
