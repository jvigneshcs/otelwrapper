//
//  WrapperAPI.swift
//  OtelWrapper
//
//  Created by Vignesh Jeyaraj on 03/01/23.
//

import Foundation
import NIOHTTP2
import NIOPosix
import GRPC

public typealias HTTPProtocol = HTTP2FramePayloadToHTTP1ClientCodec.HTTPProtocol

@objc
public class WrapperAPI: NSObject {
    
    private let client: ClientConnection
    
    @objc
    public convenience init(libraryName: String,
                            libraryVersion: String,
                            secureSchema: Bool = true,
                            host: String,
                            port: Int = 443,
                            headers: [String: String]? = nil) {
        let schema: HTTPProtocol = secureSchema ? .https : .http
        let headersTuples = headers?.map { $0 }
        self.init(libraryName: libraryName,
                  libraryVersion: libraryVersion,
                  schema: schema,
                  host: host,
                  port: port,
                  headers: headersTuples)
    }
    
    public init(libraryName: String,
                            libraryVersion: String,
                            schema: HTTPProtocol = .https,
                            host: String,
                            port: Int = 443,
                            headers: [(String,String)]? = nil) {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        switch schema {
        case .https:
            client = ClientConnection.usingPlatformAppropriateTLS(for: eventLoopGroup)
                .connect(host: host,
                         port: port)
        case .http:
            let configuration = ClientConnection.Configuration
                .default(
                    target: .hostAndPort(host,
                                         port),
                    eventLoopGroup: eventLoopGroup
                )
            client = ClientConnection(configuration: configuration)
        }
        super.init()
    }
}
