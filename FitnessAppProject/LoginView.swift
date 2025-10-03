import SwiftUI
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import FirebaseCore

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    
    @State private var shouldNavigateToProfileSetup = false
    @State private var errorAlertMessage: String?
    @State private var isShowingErrorAlert = false
    
    // --- A state to track if the user has accepted the terms ---
    @State private var termsAccepted = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    // --- App Logo and Title ---
                    VStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Theme.accentColor)
                        // --- THIS IS THE CHANGE ---
                        Text("Welcome to Movementum")
                            .font(.largeTitle).bold()
                            .foregroundColor(Theme.textColor)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("Sign in to save your progress and get a personalized experience.")
                        .font(.headline)
                        .foregroundColor(Theme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    
                    // --- The Google Sign-In Button ---
                    GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .wide, state: .normal)) {
                        handleSignInWithGoogle()
                    }
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .disabled(!termsAccepted)
                    .opacity(termsAccepted ? 1.0 : 0.5)
                    
                    // --- The Terms and Conditions Checkbox ---
                    HStack {
                        Button(action: {
                            termsAccepted.toggle()
                        }) {
                            Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
                                .foregroundColor(Theme.accentColor)
                        }
                        
                        // This text includes tappable links to your legal pages
                        Text("I agree to the [Terms of Service](https://msuhail2007.github.io/movementum-policy/privacy-policy.html) and [Privacy Policy](https://msuhail2007.github.io/movementum-policy/privacy-policy.html).")
                            .font(.caption)
                            .foregroundColor(Theme.secondaryTextColor)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding()
            }
            .onChange(of: diaryViewModel.userProfileExists) {
                guard let exists = diaryViewModel.userProfileExists else { return }
                if exists {
                    appState.isLoggedIn = true
                } else {
                    shouldNavigateToProfileSetup = true
                }
            }
            .navigationDestination(isPresented: $shouldNavigateToProfileSetup) {
                ProfileSetupView()
            }
            .alert("Login Error", isPresented: $isShowingErrorAlert, actions: {
                Button("OK") {}
            }, message: {
                Text(errorAlertMessage ?? "An unknown error occurred.")
            })
        }
    }

    // --- Google Sign-In Handler ---
    private func handleSignInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                self.errorAlertMessage = "Google Sign-In failed. Please try again.\n\n(\(error.localizedDescription))"
                self.isShowingErrorAlert = true
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self.errorAlertMessage = "Could not sign in to our servers. Please try again. \n\n(\(error.localizedDescription))"
                    self.isShowingErrorAlert = true
                    return
                }
                
                // If this is a new user, pre-fill their name from Google
                if let googleUser = result?.user,
                   self.diaryViewModel.userProfileExists == false {
                    
                    let name = googleUser.profile?.name ?? "New User"
                    // --- THIS IS THE FIX ---
                    // We now include the missing workoutDaysPerWeek argument.
                    let initialProfile = UserProfile(name: name, dob: Date(), height: 0, weight: 0, goal: "Not Set", workoutDaysPerWeek: 3)
                    self.diaryViewModel.save(userProfile: initialProfile)
                }
                
                print("Successfully signed in to Firebase with Google.")
            }
        }
    }
}


#Preview {
    LoginView()
        .preferredColorScheme(.dark)
        .environmentObject(AppState())
        .environmentObject(DiaryViewModel())
}

