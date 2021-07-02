//
//  URLSessionRequestExecutor.swift
//  Pods
//
//  Created by Admin on 10/11/2016.
//
//

import UIKit

class RequestTask: NSObject {
    var requestId: String
    var retryCount: Int = 0
    var dataTask: URLSessionDataTask
    
    init(requestId: String, dataTask: URLSessionDataTask) {
        self.requestId = requestId
        self.dataTask = dataTask
        super.init()
    }
    
    override var description: String {
        return super.description + "RequestId: \(requestId) RetryCount: \(retryCount) DataTask: \(dataTask)"
    }
}

@objc public class KNKRequestExecutor: NSObject, RequestExecutor, URLSessionDelegate {
    
    private let concurrentTaskQueue = DispatchQueue(label: "com.KalturaNetKit.KNKRequestExecutor.taskQueue",
                                                    attributes: .concurrent)
    
    var requestTasks: [String: RequestTask] = [:] 
    var usedRequestConfiguration: RequestConfiguration?
    
    enum ResponseError: Error {
        case emptyOrIncorrectURL
        case incorrectJSONBody
    }
    
    @objc public static let shared = KNKRequestExecutor()
    @objc public var requestConfiguration: RequestConfiguration = RequestConfiguration()
    
    // MARK: - Private Methods
    
    func remove(request: Request) {
        self.concurrentTaskQueue.async(flags: .barrier) {
            self.requestTasks.removeValue(forKey: request.requestId)
        }
    }
    
    // MARK: - RequestExecutor
    
    public func send(request: Request){
        
        var urlRequest: URLRequest = URLRequest(url: request.url)
        
        // Handle http method
        if let method = request.method {
            urlRequest.httpMethod = method.value
        }
        
        // Handle body
        if let data = request.dataBody {
            urlRequest.httpBody = data
        }
        
        // Handle headers
        if let headers = request.headers {
            for (headerKey,headerValue) in headers {
                urlRequest.setValue(headerValue, forHTTPHeaderField: headerKey)
            }
        }
        
        // Add custom timeoutInterval if configured.
        if let timeout = request.timeout {
            urlRequest.timeoutInterval = timeout
        }
        
        // We will use the request's requestConfiguration if it was configured,
        // otherwise we will use the executor's requestConfiguration.
        if let requestConfiguration = request.configuration {
            usedRequestConfiguration = requestConfiguration
        } else {
            usedRequestConfiguration = requestConfiguration
        }
        
        let session: URLSession!
        
        if let configuration = usedRequestConfiguration, configuration.ignoreLocalCache {
            let sessionConfiguration = URLSessionConfiguration.default
            sessionConfiguration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
            session = URLSession(configuration: sessionConfiguration)
        } else {
            session = URLSession.shared
        }
        
        let urlSessionDataTask = session.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            // Perform retry in case the response code is 400 - 599.
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 && httpResponse.statusCode < 600 {
                    // Check if it exists and wasn't canceled
                    var task: RequestTask?
                    self.concurrentTaskQueue.sync {
                        task = self.requestTasks[request.requestId]
                    }
                    
                    guard let requestTask = task else { return }
                    
                    let retryCount = self.usedRequestConfiguration?.retryCount ?? 0
                    
                    if requestTask.retryCount < retryCount {
                        self.concurrentTaskQueue.async(flags: .barrier) {
                            requestTask.retryCount += 1
                        }
                        self.send(request: request)
                        return
                    }
                }
            }
        
            // Retry was not performed, remove the request and call the completion block.
            self.remove(request: request)
            
            DispatchQueue.main.async {
                if let completion = request.completion {
                    
                    // If we got an error because the request failed, send that error.
                    if let err = error {
                        let nsError = err as NSError
                        switch nsError.code {
                        case NSURLErrorCancelled:
                            // Canceled - no need to call the completion block
                            break
                        default:
                            let result = Response(data: nil, error: nsError)
                            completion(result)
                        }
                        return
                    }
                    
                    // If the response code is 400 - 599, send that as the error.
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode >= 400 && httpResponse.statusCode < 600 {
                            var json: Any?
                            if let d = data, !d.isEmpty {
                                json = try? JSONSerialization.jsonObject(with: d, options: JSONSerialization.ReadingOptions(rawValue:0))
                            }
                            let nsError = NSError(domain: "NetKitHttpResponseError", code: httpResponse.statusCode, userInfo: nil)
                            let result = Response(data: json, error: nsError)
                            completion(result)
                            return
                        }
                    }
                    
                    // If we got data returned from the server and it's not empty, parse and return it.
                    if let d = data, !d.isEmpty {
                        do {
                            let json = try request.responseSerializer.serialize(data: d)
                            let result = Response(data: json, error: nil)
                            completion(result)
                        } catch {
                            // The parsing error will be sent.
                            let result = Response(data: nil, error: error)
                            completion(result)
                        }
                        return
                    }
                    // Will arrive here only if there was no request error, the response status code was 100 - 399, and the data is empty.
                     else {
                        let result = Response(data: nil, error: error)
                        completion(result)
                    }
                }
            }
        }
        
        // Check if the request exists, in case of a retry
        var requestTask: RequestTask?
        self.concurrentTaskQueue.sync {
            requestTask = self.requestTasks[request.requestId]
        }
        if requestTask != nil {
            self.concurrentTaskQueue.async(flags: .barrier) {
                requestTask?.dataTask = urlSessionDataTask
            }
        } else {
            self.concurrentTaskQueue.async(flags: .barrier) {
                self.requestTasks[request.requestId] = RequestTask(requestId: request.requestId, dataTask: urlSessionDataTask)
            }
        }
        urlSessionDataTask.resume()
    }
    
    public func cancel(request: Request) {
        
        var requestTask: RequestTask?
        self.concurrentTaskQueue.sync {
            requestTask = self.requestTasks[request.requestId]
        }
        
        requestTask?.dataTask.cancel()
        
        remove(request: request)
    }
    
    public func clean() {
    
    }
    
    // MARK: - URLSessionDelegate
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?){
        
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void){
        
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession){
        
    }
    
}
