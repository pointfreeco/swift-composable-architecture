//
//  WorkoutPreviewApp.swift
//  WorkoutPreview
//
//  Created by Akash soni on 26/01/23.
//

import AppFeature
import SwiftUI

@main
struct WorkoutPreviewApp: App {
  let persistenceController = PersistenceController.shared

  var body: some Scene {
    WindowGroup {
      FirstScreen()

    }
  }
}
