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
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(isSignUp ? "Sign Up" : "Log In") {
                    appViewModel.completeOnboarding()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(email.isEmpty || password.isEmpty)
                
                Button(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up") {
                    isSignUp.toggle()
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}