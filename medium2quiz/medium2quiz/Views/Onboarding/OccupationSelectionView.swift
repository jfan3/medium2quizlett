import SwiftUI

struct OccupationSelectionView: View {
    @ObservedObject var appViewModel: AppViewModel
    @Binding var currentStep: OnboardingStep
    @State private var selectedOccupation: Occupation?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 32) {
                Text("Who are you?")
                    .font(.title)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Occupation.allCases, id: \.rawValue) { occupation in
                        OccupationButton(
                            occupation: occupation,
                            isSelected: selectedOccupation == occupation
                        ) {
                            selectedOccupation = occupation
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            Button("Next") {
                if let occupation = selectedOccupation {
                    appViewModel.updateOccupation(occupation)
                    currentStep = .interests
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(selectedOccupation != nil ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(selectedOccupation == nil)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }
}

struct OccupationButton: View {
    let occupation: Occupation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: occupation.icon)
                    .font(.title2)
                Text(occupation.rawValue)
                    .font(.body)
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}