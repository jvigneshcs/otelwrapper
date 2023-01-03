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
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporter

public typealias HTTPProtocol = HTTP2FramePayloadToHTTP1ClientCodec.HTTPProtocol

@objc
public class WrapperAPI: NSObject {
    
    private let tracer: TracerSdk
    
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
    
    public convenience init(libraryName: String,
                            libraryVersion: String,
                            schema: HTTPProtocol = .https,
                            host: String,
                            port: Int = 443,
                            headers: [(String,String)]? = nil) {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let client: ClientConnection
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
        self.init(libraryName: libraryName,
                  libraryVersion: libraryVersion,
                  client: client,
                  headers: headers)
    }
    
    public convenience init(libraryName: String,
                            libraryVersion: String,
                            client: ClientConnection,
                            headers: [(String,String)]? = nil) {
        let configuration = OtlpConfiguration(headers: headers)
        self.init(libraryName: libraryName,
                  libraryVersion: libraryVersion,
                  client: client,
                  configuration: configuration)
    }
    
    private init(libraryName: String,
                 libraryVersion: String,
                 client: ClientConnection,
                 configuration: OtlpConfiguration) {
        tracer = OpenTelemetrySDK.instance
            .tracerProvider
            .get(instrumentationName: libraryName,
                 instrumentationVersion: libraryVersion) as! TracerSdk
        let traceExporter = OtlpTraceExporter(channel: client,
                                              config: configuration)
        let spanProcessor = SimpleSpanProcessor(spanExporter: traceExporter)
        OpenTelemetrySDK.instance
            .tracerProvider
            .addSpanProcessor(spanProcessor)
        super.init()
    }
    
    @objc
    public func send(event: String,
                     attributes: [String: Any],
                     time: Date) {
        let filtered = attributes.compactMapValues(AttributeValue.init)
        let span = tracer.spanBuilder(spanName: event)
            .setSpanKind(spanKind: .client)
            .setStartTime(time: time)
            .startSpan()
        for (key, value) in filtered {
            span.setAttribute(key: key,
                              value: value)
        }
        span.end()
    }
}
