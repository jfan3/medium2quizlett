import SwiftUI

struct SettingsView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var showingDeleteAlert = false
    @State private var showingChangePassword = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("John Doe")
                                .font(.headline)
                            
                            if let occupation = appViewModel.user.occupation {
                                Text(occupation.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Account section
                Section("Account") {
                    SettingsRow(
                        icon: "key.fill",
                        title: "Change Password",
                        color: .blue
                    ) {
                        showingChangePassword = true
                    }
                    
                    SettingsRow(
                        icon: "person.2.fill",
                        title: "Manage Interests",
                        color: .green
                    ) {
                        // Handle manage interests
                    }
                    
                    SettingsRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        color: .orange
                    ) {
                        // Handle notifications
                    }
                }
                
                // Study preferences
                Section("Study Preferences") {
                    SettingsRow(
                        icon: "clock.fill",
                        title: "Study Reminders",
                        color: .purple
                    ) {
                        // Handle study reminders
                    }
                    
                    SettingsRow(
                        icon: "chart.bar.fill",
                        title: "Progress Tracking",
                        color: .blue
                    ) {
                        // Handle progress tracking
                    }
                }
                
                // Data section
                Section("Data") {
                    SettingsRow(
                        icon: "icloud.fill",
                        title: "Sync Data",
                        color: .blue
                    ) {
                        // Handle data sync
                    }
                    
                    SettingsRow(
                        icon: "square.and.arrow.down.fill",
                        title: "Export Data",
                        color: .green
                    ) {
                        // Handle data export
                    }
                }
                
                // Danger zone
                Section("Danger Zone") {
                    SettingsRow(
                        icon: "trash.fill",
                        title: "Delete Account",
                        color: .red
                    ) {
                        showingDeleteAlert = true
                    }
                }
                
                // App info
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    SettingsRow(
                        icon: "questionmark.circle.fill",
                        title: "Help & Support",
                        color: .blue
                    ) {
                        // Handle help
                    }
                    
                    SettingsRow(
                        icon: "doc.text.fill",
                        title: "Privacy Policy",
                        color: .gray
                    ) {
                        // Handle privacy policy
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Handle account deletion
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(color)
                    .cornerRadius(6)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    SecureField("Current Password", text: $currentPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("New Password", text: $newPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                Button("Change Password") {
                    // Handle password change
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(newPassword == confirmPassword && !newPassword.isEmpty ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(newPassword != confirmPassword || newPassword.isEmpty)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}