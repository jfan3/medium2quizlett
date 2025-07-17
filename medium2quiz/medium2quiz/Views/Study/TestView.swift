import SwiftUI

struct TestView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var session: StudySession
    @State private var currentQuestion: TestQuestion?
    @State private var selectedAnswer: String = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var timeRemaining: Int = 30
    @State private var timer: Timer?
    @State private var questionStartTime = Date()
    
    init(viewModel: AppViewModel, testQuestions: [TestQuestion]) {
        self.viewModel = viewModel
        let userId = viewModel.currentUser?.id ?? UUID()
        self._session = State(initialValue: StudySession(
            userId: userId,
            sessionType: .test,
            testQuestions: testQuestions
        ))
        self._currentQuestion = State(initialValue: testQuestions.first)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.indigo.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header with timer
                TestHeaderView(
                    session: session,
                    timeRemaining: timeRemaining,
                    userProgress: viewModel.userProgress
                )
                
                // Progress
                ProgressView(value: session.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .indigo))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .padding(.horizontal)
                
                // Question
                if let question = currentQuestion {
                    QuestionView(
                        question: question,
                        selectedAnswer: $selectedAnswer,
                        showResult: showResult,
                        isCorrect: isCorrect
                    )
                    .padding()
                }
                
                Spacer()
                
                // Submit Button
                if !showResult {
                    Button(action: submitAnswer) {
                        Text("Submit Answer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(selectedAnswer.isEmpty ? Color.gray : Color.indigo)
                            )
                    }
                    .disabled(selectedAnswer.isEmpty)
                    .padding(.horizontal)
                } else {
                    Button(action: nextQuestion) {
                        Text("Next Question")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.indigo)
                            )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timeRemaining = 30
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                submitAnswer()
            }
        }
    }
    
    private func submitAnswer() {
        guard let question = currentQuestion else { return }
        
        timer?.invalidate()
        isCorrect = question.checkAnswer(selectedAnswer)
        showResult = true
        
        let timeSpent = Date().timeIntervalSince(questionStartTime)
        session.recordAnswer(correct: isCorrect, timeSpent: timeSpent)
    }
    
    private func nextQuestion() {
        session.currentIndex += 1
        
        if session.currentIndex < session.testQuestions.count {
            currentQuestion = session.testQuestions[session.currentIndex]
            selectedAnswer = ""
            showResult = false
            questionStartTime = Date()
            startTimer()
        } else {
            completeTest()
        }
    }
    
    private func completeTest() {
        session.completedAt = Date()
        session.isCompleted = true
        
        Task {
            await viewModel.saveStudySession(session)
            await viewModel.updateUserProgress(
                xp: session.sessionXP,
                coins: session.sessionCoins
            )
            
            // Navigate to results
        }
    }
}

struct QuestionView: View {
    let question: TestQuestion
    @Binding var selectedAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Question Type Badge
            HStack {
                Image(systemName: question.questionType.icon)
                Text(question.questionType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.indigo.opacity(0.2))
            )
            
            // Question Content
            switch question.questionData {
            case .multipleChoice(let data):
                MultipleChoiceQuestionView(
                    data: data,
                    selectedAnswer: $selectedAnswer,
                    showResult: showResult,
                    isCorrect: isCorrect
                )
                
            case .trueFalse(let data):
                TrueFalseQuestionView(
                    data: data,
                    selectedAnswer: $selectedAnswer,
                    showResult: showResult,
                    isCorrect: isCorrect
                )
                
            case .fillBlank(let data):
                FillBlankQuestionView(
                    data: data,
                    selectedAnswer: $selectedAnswer,
                    showResult: showResult,
                    isCorrect: isCorrect
                )
                
            case .shortAnswer(let data):
                ShortAnswerQuestionView(
                    data: data,
                    selectedAnswer: $selectedAnswer,
                    showResult: showResult,
                    isCorrect: isCorrect
                )
                
            case .matching(let data):
                MatchingQuestionView(
                    data: data,
                    selectedAnswer: $selectedAnswer,
                    showResult: showResult,
                    isCorrect: isCorrect
                )
            }
        }
    }
}

struct MultipleChoiceQuestionView: View {
    let data: TestQuestion.MultipleChoiceData
    @Binding var selectedAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(data.question)
                .font(.title3)
                .fontWeight(.medium)
            
            VStack(spacing: 12) {
                ForEach(Array(data.options.enumerated()), id: \.offset) { index, option in
                    OptionButton(
                        text: option,
                        isSelected: selectedAnswer == String(index),
                        isCorrect: showResult && index == data.correctIndex,
                        isWrong: showResult && selectedAnswer == String(index) && index != data.correctIndex,
                        action: {
                            if !showResult {
                                selectedAnswer = String(index)
                            }
                        }
                    )
                }
            }
            
            if showResult, let explanation = data.explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
        }
    }
}

struct TrueFalseQuestionView: View {
    let data: TestQuestion.TrueFalseData
    @Binding var selectedAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(data.statement)
                .font(.title3)
                .fontWeight(.medium)
            
            HStack(spacing: 20) {
                TrueFalseButton(
                    text: "True",
                    color: .green,
                    isSelected: selectedAnswer == "true",
                    isCorrect: showResult && data.isTrue,
                    isWrong: showResult && selectedAnswer == "true" && !data.isTrue,
                    action: {
                        if !showResult {
                            selectedAnswer = "true"
                        }
                    }
                )
                
                TrueFalseButton(
                    text: "False",
                    color: .red,
                    isSelected: selectedAnswer == "false",
                    isCorrect: showResult && !data.isTrue,
                    isWrong: showResult && selectedAnswer == "false" && data.isTrue,
                    action: {
                        if !showResult {
                            selectedAnswer = "false"
                        }
                    }
                )
            }
            
            if showResult, let explanation = data.explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
        }
    }
}

struct FillBlankQuestionView: View {
    let data: TestQuestion.FillBlankData
    @Binding var selectedAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    
    @State private var answers: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Fill in the blanks:")
                .font(.headline)
            
            Text(data.sentence)
                .font(.title3)
                .fontWeight(.medium)
            
            VStack(spacing: 12) {
                ForEach(Array(data.blanks.enumerated()), id: \.offset) { index, blank in
                    HStack {
                        Text("Blank \(index + 1):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Answer", text: binding(for: index))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(showResult)
                    }
                }
            }
            
            if showResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Correct answers:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(Array(data.correctAnswers.enumerated()), id: \.offset) { index, answer in
                        Text("\(index + 1). \(answer)")
                            .font(.footnote)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
            }
        }
        .onAppear {
            if answers.isEmpty {
                answers = Array(repeating: "", count: data.blanks.count)
            }
        }
        .onChange(of: answers) {
            selectedAnswer = answers.joined(separator: "|")
        }
    }
    
    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < answers.count ? answers[index] : "" },
            set: { newValue in
                if index < answers.count {
                    answers[index] = newValue
                }
            }
        )
    }
}

struct ShortAnswerQuestionView: View {
    let data: TestQuestion.ShortAnswerData
    @Binding var selectedAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(data.question)
                .font(.title3)
                .fontWeight(.medium)
            
            TextField("Your answer", text: $selectedAnswer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(showResult)
            
            if showResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Acceptable answers:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(data.acceptableAnswers, id: \.self) { answer in
                        Text("• \(answer)")
                            .font(.footnote)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
            }
        }
    }
}

struct MatchingQuestionView: View {
    let data: TestQuestion.MatchingData
    @Binding var selectedAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(data.instruction)
                .font(.title3)
                .fontWeight(.medium)
            
            // TODO: Implement matching UI
            Text("Matching question UI to be implemented")
                .foregroundColor(.secondary)
        }
    }
}

struct OptionButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if isWrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 2)
                    )
            )
        }
    }
    
    private var backgroundColor: Color {
        if isCorrect {
            return Color.green.opacity(0.2)
        } else if isWrong {
            return Color.red.opacity(0.2)
        } else if isSelected {
            return Color.indigo.opacity(0.1)
        }
        return Color.gray.opacity(0.05)
    }
    
    private var borderColor: Color {
        if isCorrect {
            return .green
        } else if isWrong {
            return .red
        } else if isSelected {
            return .indigo
        }
        return Color.gray.opacity(0.3)
    }
    
    private var textColor: Color {
        if isCorrect || isWrong {
            return .primary
        }
        return isSelected ? .primary : .secondary
    }
}

struct TrueFalseButton: View {
    let text: String
    let color: Color
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : (isWrong ? "xmark.circle.fill" : "circle"))
                    .font(.largeTitle)
                    .foregroundColor(iconColor)
                
                Text(text)
                    .font(.headline)
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(borderColor, lineWidth: 2)
                    )
            )
        }
    }
    
    private var backgroundColor: Color {
        if isCorrect {
            return color.opacity(0.2)
        } else if isWrong {
            return Color.gray.opacity(0.2)
        } else if isSelected {
            return color.opacity(0.1)
        }
        return Color.gray.opacity(0.05)
    }
    
    private var borderColor: Color {
        if isCorrect || isSelected {
            return color
        } else if isWrong {
            return .gray
        }
        return Color.gray.opacity(0.3)
    }
    
    private var iconColor: Color {
        if isCorrect {
            return color
        } else if isWrong {
            return .gray
        }
        return isSelected ? color : Color.gray.opacity(0.5)
    }
    
    private var textColor: Color {
        if isCorrect || isWrong || isSelected {
            return .primary
        }
        return .secondary
    }
}

struct TestHeaderView: View {
    let session: StudySession
    let timeRemaining: Int
    let userProgress: UserProgress?
    
    var body: some View {
        HStack {
            // Question counter
            Text("Q\(session.currentIndex + 1)/\(session.testQuestions.count)")
                .font(.headline)
            
            Spacer()
            
            // Timer
            HStack {
                Image(systemName: "clock")
                Text("\(timeRemaining)s")
                    .font(.headline)
                    .foregroundColor(timeRemaining < 10 ? .red : .primary)
            }
            
            Spacer()
            
            // Score
            HStack {
                Text("\(session.correctAnswers)/\(session.cardsStudied)")
                    .font(.headline)
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }
}