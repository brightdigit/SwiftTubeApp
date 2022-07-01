import Combine
import SwiftUI
import Prch
import SwiftTube

class SubscriptionsModel : ObservableObject {
    let tokenResponseSubject = PassthroughSubject<OAuthTokenResponse,Never>()
    let errorSubject = PassthroughSubject<Error,Never>()
    let clientSubject = PassthroughSubject<Client<URLSession, YouTube.API>, Never>()
    
    var cancellables = [AnyCancellable]()
    let signinModel = SignInViewModel()
    
    @Published var subscriptionsResult : ClientResult<SwiftTube.Subscriptions.YoutubeSubscriptionsList.Response.SuccessType, SwiftTube.Subscriptions.YoutubeSubscriptionsList.Response.FailureType>?
    
    init () {
        self.signinModel.$result.map{try? $0?.get()}.compactMap{$0}.subscribe(self.tokenResponseSubject).store(in: &self.cancellables)
        self.signinModel.$result.map{$0?.getError()}.compactMap{$0}.subscribe(self.errorSubject).store(in: &self.cancellables)
        
        self.tokenResponseSubject
            .map { response in
                return YouTube.API(token: response.accessToken)
            }.map { api in
                return Client(api: api, session: URLSession.shared)
            }.subscribe(self.clientSubject).store(in: &self.cancellables)
        
        let clientResultSubjectPublisher = self.clientSubject.flatMap { client in
            Future { completion in
                
                client.request(Subscriptions.YoutubeSubscriptionsList.Request(options: .init(part: ["snippet","contentDetails"], mine: true))) { result in
                    completion(.success(result))
                }
            }
        }
        
        clientResultSubjectPublisher.map{$0 as ClientResult?}.receive(on: DispatchQueue.main).assign(to: &self.$subscriptionsResult)
        errorSubject.map(ClientError.unknownError).map(ClientResult.failure).map{$0 as ClientResult?}.receive(on: DispatchQueue.main).assign(to: &self.$subscriptionsResult)
    }
    func signIn () {
        self.signinModel.signIn()
    }
}
