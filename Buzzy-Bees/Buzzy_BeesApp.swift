//
//  Buzzy_BeesApp.swift
//  Buzzy-Bees
//
//  Created by Geo Culurciello on 1/19/26.
//

import SwiftUI

@main
struct Buzzy_BeesApp: App {
    @State private var authManager = AuthManager()
    @State private var eventManager = EventManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(eventManager)
        }
    }
}
