import SwiftUI

/// Authentication view with email/password login
struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var magicLinkSent = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f0f23")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Logo
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "8b5cf6").opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Text("🎙️")
                                .font(.system(size: 50))
                        }
                        
                        Text("TimeTracker")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Voice Coach")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "a78bfa"))
                    }
                    .padding(.top, 60)
                    
                    // Magic link sent message
                    if magicLinkSent {
                        VStack(spacing: 8) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: "10b981"))
                            
                            Text("Check your email!")
                                .font(.headline)
                                .foregroundColor(Color(hex: "10b981"))
                            
                            Text("We sent a login link to \(email)")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "6ee7b7"))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(hex: "10b981").opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal, 30)
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "94a3b8"))
                            
                            TextField("you@example.com", text: $email)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "94a3b8"))
                            
                            SecureField("••••••••", text: $password)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Magic Link button
                        Button(action: sendMagicLink) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Sign in with Email Link")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "10b981"))
                            .cornerRadius(12)
                        }
                        .disabled(authManager.isLoading)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                            Text("or with password")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "64748b"))
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                        }
                        
                        // Sign In button
                        Button(action: signIn) {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In with Password")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "7c3aed"))
                        .cornerRadius(12)
                        .disabled(authManager.isLoading)
                        
                        // Toggle sign up
                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "94a3b8"))
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer(minLength: 40)
                    
                    // Footer
                    Text("Manage your tasks with voice commands")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "475569"))
                        .padding(.bottom, 40)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            showError = true
            return
        }
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func sendMagicLink() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            showError = true
            return
        }
        
        Task {
            do {
                try await authManager.signInWithMagicLink(email: email)
                magicLinkSent = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}

