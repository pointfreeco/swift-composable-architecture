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
    Self { step, _, callback in
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
    Self { step, groupLevel, callback in
      func console(_ string: String) {
        let indent = String(repeating: "\t", count: groupLevel)
        print("\(indent)\(string)")
      }
      
      switch step.type {
      case let .send(action, _):
        console("send: \(action)")
      case let .receive(action, _):
        console("receive: \(action)")
      case let .group(name, _):
        console("TestStore assert group: '\(name)' started at \(Date())")
      default:
        return
      }
      
      callback() { stepPassed in
        console("\t [\(stepPassed ? "PASS" : "FAIL")]")
      }
    }
  }
}

#endif
