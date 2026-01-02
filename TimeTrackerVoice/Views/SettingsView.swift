import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var peopleManager: PeopleManager
    
    @State private var showingAPIKeyAlert = false
    @State private var apiKeyInput = ""
    @State private var showingClearCacheAlert = false
    @State private var showingSignOutAlert = false
    @State private var cacheCleared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0f172a")
                    .ignoresSafeArea()
                
                mainContent
            }
            .navigationTitle(L10n.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.done) {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "a78bfa"))
                }
            }
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .environment(\.layoutDirection, l10n.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
        .alert(L10n.enterAPIKey, isPresented: $showingAPIKeyAlert) {
            TextField(L10n.apiKeyPlaceholder, text: $apiKeyInput)
                .textContentType(.password)
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.save) {
                if !apiKeyInput.isEmpty {
                    Config.setOpenAIAPIKey(apiKeyInput)
                    apiKeyInput = ""
                }
            }
        }
        .alert(L10n.clearCache, isPresented: $showingClearCacheAlert) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.clearCache, role: .destructive) {
                clearAllCache()
            }
        } message: {
            Text(L10n.clearCacheDescription)
        }
        .alert(L10n.signOut, isPresented: $showingSignOutAlert) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.signOut, role: .destructive) {
                authManager.signOut()
                dismiss()
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                accountSection
                preferencesSection
                dataSection
                aboutSection
                signOutButton
                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Sections
    
    private var accountSection: some View {
        SettingsSection(title: L10n.account) {
            if let email = authManager.currentUser?.email {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "a78bfa"))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.signedInAs)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "64748b"))
                        Text(email)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(16)
            }
        }
    }
    
    private var preferencesSection: some View {
        SettingsSection(title: L10n.preferences) {
            VStack(spacing: 0) {
                languageRow
                
                Divider()
                    .background(Color(hex: "334155"))
                
                apiKeyRow
            }
        }
    }
    
    private var languageRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "globe")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "a78bfa"))
                .frame(width: 28)
            
            Text(L10n.language)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Spacer()
            
            Picker("", selection: $l10n.currentLanguage) {
                ForEach(L10n.Language.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .tint(Color(hex: "a78bfa"))
        }
        .padding(16)
    }
    
    private var apiKeyRow: some View {
        Button(action: { showingAPIKeyAlert = true }) {
            HStack(spacing: 14) {
                Image(systemName: "key.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "a78bfa"))
                    .frame(width: 28)
                
                Text(L10n.apiKey)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(Config.openAIAPIKey.isEmpty ? L10n.apiKeyNotSet : L10n.apiKeySet)
                    .font(.system(size: 14))
                    .foregroundColor(Config.openAIAPIKey.isEmpty ? Color(hex: "f59e0b") : Color(hex: "22c55e"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748b"))
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dataSection: some View {
        SettingsSection(title: L10n.dataManagement) {
            Button(action: { showingClearCacheAlert = true }) {
                HStack(spacing: 14) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "a78bfa"))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.clearCache)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text(L10n.clearCacheDescription)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "64748b"))
                    }
                    
                    Spacer()
                    
                    if cacheCleared {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "22c55e"))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "64748b"))
                    }
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: L10n.about) {
            HStack(spacing: 14) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "a78bfa"))
                    .frame(width: 28)
                
                Text(L10n.version)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748b"))
            }
            .padding(16)
        }
    }
    
    private var signOutButton: some View {
        Button(action: { showingSignOutAlert = true }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text(L10n.signOut)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func clearAllCache() {
        UserDefaults.standard.removeObject(forKey: "cached_tasks")
        UserDefaults.standard.removeObject(forKey: "cached_categories")
        UserDefaults.standard.removeObject(forKey: "cached_people")
        UserDefaults.standard.removeObject(forKey: "last_sync_date")
        
        Task {
            await taskManager.fetchTasks()
            await taskManager.fetchCategories()
            await peopleManager.fetchPeople()
        }
        
        withAnimation {
            cacheCleared = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                cacheCleared = false
            }
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "64748b"))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color(hex: "1e293b"))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
        .environmentObject(TaskManager.shared)
        .environmentObject(PeopleManager.shared)
}
