

extension Result {
    func getError() -> Failure? {
        guard case let .failure(failure) = self else {
            return nil
        }
        return failure
        
    }
}
