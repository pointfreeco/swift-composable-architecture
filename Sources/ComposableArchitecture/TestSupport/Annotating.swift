//
//  File.swift
//  
//
//  Created by Luke Redpath on 25/06/2020.
//

#if DEBUG

import XCTest

extension TestStore.Annotating {
  public static var activity: Self {
    Self { step, callback in
      var activityName: String!
      
      switch step.type {
      case let .send(action, _):
        activityName = "--> send: \(action)"
      case let .receive(action, _):
        activityName = "<-- receive: \(action)"
      case let .group(name, _):
        activityName = name
      default:
        callback() { _ in }
        return
      }
      
      XCTContext.runActivity(named: activityName) { _ in
        callback() { _ in }
      }
    }
  }
  
  public static var console: Self {
    Self { step, callback in
      switch step.type {
      case let .send(action, _):
        print("\t send: \(action)")
      case let .receive(action, _):
        print("\t receive: \(action)")
      case let .group(name, _):
        print("TestStore assert group: '\(name)' started at \(Date())")
      default:
        return
      }
      
      callback() { stepPassed in
        print("\t\t [\(stepPassed ? "PASS" : "FAIL")]")
      }
    }
  }
}

#endif
