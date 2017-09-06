/// Represents a GraphQL response received from a server.
public final class GraphQLResponse<Operation: GraphQLOperation> {
  public let operation: Operation
  public let body: JSONObject
  public let responseHeaders: [AnyHashable: Any]

  public init(operation: Operation, body: JSONObject, responseHeaders: [AnyHashable: Any]) {
    self.operation = operation
    self.body = body
    self.responseHeaders = responseHeaders
  }

  func parseResult(cacheKeyForObject: CacheKeyForObject? = nil) throws -> Promise<(GraphQLResult<Operation.Data>, RecordSet?)>  {
    let errors: [GraphQLError]?
    
    if let errorsEntry = body["errors"] as? [JSONObject] {
      errors = errorsEntry.map(GraphQLError.init)
    } else {
      errors = nil
    }

    if let dataEntry = body["data"] as? JSONObject {
      let executor = GraphQLExecutor { object, info in
        return .result(.success(object[info.responseKeyForField]))
      }
      
      executor.cacheKeyForObject = cacheKeyForObject
      
      let mapper = GraphQLSelectionSetMapper<Operation.Data>()
      let normalizer = GraphQLResultNormalizer()
      let dependencyTracker = GraphQLDependencyTracker()
      
      return firstly {
        try executor.execute(selections: Operation.Data.selections, on: dataEntry, withKey: rootKey(forOperation: operation), variables: operation.variables, accumulator: zip(mapper, normalizer, dependencyTracker))
      }.map { (data, records, dependentKeys) in
        (GraphQLResult(data: data, errors: errors, dependentKeys: dependentKeys, responseHeaders: self.responseHeaders), records)
      }
    } else {
        return Promise(fulfilled: (GraphQLResult(data: nil, errors: errors, dependentKeys: nil, responseHeaders: nil), nil))
    }
  }
}
