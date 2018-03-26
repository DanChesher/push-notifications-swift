import Foundation

struct NetworkService: PushNotificationsNetworkable {

    let url: URL
    let session: URLSession

    typealias NetworkCompletionHandler = (_ response: NetworkResponse) -> Void

    // MARK: PushNotificationsNetworkable
    func register(deviceToken: Data, instanceId: String, completion: @escaping CompletionHandler) {
        let deviceTokenString = deviceToken.hexadecimalRepresentation()
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""

        let metadata = Metadata.update()

        guard let body = try? Register(token: deviceTokenString, instanceId: instanceId, bundleIdentifier: bundleIdentifier, metadata: metadata).encode() else { return }
        let request = self.setRequest(url: self.url, httpMethod: .POST, body: body)

        self.networkRequest(request, session: self.session) { (response) in
            switch response {
            case .Success(let data, let httpURLResponse):
                guard let device = try? JSONDecoder().decode(Device.self, from: data) else { return }
                completion(device.id, httpURLResponse)
            case .Failure(let data, let httpURLResponse):
                guard let reason = try? JSONDecoder().decode(Reason.self, from: data) else { return }

                print(reason.description)
                completion(nil, httpURLResponse)
            }
        }
    }

    func subscribe(completion: @escaping CompletionHandler) {
        let request = self.setRequest(url: self.url, httpMethod: .POST)

        self.networkRequest(request, session: self.session) { (response) in
            switch response {
            case .Success(_, let httpURLResponse):
                completion(nil, httpURLResponse)
            case .Failure(_, let httpURLResponse):
                completion(nil, httpURLResponse)
            }
        }
    }

    func setSubscriptions(interests: Array<String>, completion: @escaping CompletionHandler) {
        guard let body = try? Interests(interests: interests).encode() else { return }
        let request = self.setRequest(url: self.url, httpMethod: .PUT, body: body)

        self.networkRequest(request, session: self.session) { (response) in
            switch response {
            case .Success(_, let httpURLResponse):
                completion(nil, httpURLResponse)
            case .Failure(_, let httpURLResponse):
                completion(nil, httpURLResponse)
            }
        }
    }

    func unsubscribe(completion: @escaping CompletionHandler) {
        let request = self.setRequest(url: self.url, httpMethod: .DELETE)

        self.networkRequest(request, session: self.session) { (response) in
            switch response {
            case .Success(_, let httpURLResponse):
                completion(nil, httpURLResponse)
            case .Failure(_, let httpURLResponse):
                completion(nil, httpURLResponse)
            }
        }
    }

    func unsubscribeAll(completion: @escaping CompletionHandler) {
        self.setSubscriptions(interests: [], completion: completion)
    }

    func track(userInfo: [AnyHashable: Any], eventType: String, deviceId: String, completion: @escaping CompletionHandler) {
        guard let publishId = PublishId(userInfo: userInfo).id else { return }
        let timestampSecs = UInt(Date().timeIntervalSince1970)
        guard let body = try? Track(publishId: publishId, timestampSecs: timestampSecs, eventType: eventType, deviceId: deviceId).encode() else { return }

        let request = self.setRequest(url: self.url, httpMethod: .POST, body: body)
        self.networkRequest(request, session: self.session) { (response) in
            switch response {
            case .Success(_, let httpURLResponse):
                completion(nil, httpURLResponse)
            case .Failure(_, let httpURLResponse):
                completion(nil, httpURLResponse)
            }
        }
    }

    func syncMetadata(completion: @escaping CompletionHandler) {
        guard let metadataDictionary = Metadata.load() else { return }
        let metadata = Metadata(propertyListRepresentation: metadataDictionary)
        if metadata.hasChanged() {
            let updatedMetadataObject = Metadata.update()
            guard let body = try? updatedMetadataObject.encode() else { return }
            let request = self.setRequest(url: self.url, httpMethod: .PUT, body: body)
            self.networkRequest(request, session: self.session) { (response) in
                switch response {
                case .Success(_, let httpURLResponse):
                    completion(nil, httpURLResponse)
                case .Failure(_, let httpURLResponse):
                    completion(nil, httpURLResponse)
                }
            }
        }
    }

    // MARK: Networking Layer
    private func networkRequest(_ request: URLRequest, session: URLSession, completion: @escaping NetworkCompletionHandler) {
        session.dataTask(with: request, completionHandler: { (data, response, error) in
            guard
                let data = data,
                let httpURLResponse = response as? HTTPURLResponse
            else { return }

            guard httpURLResponse.statusCode == 200, error == nil else {
                return completion(NetworkResponse.Failure(data: data, response: httpURLResponse))
            }

            completion(NetworkResponse.Success(data: data, response: httpURLResponse))

        }).resume()
    }

    private func setRequest(url: URL, httpMethod: HTTPMethod, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = httpMethod.rawValue
        request.httpBody = body

        return request
    }
}
