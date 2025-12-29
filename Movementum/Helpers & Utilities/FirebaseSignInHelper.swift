//
//  FirebaseSignInHelper.swift
//  FitnessAppProject
//
//  Created by Mohammed suhail on 06/09/2025.
//


import Foundation
import CryptoKit
import AuthenticationServices // This is needed for the security framework access

// This is a standard helper class, often based on Firebase's own examples,
// for securely handling the "Sign in with Apple" flow. It is responsible for
// generating and hashing a cryptographic nonce.

// A "nonce" (number used once) is a random string that is created for each sign-in
// attempt. It's sent to Apple and then returned, proving that the login response
// is fresh and not a captured, replayed attack.
class FirebaseSignInHelper {
    
    // A static variable to hold the most recently created nonce.
    // This allows the LoginView's completion handler to access it.
    static var currentNonce: String?

    // Generates a secure, random string of a given length to be used as the nonce.
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                // SecRandomCopyBytes is a cryptographically secure way to generate random data.
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate random bytes. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    // Hashes the input string using the SHA256 algorithm.
    // Apple requires that the nonce be hashed before it's sent in the sign-in request.
    @available(iOS 13.0, *)
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

