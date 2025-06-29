import Foundation

class GraphQLClient {
  private let baseURL: URL
  private let session: URLSession

  init(baseURL: String, session: URLSession = .shared) {
    self.baseURL = URL(string: baseURL)!
    self.session = session
  }

  func execute<T: Codable>(
    query: String,
    variables: [String: Any]? = nil,
    authorization: String? = nil,
    responseType: T.Type
  ) async throws -> T {
    let graphQLRequest = Request(query: query, variables: variables)

    var urlRequest = URLRequest(url: baseURL)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let authorization = authorization {
      urlRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    let encoder = JSONEncoder()
    urlRequest.httpBody = try encoder.encode(graphQLRequest)

    let (data, response) = try await session.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw Error.invalidResponse
    }

    guard 200...299 ~= httpResponse.statusCode else {
      throw Error.httpError(httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let graphQLResponse = try decoder.decode(Response<T>.self, from: data)

    if let errors = graphQLResponse.errors, !errors.isEmpty {
      throw Error.graphQLErrors(errors)
    }

    guard let data = graphQLResponse.data else {
      throw Error.noData
    }

    return data
  }
}

extension GraphQLClient {
  struct Request: Codable {
    let query: String
    let variables: [String: AnyCodable]?

    init(query: String, variables: [String: Any]? = nil) {
      self.query = query
      self.variables = variables?.mapValues { AnyCodable($0) }
    }
  }

  struct Response<T: Codable>: Codable {
    let data: T?
    let errors: [ErrorResponse]?
  }

  struct ErrorResponse: Codable {
    let message: String
    let locations: [Location]?
    let path: [String]?

    struct Location: Codable {
      let line: Int
      let column: Int
    }
  }

  enum Error: Swift.Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case graphQLErrors([ErrorResponse])
    case noData

    var errorDescription: String? {
      switch self {
      case .invalidResponse:
        return "Invalid response received"
      case .httpError(let statusCode):
        return "HTTP error with status code: \(statusCode)"
      case .graphQLErrors(let errors):
        return "GraphQL errors: \(errors.map(\.message).joined(separator: ", "))"
      case .noData:
        return "No data returned from GraphQL query"
      }
    }
  }
}
