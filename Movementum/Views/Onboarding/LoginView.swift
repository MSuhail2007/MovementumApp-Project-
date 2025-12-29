import SwiftUI
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import FirebaseCore
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var healthManager: HealthStoreManager
    
    @State private var shouldNavigateToOnboarding = false
    @State private var errorAlertMessage: String?
    @State private var isShowingErrorAlert = false
    
    @State private var isAppleSignInAlertShowing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Image("login_background")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
                
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    Spacer()
                    
                    Text("")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    Spacer()
                    
                    VStack(spacing: 15) {
                        Button(action: handleSignInWithGoogle) {
                            Image("google_signin_button")
                                .resizable()
                                .scaledToFit()
                        }
                        .frame(height: 55)
                        .cornerRadius(15)
                        
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { _ in },
                            onCompletion: { _ in }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(width:235,height: 53)
                        .cornerRadius(50)
                        .onTapGesture {
                            self.isAppleSignInAlertShowing = true
                        }
                    }
                    .padding(.horizontal)
                    
                    Text("By signing up, you agree to our [Terms of Service](https://www.yourapp.com/terms) and [Privacy Policy](https://www.yourapp.com/privacy).")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }
                .padding()
            }
            .alert("Coming Soon!", isPresented: $isAppleSignInAlertShowing) {
                Button("OK") {}
            } message: {
                Text("Sign in with Apple will be available in a future update.")
            }
            .onAppear(perform: checkInitialState)
            // This handles the asynchronous update after a NEW user signs in.
            .onChange(of: diaryViewModel.userProfileExists) {
                handleProfileStateChange()
            }
            .navigationDestination(isPresented: $shouldNavigateToOnboarding) {
                // Use a saved profile if present, otherwise fallback to Auth displayName and Health DOB
                let name = diaryViewModel.userProfile?.name ?? Auth.auth().currentUser?.displayName ?? ""
                let dob = diaryViewModel.userProfile?.dob ?? healthManager.dateOfBirth ?? Date()
                OnboardingFlowView(userName: name, dob: dob)
            }
            .alert("Login Error", isPresented: $isShowingErrorAlert, actions: {
                Button("OK") {}
            }, message: {
                Text(errorAlertMessage ?? "An unknown error occurred.")
            })
        }
    }
    
    // --- THIS IS THE FIX (Part 2) ---
    // A new, robust set of functions to handle navigation logic.
    private func checkInitialState() {
        // If the user is already known when the view appears, handle it.
        if diaryViewModel.userProfileExists != nil {
            handleProfileStateChange()
        }
    }
    
    private func handleProfileStateChange() {
        guard let exists = diaryViewModel.userProfileExists else { return }
        
        if exists {
            // This is a returning user, log them straight in.
            appState.isLoggedIn = true
        } else {
            // This is a new user, send them to onboarding.
            shouldNavigateToOnboarding = true
        }
    }
    
    // --- The Google Sign-In Handler is unchanged and fully functional ---
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
                self.errorAlertMessage = "Google Sign-In failed: \(error.localizedDescription)"
                self.isShowingErrorAlert = true
                return
            }
            
            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self.errorAlertMessage = "Could not sign in to our servers: \(error.localizedDescription)"
                    self.isShowingErrorAlert = true
                    return
                }
                // The DiaryViewModel's auth listener will now handle the rest.
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(DiaryViewModel(isForPreview: true))
            .environmentObject(AppState())
            .environmentObject(HealthStoreManager())
    }
}
