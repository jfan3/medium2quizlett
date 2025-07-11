import SwiftUI

enum OnboardingStep {
    case occupation
    case interests
    case login
}

struct OnboardingView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var currentStep: OnboardingStep = .occupation
    
    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case .occupation:
                    OccupationSelectionView(
                        appViewModel: appViewModel,
                        currentStep: $currentStep
                    )
                case .interests:
                    InterestSelectionView(
                        appViewModel: appViewModel,
                        currentStep: $currentStep
                    )
                case .login:
                    LoginView(appViewModel: appViewModel)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct LoginView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Text(isSignUp ? "Sign Up" : "Log In")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                if appViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                }
                
                if let errorMessage = appViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                // Real Authentication Button
                Button(isSignUp ? "Sign Up" : "Log In") {
                    Task {
                        if isSignUp {
                            await appViewModel.signUp(email: email, password: password)
                        } else {
                            await appViewModel.signIn(email: email, password: password)
                        }
                        
                        if appViewModel.isAuthenticated {
                            await appViewModel.completeOnboarding()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(email.isEmpty || password.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(email.isEmpty || password.isEmpty || appViewModel.isLoading)
                
                Button(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up") {
                    isSignUp.toggle()
                    appViewModel.errorMessage = nil
                }
                .foregroundColor(.blue)
                .disabled(appViewModel.isLoading)
                
                // Dev Login Button
                Button("🔧 Dev Login (Skip Auth)") {
                    // Create a mock dev user
                    Task { @MainActor in
                        appViewModel.user.occupation = .softwareEngineer
                        appViewModel.user.interests = ["Engineering", "Data Science"]
                        appViewModel.isAuthenticated = true
                        appViewModel.completeOnboardingSync()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
                .font(.system(size: 14, weight: .medium))
                .disabled(appViewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}