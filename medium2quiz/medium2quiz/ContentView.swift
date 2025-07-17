//
//  ContentView.swift
//  medium2quiz
//
//  Created by Jingwen Fan on 7/1/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appViewModel = AppViewModel()
    @State private var isInitialized = false
    
    var body: some View {
        ZStack {
            if !isInitialized {
                // Show loading screen during initialization
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            } else if appViewModel.isOnboardingComplete {
                MainTabView(appViewModel: appViewModel)
            } else {
                OnboardingView(appViewModel: appViewModel)
            }
        }
        .onAppear {
            print("🎯 ContentView appeared - isOnboardingComplete: \(appViewModel.isOnboardingComplete)")
            // Delay to allow ViewModel to initialize
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInitialized = true
            }
        }
    }
}

#Preview {
    ContentView()
}
