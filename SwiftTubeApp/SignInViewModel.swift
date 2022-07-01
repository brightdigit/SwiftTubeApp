import Foundation
import SwiftUI
import Combine
import AuthenticationServices

class SignInViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    static let baseURLComponents = URLComponents(string: "https://oauth2.googleapis.com/token")!
    
    var subscriptions = [AnyCancellable]()
    let codeSubject = PassthroughSubject<String, Never>()
    let errorSubject  = PassthroughSubject<Error, Never>()
    let requestSubject =  PassthroughSubject<OAuthorizationRequest, Never>()
    var sessionProvider : OAuthWebSessionProvider!
    
    @Published var result : Result<OAuthTokenResponse, Error>?
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    fileprivate func queryItems(_ request: OAuthorizationRequest, _ code: String) -> [URLQueryItem] {
        var queryItems = [URLQueryItem]()
        queryItems.append(.init(name: "client_id", value: request.clientID))
        queryItems.append(.init(name: "code", value: code))
        queryItems.append(.init(name: "code_verifier", value: request.codeVerifier))
        queryItems.append(.init(name: "redirect_uri", value: request.redirectURI))
        queryItems.append(.init(name: "grant_type", value: "authorization_code"))
        return queryItems
    }
    
    fileprivate func urlRequest(_ queryItems: [URLQueryItem]) -> URLRequest {
        var urlComponents = Self.baseURLComponents
        urlComponents.queryItems = queryItems
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "POST"
        return urlRequest
    }
    
    override init () {
        super.init()
        
        self.sessionProvider = .init(scheme: OAuthorizationRequest.scheme, provider: self)
        
        let authSessionResultPublisher = self.requestSubject.share().map(\.url).flatMap(self.sessionProvider.publisher(forURL:))
        
        
        
        let processURLResultPublisher = authSessionResultPublisher.share().compactMap{try? $0.get()}.map{ url in
            Result{
                try self.processResponseURL(url: url)
            }
        }
        
        let authSessionErrorPublisher = authSessionResultPublisher.compactMap {
            return $0.getError()
        }
        authSessionErrorPublisher.sink { _ in
            self.sessionProvider.cancel()
        }.store(in: &self.subscriptions)
        authSessionErrorPublisher.share().subscribe(self.errorSubject).store(in: &self.subscriptions)
        
        
        processURLResultPublisher.share().compactMap{try? $0.get()}.subscribe(self.codeSubject).store(in: &self.subscriptions)
        processURLResultPublisher.compactMap{$0.getError()}.subscribe(self.errorSubject).store(in: &self.subscriptions)
        
        self.requestSubject.combineLatest(self.codeSubject).map { request, code -> [URLQueryItem] in
            return self.queryItems(request, code)
        }.map { queryItems -> URLRequest in
            return self.urlRequest(queryItems)
        }.flatMap { urlRequest in
            return Future<Result<OAuthTokenResponse, Error>, Never>(operation:{
                let response = try await URLSession.shared.data(for: urlRequest)
                
                let data = response.0
                return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            })
        }.map{$0 as Result<OAuthTokenResponse, Error>?}.receive(on: DispatchQueue.main).assign(to: &self.$result)
        
        errorSubject.map(Result<OAuthTokenResponse,Error>.failure).map{$0 as Result<OAuthTokenResponse, Error>?}.receive(on: DispatchQueue.main).assign(to: &self.$result)
        
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    func processResponseURL(url: URL) throws -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems else {
            throw OAuthResponseParsingError(url: url)
        }
        let codeQueryItem = queryItems.first {
            $0.name == "code"
        }
        
        guard let codeQueryItem = codeQueryItem else {
            throw OAuthResponseParsingError(url: url)
        }
        
        guard let value = codeQueryItem.value else {
            throw OAuthResponseParsingError(url: url)
        }
        
        return value
    }
    
    func signIn() {
        let request :  OAuthorizationRequest
        do {
            request = try OAuthorizationRequest()
        } catch {
            self.errorSubject.send(error)
            return
        }
        self.requestSubject.send(request)
        
    }
    
}
