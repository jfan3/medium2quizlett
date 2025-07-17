import Foundation

class EnvironmentConfig {
    private static var config: [String: String] = {
        // Try multiple possible file names and locations
        let possibleFiles = [".env", "env_config", "env_config.txt"]
        
        for fileName in possibleFiles {
            if let path = Bundle.main.path(forResource: fileName, ofType: nil),
               let data = try? String(contentsOfFile: path, encoding: .utf8) {
                print("✅ Found config file: \(fileName)")
                var config: [String: String] = [:]
                let lines = data.components(separatedBy: .newlines)
                
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                        let parts = trimmed.components(separatedBy: "=")
                        if parts.count == 2 {
                            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            config[key] = value
                        }
                    }
                }
                return config
            }
        }
        
        print("❌ No config file found. Tried: \(possibleFiles)")
        // Fallback to hardcoded values for now (NEVER include API keys here)
        return [
            "SUPABASE_URL": "https://fjswkvgochsdmcqeaexc.supabase.co",
            "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqc3drdmdvY2hzZG1jcWVhZXhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0OTI5NjMsImV4cCI6MjA2NzA2ODk2M30.OsvnIZE9TX6qzqzeAjdaa9988Bg2aUhBw23761K3n8U",
            "CLAUDE_API_KEY": "" // Remove API key - should be in env_config.txt only
        ]
    }()
    
    static var supabaseURL: String {
        return config["SUPABASE_URL"] ?? ""
    }
    
    static var supabaseAnonKey: String {
        return config["SUPABASE_ANON_KEY"] ?? ""
    }
    
    
    static var claudeAPIKey: String {
        return config["CLAUDE_API_KEY"] ?? ""
    }
    
    static var devUserEmail: String {
        return config["DEV_USER_EMAIL"] ?? "dev@test.com"
    }
    
    static var devUserPassword: String {
        return config["DEV_USER_PASSWORD"] ?? "devpassword"
    }
    
    static var isDevelopment: Bool {
        return config["IS_DEVELOPMENT"]?.lowercased() == "true"
    }
}