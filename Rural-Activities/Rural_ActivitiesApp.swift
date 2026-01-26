//
//  Rural_ActivitiesApp.swift
//  Rural-Activities
//
//  Created by Geo Culurciello on 1/19/26.
//

import SwiftUI

@main
struct Rural_ActivitiesApp: App {
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
