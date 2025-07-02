//
//  ContentView.swift
//  medium2quiz
//
//  Created by Jingwen Fan on 7/1/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some View {
        Group {
            if appViewModel.isOnboardingComplete {
                MainTabView(appViewModel: appViewModel)
            } else {
                OnboardingView(appViewModel: appViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
