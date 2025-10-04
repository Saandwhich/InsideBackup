import SwiftUI

struct DescribeMealView: View {
    @Binding var isPresented: Bool
    @State private var mealName: String = ""
    @State private var mealDescription: String = ""
    @State private var isLoading = false
    
    private let openAIService = OpenAIService()
    private let profileStore = ProfileStore.shared
    var onAnalysisComplete: (String, String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Text("Describe A Meal")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color("PrimaryGreen"))
                        Spacer()
                        Button {
                            isPresented = false
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "xmark")
                                    .foregroundColor(.black)
                                    .font(.system(size: 12, weight: .regular))
                            }
                            .padding(8)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    Text("Enter the meal name and a short description for analysis.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                    
                    // Meal Name
                    TextField("Meal Name", text: $mealName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                        .tint(Color("PrimaryGreen"))
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    // Meal Description
                    ZStack(alignment: .topLeading) {
                        Color(.systemGray6)
                            .cornerRadius(14)
                        
                        if mealDescription.isEmpty {
                            Text("Enter your meal description here...")
                                .foregroundColor(Color.gray.opacity(0.5))
                                .padding(EdgeInsets(top: 16, leading: 12, bottom: 0, trailing: 0))
                        }
                        
                        TextEditor(text: $mealDescription)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.primary)
                            .tint(Color("PrimaryGreen"))
                            .accessibilityLabel("Meal description input")
                    }
                    .frame(minHeight: 140)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                    
                    // Analyze Button
                    Button(action: analyzeMeal) {
                        HStack {
                            Image(systemName: "sparkle")
                                .font(.system(size: 18))
                            Text("Analyze")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color("PrimaryGreen"))
                        .clipShape(Capsule())
                        .padding(.horizontal)
                    }
                    .disabled(mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              isLoading)
                    .opacity((mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              isLoading) ? 0.5 : 1)
                    .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: 500) // cap content width on iPad
            .background(Color.white)
            .cornerRadius(24)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onTapGesture { hideKeyboard() }
            .keyboardAdaptive()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .interactiveDismissDisabled(true)
        .transition(.opacity)
        .zIndex(1)
    }

    private func analyzeMeal() {
        isLoading = true
        let allergens = profileStore.profile?.allergens ?? []
        let diets = profileStore.profile?.diets ?? []
        let dietaryRestrictions = "Allergens: \(allergens.joined(separator: ", ")); Diets: \(diets.joined(separator: ", "))"

        let analysisPrompt = """
        You are an expert nutritionist, diet coach, and medical doctor specializing in personalized dietary guidance. Your top priority is to provide safe, accurate, and clear dietary advice strictly based on the user's specified dietary restrictions: \(dietaryRestrictions)

        Given the meal description provided by the user, analyze the meal strictly based on its traditional, standard recipe and ingredients, without making any assumptions or modifications unless the user explicitly states otherwise.

        Respond only with the following clearly labeled sections:

        Ingredients: (List only the ingredients of the food in its traditional form strictly as they appear in a nutrition label.)

        Safety Score: (Provide a numeric safety score from 1 to 10 indicating how safe this meal is considering ONLY the user's dietary restrictions.)

        Reason: (Briefly explain why the meal received this safety score, ONLY focusing on allergens or dietary conflicts.)

        Suggestions: (Offer practical advice or alternative options to improve the meal’s safety regarding the dietary restrictions ONLY)

        User query: \(mealDescription)
        """

        openAIService.analyzeMealDescription(analysisPrompt, userAllergens: allergens, userDiets: diets) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let analysisText):
                    onAnalysisComplete(analysisText, mealName.trimmingCharacters(in: .whitespacesAndNewlines))
                case .failure(let error):
                    onAnalysisComplete("Error: \(error.localizedDescription)", mealName.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
