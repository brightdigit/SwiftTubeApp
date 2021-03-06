import Combine

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
