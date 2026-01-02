import Foundation
import Combine

@MainActor
class PeopleManager: ObservableObject {
    static let shared = PeopleManager()
    
    @Published var people: [Person] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncDate: Date?
    
    // Cache key
    private let peopleKey = "cached_people"
    private let lastSyncKey = "people_last_sync"
    
    private init() {
        // Load cached data immediately
        loadCachedData()
    }
    
    // MARK: - Local Cache Management
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: peopleKey) {
            do {
                let cachedPeople = try JSONDecoder().decode([Person].self, from: data)
                self.people = cachedPeople
                print("📦 Loaded \(cachedPeople.count) cached contacts")
            } catch {
                print("⚠️ Failed to decode cached contacts: \(error)")
            }
        }
        
        if let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = lastSync
        }
    }
    
    private func savePeopleToCache() {
        do {
            let data = try JSONEncoder().encode(people)
            UserDefaults.standard.set(data, forKey: peopleKey)
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            self.lastSyncDate = Date()
            print("💾 Saved \(people.count) contacts to cache")
        } catch {
            print("⚠️ Failed to save contacts to cache: \(error)")
        }
    }
    
    // MARK: - Fetch People
    
    func fetchPeople() async {
        guard let token = AuthManager.shared.getAccessToken() else {
            print("⚠️ No access token - using cached contacts only")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/people?order=first_name.asc")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            people = try JSONDecoder().decode([Person].self, from: data)
            
            // ✅ Save to cache
            savePeopleToCache()
            
            print("✅ Fetched \(people.count) contacts from server")
        } catch {
            self.error = error.localizedDescription
            print("❌ Error fetching contacts: \(error)")
            print("📦 Using \(people.count) cached contacts instead")
        }
    }
    
    // MARK: - Create Person
    
    func createPerson(_ input: CreatePersonInput) async throws -> Person {
        guard let token = AuthManager.shared.getAccessToken() else {
            throw PeopleError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/people")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try JSONEncoder().encode(input)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw PeopleError.createFailed
        }
        
        let fetchedPeople = try JSONDecoder().decode([Person].self, from: data)
        guard let newPerson = fetchedPeople.first else {
            throw PeopleError.createFailed
        }
        
        self.people.append(newPerson)
        self.people.sort { $0.firstName < $1.firstName }
        
        // ✅ Save to cache
        savePeopleToCache()
        
        print("✅ Created contact: \(newPerson.fullName)")
        return newPerson
    }
    
    // MARK: - Update Person
    
    func updatePerson(id: String, input: UpdatePersonInput) async throws -> Person {
        guard let token = AuthManager.shared.getAccessToken() else {
            throw PeopleError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/people?id=eq.\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try JSONEncoder().encode(input)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PeopleError.updateFailed
        }
        
        let fetchedPeople = try JSONDecoder().decode([Person].self, from: data)
        guard let updatedPerson = fetchedPeople.first else {
            throw PeopleError.updateFailed
        }
        
        if let index = self.people.firstIndex(where: { $0.id == id }) {
            self.people[index] = updatedPerson
        }
        
        // ✅ Save to cache
        savePeopleToCache()
        
        print("✅ Updated contact: \(updatedPerson.fullName)")
        return updatedPerson
    }
    
    // MARK: - Delete Person
    
    func deletePerson(id: String) async throws {
        guard let token = AuthManager.shared.getAccessToken() else {
            throw PeopleError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/people?id=eq.\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw PeopleError.deleteFailed
        }
        
        people.removeAll { $0.id == id }
        
        // ✅ Save to cache
        savePeopleToCache()
        
        print("✅ Deleted contact")
    }
    
    // MARK: - Helpers
    
    func getPeopleByType(_ type: RelationshipType) -> [Person] {
        return people.filter { $0.relationshipType == type }
    }
    
    func getUpcomingBirthdays(days: Int = 30) -> [Person] {
        return people
            .filter { $0.daysUntilBirthday != nil && $0.daysUntilBirthday! <= days }
            .sorted { ($0.daysUntilBirthday ?? 999) < ($1.daysUntilBirthday ?? 999) }
    }
    
    func findPerson(byName name: String) -> Person? {
        let lowercaseName = name.lowercased()
        return people.first { person in
            person.fullName.lowercased().contains(lowercaseName) ||
            (person.nickname?.lowercased().contains(lowercaseName) ?? false)
        }
    }
    
    func searchPeople(_ query: String) -> [Person] {
        let lowercaseQuery = query.lowercased()
        return people.filter { person in
            person.fullName.lowercased().contains(lowercaseQuery) ||
            (person.nickname?.lowercased().contains(lowercaseQuery) ?? false) ||
            (person.relationshipDetail?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    // Statistics
    var stats: (total: Int, family: Int, friends: Int, colleagues: Int, other: Int) {
        (
            total: people.count,
            family: people.filter { $0.relationshipType == .family }.count,
            friends: people.filter { $0.relationshipType == .friend }.count,
            colleagues: people.filter { $0.relationshipType == .colleague }.count,
            other: people.filter { $0.relationshipType == .other }.count
        )
    }
}

// MARK: - Errors

enum PeopleError: LocalizedError {
    case notAuthenticated
    case createFailed
    case updateFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .createFailed:
            return "Failed to create contact"
        case .updateFailed:
            return "Failed to update contact"
        case .deleteFailed:
            return "Failed to delete contact"
        }
    }
}

