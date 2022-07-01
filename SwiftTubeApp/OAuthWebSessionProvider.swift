import AuthenticationServices
import Combine
class OAuthWebSessionProvider {
    internal init(scheme: String, provider: ASWebAuthenticationPresentationContextProviding, session: ASWebAuthenticationSession? = nil) {
        self.scheme = scheme
        self.provider = provider
        self.session = session
    }
    
    let scheme : String
    let provider : ASWebAuthenticationPresentationContextProviding
    var session : ASWebAuthenticationSession?
    
    func publisher(forURL url: URL) -> AnyPublisher<Result<URL, Error>, Never> {
        Future<Result<URL, Error>, Never> { completion in
            guard self.session == nil else {
                return
            }
            let authSession = ASWebAuthenticationSession(
                url: url, callbackURLScheme:
                    self.scheme) { (url, error) in
                        if let error = error {
                            completion(.success(Result.failure(error)))
                        } else if let url = url {
                            completion(.success(.success(url)))
                        }
                    }
            
            
            authSession.presentationContextProvider = self.provider
            authSession.prefersEphemeralWebBrowserSession = true
            self.session = authSession
            authSession.start()
        }.eraseToAnyPublisher()
    }
    
    func cancel () {
        self.session = nil
    }
}
