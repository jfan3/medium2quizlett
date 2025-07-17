import SwiftUI

struct FlashcardStudyView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var session: StudySession
    @State private var currentCard: Flashcard?
    @State private var isFlipped = false
    @State private var dragOffset = CGSize.zero
    @State private var showAnswer = false
    @State private var cardStartTime = Date()
    @State private var showXPAnimation = false
    @State private var earnedXP = 0
    
    init(viewModel: AppViewModel, flashcards: [Flashcard]) {
        self.viewModel = viewModel
        let userId = viewModel.currentUser?.id ?? UUID()
        self._session = State(initialValue: StudySession(
            userId: userId,
            sessionType: .flashcard,
            flashcards: flashcards
        ))
        self._currentCard = State(initialValue: flashcards.first)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                StudyHeaderView(
                    session: session,
                    userProgress: viewModel.userProgress
                )
                
                // Progress Bar
                ProgressView(value: session.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .padding(.horizontal)
                
                // Flashcard
                if let card = currentCard {
                    FlashcardView(
                        card: card,
                        isFlipped: $isFlipped,
                        dragOffset: $dragOffset,
                        onSwipe: handleSwipe
                    )
                    .padding()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                }
                
                // Action Buttons
                HStack(spacing: 40) {
                    Button(action: { handleAnswer(false) }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: { isFlipped.toggle() }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { handleAnswer(true) }) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.green)
                    }
                }
                .padding(.bottom, 40)
            }
            
            // XP Animation Overlay
            if showXPAnimation {
                XPAnimationView(xp: earnedXP)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Study Flashcards")
                    .font(.headline)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: pauseSession) {
                    Image(systemName: "pause.circle")
                }
            }
        }
    }
    
    private func handleSwipe(_ direction: SwipeDirection) {
        if direction == .right {
            handleAnswer(true)
        } else {
            handleAnswer(false)
        }
    }
    
    private func handleAnswer(_ correct: Bool) {
        let timeSpent = Date().timeIntervalSince(cardStartTime)
        session.recordAnswer(correct: correct, timeSpent: timeSpent)
        
        if correct {
            earnedXP = Int(Double(currentCard?.difficulty.xpValue ?? 10) * session.bonusMultiplier)
            showXPAnimation = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showXPAnimation = false
            }
        }
        
        Task {
            await viewModel.updateFlashcardMastery(
                flashcardId: currentCard?.id ?? UUID(),
                correct: correct
            )
        }
        
        moveToNextCard()
    }
    
    private func moveToNextCard() {
        session.currentIndex += 1
        
        if session.currentIndex < session.flashcards.count {
            withAnimation(.easeInOut) {
                currentCard = session.flashcards[session.currentIndex]
                isFlipped = false
                dragOffset = .zero
                cardStartTime = Date()
            }
        } else {
            completeSession()
        }
    }
    
    private func completeSession() {
        session.completedAt = Date()
        session.isCompleted = true
        
        Task {
            await viewModel.saveStudySession(session)
            await viewModel.updateUserProgress(
                xp: session.sessionXP,
                coins: session.sessionCoins
            )
        }
    }
    
    private func pauseSession() {
        // TODO: Implement pause functionality
    }
}

struct FlashcardView: View {
    let card: Flashcard
    @Binding var isFlipped: Bool
    @Binding var dragOffset: CGSize
    let onSwipe: (SwipeDirection) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Front (Question)
                CardFaceView(
                    text: card.question,
                    backgroundColor: difficultyColor,
                    isQuestion: true
                )
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                
                // Back (Answer)
                CardFaceView(
                    text: card.answer,
                    backgroundColor: .blue,
                    isQuestion: false,
                    explanation: card.explanation
                )
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .offset(dragOffset)
            .rotationEffect(.degrees(Double(dragOffset.width / 10)))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if abs(value.translation.width) > 100 {
                            let direction: SwipeDirection = value.translation.width > 0 ? .right : .left
                            withAnimation(.spring()) {
                                dragOffset = CGSize(
                                    width: value.translation.width > 0 ? 500 : -500,
                                    height: 0
                                )
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipe(direction)
                            }
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.spring()) {
                    isFlipped.toggle()
                }
            }
        }
    }
    
    private var difficultyColor: Color {
        switch card.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct CardFaceView: View {
    let text: String
    let backgroundColor: Color
    let isQuestion: Bool
    let explanation: String?
    
    init(text: String, backgroundColor: Color, isQuestion: Bool, explanation: String? = nil) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.isQuestion = isQuestion
        self.explanation = explanation
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isQuestion ? "Question" : "Answer")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            ScrollView {
                Text(text)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
            }
            
            if let explanation = explanation, !isQuestion {
                Divider()
                    .background(Color.white.opacity(0.3))
                
                Text(explanation)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor)
                .shadow(radius: 10)
        )
    }
}

struct StudyHeaderView: View {
    let session: StudySession
    let userProgress: UserProgress?
    
    var body: some View {
        HStack {
            // Streak indicator
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(userProgress?.currentStreak ?? 0)")
                    .font(.headline)
            }
            
            Spacer()
            
            // XP counter
            HStack {
                Text("+\(session.sessionXP)")
                    .font(.headline)
                    .foregroundColor(.purple)
                Text("XP")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            // Coins counter
            HStack {
                Text("+\(session.sessionCoins)")
                    .font(.headline)
                    .foregroundColor(.yellow)
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding(.horizontal)
    }
}

struct XPAnimationView: View {
    let xp: Int
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        Text("+\(xp) XP")
            .font(.system(size: 40, weight: .bold))
            .foregroundColor(.purple)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offset)
            .onAppear {
                withAnimation(.spring()) {
                    scale = 1.5
                    opacity = 1
                }
                
                withAnimation(.easeOut(duration: 1).delay(0.5)) {
                    offset = -100
                    opacity = 0
                }
            }
    }
}

enum SwipeDirection {
    case left, right
}