//
//  TheApplicationApp.swift
//  TheApplication
//
//  Created by Akash soni on 25/01/23.
//

import SwiftUI

@main
struct TheApplicationApp: App {
  let persistenceController = PersistenceController.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
  }
}
