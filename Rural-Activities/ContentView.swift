//
//  ContentView.swift
//  Rural-Activities
//
//  Created by Geo Culurciello on 1/19/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
        .environment(EventManager())
}
