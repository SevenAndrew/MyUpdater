//
//  MyUpdaterApp.swift
//  MyUpdaterApp
//
//  Created by Andreas Sauerwein on 21.12.24.
//

import SwiftUI

@main
struct MyUpdaterApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
    }
}
