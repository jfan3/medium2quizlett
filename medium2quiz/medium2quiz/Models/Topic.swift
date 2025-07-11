import Foundation

struct Topic: Codable, Identifiable {
    let id: UUID
    let name: String
    let isSelected: Bool
    
    init(name: String, isSelected: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isSelected = isSelected
    }
    
    init(id: UUID, name: String, isSelected: Bool = false) {
        self.id = id
        self.name = name
        self.isSelected = isSelected
    }
    
    static let defaultTopics = [
        Topic(name: "Causal Inference"),
        Topic(name: "ETL Pipelines"),
        Topic(name: "Data Visualization"),
        Topic(name: "Machine Learning"),
        Topic(name: "Cloud Computing"),
        Topic(name: "Cybersecurity"),
        Topic(name: "Blockchain"),
        Topic(name: "Quantum Computing"),
        Topic(name: "Augmented Reality"),
        Topic(name: "Bioinformatics")
    ]
}