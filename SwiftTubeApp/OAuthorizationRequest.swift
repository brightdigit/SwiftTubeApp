import Security
import Foundation
import CryptoKit

struct OAuthorizationRequest : Identifiable{
    
    static let defaultScopes = ["https://www.googleapis.com/auth/youtube",
                                "https://www.googleapis.com/auth/youtube.channel-memberships.creator",
                                "https://www.googleapis.com/auth/youtube.force-ssl",
                                "https://www.googleapis.com/auth/youtube.readonly",
                                "https://www.googleapis.com/auth/youtube.upload",
                                "https://www.googleapis.com/auth/youtubepartner",
                                "https://www.googleapis.com/auth/youtubepartner-channel-audit"]
    
    internal init () throws {
        let codeVerifier = try OAuthorizationRequest.base64URLEncode(octets: OAuthorizationRequest.generateCryptographicallySecureRandomOctets(count: 32))
        
        self.init(codeVerifier: codeVerifier)
    }
    
    static let scheme = "com.googleusercontent.apps.8192297481-sfe3mbpq8ne81mrgqbdb16c0ltkeg7ac"
    internal init(clientID: String = "8192297481-sfe3mbpq8ne81mrgqbdb16c0ltkeg7ac.apps.googleusercontent.com", redirectURI: String = "\(scheme):", responseType: String = "code", scopes: [String] = Self.defaultScopes, codeVerifier: String, codeChallengeMethod: String = "S256", state: [String : String] = [:], loginHint: String? = nil) {
        
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.responseType = responseType
        self.scopes = scopes
        self.codeVerifier = codeVerifier
        self.codeChallengeMethod = codeChallengeMethod
        self.state = state
        self.loginHint = loginHint
    }
    
    static func generateCryptographicallySecureRandomOctets(count: Int) throws -> [UInt8] {
        var octets = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, octets.count, &octets)
        if status == errSecSuccess { // Always test the status.
            return octets
        } else {
            throw PKCEError.failedToGenerateRandomOctets
        }
    }
    static func base64URLEncode<S>(octets: S) -> String where S : Sequence, UInt8 == S.Element {
        let data = Data(octets)
        return data
            .base64EncodedString() // Regular base64 encoder
            .replacingOccurrences(of: "=", with: "") // Remove any trailing '='s
            .replacingOccurrences(of: "+", with: "-") // 62nd char of encoding
            .replacingOccurrences(of: "/", with: "_") // 63rd char of encoding
            .trimmingCharacters(in: .whitespaces)
    }
    static func challenge(for verifier: String) -> String {
        let challenge = verifier
            .data(using: .ascii) // (a)
            .map { SHA256.hash(data: $0) } // (b)
            .map { base64URLEncode(octets: $0) } // (c)
        
        return challenge!
    }
    static let baseURLComponents = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    let clientID : String
    let redirectURI : String
    let responseType : String
    let scopes : [String]
    let codeVerifier : String
    var codeChallenge : String {
        Self.challenge(for: self.codeVerifier)
    }
    let codeChallengeMethod : String
    let state : [String : String]
    let loginHint : String?
    
    var id : String {
        return codeVerifier
    }
    
    var url : URL {
        var urlComponents = Self.baseURLComponents
        
        var queryItems = [URLQueryItem]()
        
        queryItems.append(.init(name: "client_id", value: self.clientID))
        queryItems.append(.init(name: "redirect_uri", value: self.redirectURI))
        queryItems.append(.init(name: "response_type", value: self.responseType))
        queryItems.append(.init(name: "scope", value: self.scopes.joined(separator: " ")))
        queryItems.append(.init(name: "code_challenge", value: self.codeChallenge))
        queryItems.append(.init(name: "code_challenge_method", value: self.codeChallengeMethod))
        
        if !self.state.isEmpty {
            let value = self.state.map { (key: String, value: String) in
                "\(key)=\(value)"
            }.description.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            queryItems.append(.init(name: "state", value: value))
        }
        
        if let loginHint = loginHint {
            queryItems.append(.init(name: "login_hint", value: loginHint))
        }
        
        urlComponents.queryItems = queryItems
        
        return urlComponents.url!
        
    }
}
