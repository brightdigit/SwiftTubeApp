import Foundation

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
