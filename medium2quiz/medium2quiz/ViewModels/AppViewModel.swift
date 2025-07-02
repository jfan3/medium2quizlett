import Foundation
import Combine

class AppViewModel: ObservableObject {
    @Published var user = User()
    @Published var articles: [Article] = []
    @Published var selectedTopics: [Topic] = []
    @Published var isOnboardingComplete = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadUserData()
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        $user
            .map { $0.isOnboardingComplete }
            .assign(to: \.isOnboardingComplete, on: self)
            .store(in: &cancellables)
    }
    
    func completeOnboarding() {
        user.isOnboardingComplete = true
        saveUserData()
    }
    
    func updateOccupation(_ occupation: Occupation) {
        user.occupation = occupation
        saveUserData()
    }
    
    func updateInterests(_ interests: [String]) {
        user.interests = interests
        saveUserData()
    }
    
    func addArticle(_ article: Article) {
        articles.append(article)
        saveArticles()
    }
    
    func updateArticleStatus(_ articleId: UUID, status: ArticleStatus) {
        if let index = articles.firstIndex(where: { $0.id == articleId }) {
            articles[index].status = status
            saveArticles()
        }
    }
    
    func getArticles(by status: ArticleStatus) -> [Article] {
        articles.filter { $0.status == status }
    }
    
    func getStarredCards() -> [QuizCard] {
        articles.flatMap { $0.quizCards }.filter { $0.isStarred }
    }
    
    func getWeakCards() -> [QuizCard] {
        articles.flatMap { $0.quizCards }.filter { $0.isWeak }
    }
    
    func getAcedCards() -> [QuizCard] {
        articles.flatMap { $0.quizCards }.filter { $0.isAced }
    }
    
    private func loadUserData() {
        if let data = UserDefaults.standard.data(forKey: "user"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.user = user
        }
    }
    
    private func saveUserData() {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "user")
        }
    }
    
    private func saveArticles() {
        if let data = try? JSONEncoder().encode(articles) {
            UserDefaults.standard.set(data, forKey: "articles")
        }
    }
}