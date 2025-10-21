import SwiftUI
import UIKit

struct SurveyQuestionView: View {
    @ObservedObject var manager: SurveyManager
    let question: SurveyQuestion
    let onBackToWelcome: () -> Void
    let onComplete: () -> Void

    @State private var searchText: String = ""
    @State private var nameInput: String = ""
    @State private var showCustomInputPopup = false
    @State private var customInput: String = ""

    // Only question steps for progress bar and navigation
    var questionSteps: [SurveyQuestion] {
        manager.steps.compactMap { step in
            if case .question(let q) = step { return q }
            return nil
        }
    }

    // Filter options for search
    var filteredOptions: [String] {
        if manager.currentIndex == 0 { return [] }
        // Start with the question's options
        var all = question.options
        // Include any already-selected answers (e.g., custom entries) so they appear as options
        if let selected = manager.answers[manager.currentIndex] {
            for item in selected where !all.contains(item) {
                all.append(item)
            }
        }
        // Apply search only when enabled and for multi-select
        if searchText.isEmpty || !question.isMultiSelect || !question.showsSearchBar {
            return all
        } else {
            return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 10)
                GeometryReader { geo in
                    let progress = CGFloat(manager.steps.isEmpty ? 0 : (manager.currentIndex + 1)) / CGFloat(max(manager.steps.count, 1))
                    Capsule()
                        .fill(Color("PrimaryGreen"))
                        .frame(width: geo.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)
            .padding(.top, 20)
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Question Text
                    Text(question.question)
                        .font(.title2.bold())
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // Name Input (Q1)
                    if manager.currentIndex == 0 {
                        TextField("Type your name...", text: $nameInput)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(24)
                            .accentColor(Color("PrimaryGreen"))
                            .padding(.horizontal, 24)
                            .onChange(of: nameInput) { newValue in
                                manager.answers[manager.currentIndex] = [newValue]
                                manager.saveDraft()
                            }
                    }

                    // Search Bar (multi-select)
                    if question.isMultiSelect && question.showsSearchBar {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search...", text: $searchText)
                                .accentColor(Color("PrimaryGreen"))
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(24)
                        .padding(.horizontal, 24)
                    }

                    if manager.currentIndex != 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(filteredOptions, id: \.self) { option in
                                let selected = manager.answers[manager.currentIndex] ?? []

                                Button(action: {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    if question.isMultiSelect {
                                        var updated = selected
                                        if updated.contains(option) {
                                            updated.removeAll { $0 == option }
                                        } else {
                                            updated.append(option)
                                        }
                                        manager.answers[manager.currentIndex] = updated
                                        manager.saveDraft()
                                    } else {
                                        manager.answers[manager.currentIndex] = [option]
                                        manager.saveDraft()
                                    }
                                }) {
                                    Text(option)
                                        .frame(maxWidth: .infinity, alignment: question.optionAlignmentLeading ? .leading : .center)
                                        .padding()
                                        .background(
                                            selected.contains(option)
                                                ? Color("PrimaryGreen")
                                                : Color(.systemGray6)
                                        )
                                        .foregroundColor(
                                            selected.contains(option) ? .white : .primary
                                        )
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal, 24)
                            }
                            if question.allowsCustomInput {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showCustomInputPopup = true
                                }) {
                                    Text("➕ Add your own")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .foregroundColor(.primary)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    Spacer(minLength: 80)
                }
            }

            // Bottom Buttons
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                HStack(spacing: 16) {
                    // Back Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        searchText = ""
                        if manager.currentIndex == 0 {
                            onBackToWelcome()
                        } else {
                            manager.currentIndex -= 1
                        }
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color("PrimaryGreen"))
                            .clipShape(Circle())
                    }

                    Spacer(minLength: 0)

                    // Continue Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        searchText = ""
                        manager.nextStep()
                    }) {
                        Text("Continue")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(height: 52)
                            .frame(maxWidth: .infinity)
                            .background(Color("PrimaryGreen"))
                            .cornerRadius(32)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .background(Color(.systemBackground))
            }
            .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showCustomInputPopup) {
            VStack(spacing: 16) {
                Text("Add your own option")
                    .font(.headline)
                    .padding(.top, 20)

                TextField("Your option", text: $customInput)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                HStack {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        customInput = ""
                        showCustomInputPopup = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.red)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)

                    Button("Add") {
                        let trimmed = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()

                        // Store the custom input in the answers without mutating the question model
                        var currentAnswers = manager.answers[manager.currentIndex] ?? []
                        if question.isMultiSelect {
                            if !currentAnswers.contains(trimmed) {
                                currentAnswers.append(trimmed)
                            }
                        } else {
                            currentAnswers = [trimmed]
                        }
                        manager.answers[manager.currentIndex] = currentAnswers
                        manager.saveDraft()

                        customInput = ""
                        showCustomInputPopup = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryGreen"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}
