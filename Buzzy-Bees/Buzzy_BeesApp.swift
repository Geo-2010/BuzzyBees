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
    @State private var locationManager = LocationManager()
    private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(eventManager)
                .environment(locationManager)
                .onAppear {
                    eventManager.locationManager = locationManager
                    locationManager.requestPermission()
                    // Strategic prompt #1: app launch
                    notificationManager.promptIfNeeded()
                }
                .alert("Enable Notifications?",
                       isPresented: Binding(
                        get: { notificationManager.showPermissionPrompt },
                        set: { notificationManager.showPermissionPrompt = $0 }
                       )) {
                    Button("Enable") {
                        notificationManager.userAcceptedPrompt()
                    }
                    Button("Not Now", role: .cancel) {
                        notificationManager.userDeclinedPrompt()
                    }
                } message: {
                    Text("Get reminders before events you RSVP to so you never miss out!")
                }
        }
    }
}
