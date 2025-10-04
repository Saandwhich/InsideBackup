import SwiftUI

struct SurveyQuestionView: View {
    @ObservedObject var manager: SurveyManager
    let question: SurveyQuestion
    let onBackToWelcome: () -> Void
    let onComplete: () -> Void

    @State private var searchText: String = ""
    @State private var showCustomInputPopup = false
    @State private var customInput: String = ""
    @State private var nameInput: String = ""


    var filteredOptions: [String] {
        let all = question.options
        if searchText.isEmpty || !question.isMultiSelect || manager.currentIndex == 2 {
            return all
        } else {
            return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ProgressView(value: Double(manager.currentIndex + 1), total: Double(manager.questions.count))
                .accentColor(Color("PrimaryGreen"))
                .frame(height: 10)
                .background(Color(.systemGray5))
                .cornerRadius(5)
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
                            .onChange(of: nameInput) { oldValue, newValue in
                                manager.answers[manager.currentIndex] = [newValue]
                            }
                    }

                    // Search Bar (only multi-select)
                    if question.isMultiSelect && manager.currentIndex != 2 {
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

                    // Options
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(filteredOptions, id: \.self) { option in
                            let selected = manager.answers[manager.currentIndex] ?? []

                            if question.isMultiSelect {
                                // Multi-select style
                                Button(action: {
                                    var updated = selected
                                    if updated.contains(option) {
                                        updated.removeAll { $0 == option }
                                    } else {
                                        updated.append(option)
                                    }
                                    manager.answers[manager.currentIndex] = updated
                                }) {
                                    Text(option)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
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
                            } else {
                                // Single-select (styled like diet/allergen buttons)
                                Button(action: {
                                    manager.answers[manager.currentIndex] = [option]
                                }) {
                                    Text(option)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
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
                        }

                        if question.allowsCustomInput {
                            Button(action: { showCustomInputPopup = true }) {
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

                    Spacer(minLength: 80)
                }
            }

            // Bottom Buttons
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                HStack(spacing: 16) {
                    // Back Button
                    Button(action: {
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
                        searchText = ""
                        if manager.currentIndex < manager.questions.count - 1 {
                            manager.currentIndex += 1
                        } else {
                            // persist profile and integrate severities
                            manager.saveProfile()
                            onComplete()
                        }
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
            VStack(spacing: 24) {
                Text("Enter or describe your allergen or diet")
                    .font(.headline)
                    .padding(.top)

                TextField("e.g. sunflower oil", text: $customInput)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .accentColor(Color("PrimaryGreen"))
                    .padding(.horizontal)

                Button("Add") {
                    if !customInput.isEmpty {
                        if !question.options.contains(customInput) {
                            manager.questions[manager.currentIndex].options.append(customInput)
                        }
                        var updated = manager.answers[manager.currentIndex] ?? []
                        updated.append(customInput)
                        manager.answers[manager.currentIndex] = updated

                    }
                    showCustomInputPopup = false
                    customInput = ""
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("PrimaryGreen"))
                .foregroundColor(.white)
                .cornerRadius(20)
                .padding(.horizontal)

                Button("Cancel") {
                    showCustomInputPopup = false
                    customInput = ""
                }
                .foregroundColor(.red)

                Spacer()
            }
            .padding(.top)
        }
    }
}
