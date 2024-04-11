import SwiftUI

@main
struct TicTacToeApp: App {

  var body: some Scene {
    WindowGroup {
      RootView()
    }
  }
}


import ComposableArchitecture

struct State1 {
  @Shared<Int, None<Never>> var count: Int
  @Shared var count: Int
  //@Shared(ServerConfigKey()) var config = ServerConfig()

  func foo() {
    //    $config.persistence.reload()
    //    let tmp = $config.identifier
  }
}


