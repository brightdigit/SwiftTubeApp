//
//  ContentView.swift
//  SwiftTubeApp
//
//  Created by Leo Dion on 6/29/22.
//

import Prch
import SwiftUI
import Combine
import CryptoKit
import AuthenticationServices
import SwiftTube

extension SwiftTube.Subscription : Identifiable {
    
}

enum PKCEError : Error {
    case failedToGenerateRandomOctets
    case failedToCreateChallengeForVerifier
}

struct OAuthorizationRequest : Identifiable{
    
    static let defaultScopes = ["https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.channel-memberships.creator",
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.readonly",
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtubepartner",
    "https://www.googleapis.com/auth/youtubepartner-channel-audit"]
    
    internal init () throws {
//        let codeVerifier43 = try 32
//            |> generateCryptographicallySecureRandomOctets
//            |> base64URLEncode
        
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
//
//struct SafariView : UIViewControllerRepresentable {
//    let url : URL
//
//    func makeUIViewController(context: Context) -> SFSafariViewController {
//        return SFSafariViewController(url: self.url)
//    }
//
//    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
//
//    }
//}

struct OAuthTokenResponse : Codable {
    let accessToken : String
    let expiresIn: TimeInterval
    let scope: String
    let refreshToken: String
    
    enum CodingKeys : String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case scope = "scope"
        case refreshToken = "refresh_token"
    }
    
}
extension Future where Failure == Never {
    convenience init<SuccessType>(operation: @escaping () async throws -> SuccessType) where Output == Result<SuccessType, Error> {
        self.init { promise in
            _Concurrency.Task {
                do {
                    let output = try await operation()
                    promise(.success(.success(output)))
                } catch {
                    promise(.success(.failure(error)))
                }
            }
        }
    }
}
class SignInViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    static let baseURLComponents = URLComponents(string: "https://oauth2.googleapis.com/token")!
    var subscriptions = [AnyCancellable]()
    @Published var code : String?
    @Published var expirationDate : String?
    @Published var request : OAuthorizationRequest?
    @Published var result : Result<OAuthTokenResponse, Error>?
    @Published var client : Client<URLSession, YouTube.API>?
    @Published var subscriptionsResult : ClientResult<SwiftTube.Subscriptions.YoutubeSubscriptionsList.Response.SuccessType, SwiftTube.Subscriptions.YoutubeSubscriptionsList.Response.FailureType>?
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    override init () {
        super.init()
        self.$request.compactMap{$0}.combineLatest(self.$code.compactMap{$0}).map { request, code -> [URLQueryItem] in
            var queryItems = [URLQueryItem]()
            queryItems.append(.init(name: "client_id", value: request.clientID))
            queryItems.append(.init(name: "code", value: code))
            queryItems.append(.init(name: "code_verifier", value: request.codeVerifier))
            queryItems.append(.init(name: "redirect_uri", value: request.redirectURI))
            queryItems.append(.init(name: "grant_type", value: "authorization_code"))
            return queryItems
        }.map { queryItems -> URLRequest in
            var urlComponents = Self.baseURLComponents
            urlComponents.queryItems = queryItems
            var urlRequest = URLRequest(url: urlComponents.url!)
            urlRequest.httpMethod = "POST"
            return urlRequest
        }.flatMap { urlRequest in
            return Future<Result<OAuthTokenResponse, Error>, Never>(operation:{
                let response = try await URLSession.shared.data(for: urlRequest)
                
                let data = response.0
                return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            })
        }.print().map{$0 as Result<OAuthTokenResponse, Error>?}.receive(on: DispatchQueue.main).assign(to: &self.$result)
        
        
        self.$result.compactMap {
            try? $0?.get()
        }.map { response in
            return YouTube.API(token: response.accessToken)
        }.map { api in
            return Client(api: api, session: URLSession.shared)
        }.map{$0 as Client?}.receive(on: DispatchQueue.main)
            .assign(to: &self.$client)
        
        
        self.$client.compactMap{ $0 }.flatMap { client in
            Future { completion in
                
                client.request(Subscriptions.YoutubeSubscriptionsList.Request(options: .init(part: ["snippet","contentDetails"], mine: true))) { result in
                    completion(.success(result))
                }
            }
        }.map({ result in
            dump(result)
            if case let .failure(.unexpectedStatusCode(statusCode: _, data: data)) = result {
                print("error:", String(bytes: data, encoding: .utf8) ?? "")
            }
            return result
        }).map{$0 as ClientResult?}.receive(on: DispatchQueue.main).assign(to: &self.$subscriptionsResult)
        
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    func processResponseURL(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems else {
            return
        }
        let codeQueryItem = queryItems.first {
            $0.name == "code"
        }
        
        guard let codeQueryItem = codeQueryItem else {
            return
        }
        DispatchQueue.main.async {
            self.code = codeQueryItem.value
        }

//        let anilistComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
//        // Anilist actually returns the token in a messed up way.
//        // All the parameters - including query parameters - are AFTER the fragment.
//        // So I can't just access the query property of these components to get all the data I need.
//        // To work around this and save myself the headache of possible encoding issues, I will create
//        // a new URL using the fragment of the old components and some dummy domain.
//
//        if  let anilistFragment = anilistComponents?.fragment,
//            let dummyURL = URL(string: "http://dummyurl.com?\(anilistFragment)"),
//            let components = URLComponents(url: dummyURL, resolvingAgainstBaseURL: true),
//            let queryItems = components.queryItems,
//            let token = queryItems.filter ({ $0.name == "access_token" }).first?.value,
//            let expirationDate = queryItems.filter ({ $0.name == "expires_in" }).first?.value
//            {
//            DispatchQueue.main.async {
//                self.token = token
//                self.expirationDate = expirationDate
//            }
//            /// Store the token
//            /// Store the token expiration date if necessary.
//        }
    }
    
    func signIn() {
           let signInPromise = Future<URL, Error> { completion in
               let request :  OAuthorizationRequest
               do {
                request = try OAuthorizationRequest()
               } catch {
                   completion(.failure(error))
                   return
               }
               self.request = request
               
               let authSession = ASWebAuthenticationSession(
                url: request.url, callbackURLScheme:
                    OAuthorizationRequest.scheme) { (url, error) in
                   if let error = error {
                       completion(.failure(error))
                   } else if let url = url {
                       completion(.success(url))
                   }
               }
               
               authSession.presentationContextProvider = self
               authSession.prefersEphemeralWebBrowserSession = true
               authSession.start()
           }
           
           signInPromise.sink { (completion) in
               switch completion {
               case .failure(let error): break// Handle the error here. An error can even be when the user cancels authentication.
               default: break
               }
           } receiveValue: { (url) in
               self.processResponseURL(url: url)
           }
           .store(in: &subscriptions)
       }

}

struct ContentView: View {
    @StateObject var signinModel = SignInViewModel()
    var body: some View {
        if let subscriptions = try? signinModel.subscriptionsResult?.get().items {
            ForEach(subscriptions, id: \.id) { subscription in
                Text(subscription.snippet?.channelTitle ?? "No Title")
            }
        } else {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                Text("Hello, world!")
                Button {
                    self.signinModel.signIn()
                } label: {
                    Text("Authorize")
                }
            }
        }
//        .sheet(item: self.$oauthRequest) { request in
//            ASWebAuthenticationSession(url: request, callbackURLScheme: <#T##String?#>, completionHandler: <#T##ASWebAuthenticationSession.CompletionHandler##ASWebAuthenticationSession.CompletionHandler##(URL?, Error?) -> Void#>)
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
