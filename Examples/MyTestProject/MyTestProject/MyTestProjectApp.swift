//
//  MyTestProjectApp.swift
//  MyTestProject
//
//  Created by Akash soni on 26/01/23.
//

import SwiftUI

@main
struct MyTestProjectApp: App {
  let persistenceController = PersistenceController.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
  }
}
