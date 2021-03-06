//
//  Asset.swift
//  Pods
//
//  Created by Admin on 13/11/2016.
//
//

import UIKit
import SwiftyJSON

public class OTTAssetService {

    public static func get(baseURL: String, ks: String, assetId: String, type: AssetObjectType) -> KalturaRequestBuilder? {

        if let request: KalturaRequestBuilder = KalturaRequestBuilder(url: baseURL, service: "asset", action: "get") {
            request
            .setBody(key: "id", value: JSON(assetId))
            .setBody(key: "ks", value: JSON(ks))
            .setBody(key: "type", value: JSON(type.rawValue))
            .setBody(key: "assetReferenceType", value: JSON(type.rawValue))
            .setBody(key: "with", value: JSON([["type": "files", "objectType": "KalturaCatalogWithHolder"]]))
            return request
        } else {
            return nil
        }
    }

    public static func getPlaybackContext(baseURL: String, ks: String, assetId: String, type: AssetObjectType, playbackContextOptions: PlaybackContextOptions) -> KalturaRequestBuilder? {

        if let request: KalturaRequestBuilder = KalturaRequestBuilder(url: baseURL, service: "asset", action: "getPlaybackContext") {
            request
            .setBody(key: "assetId", value: JSON(assetId))
            .setBody(key: "ks", value: JSON(ks))
            .setBody(key: "assetType", value: JSON(type.rawValue))
            .setBody(key: "contextDataParams", value: JSON(playbackContextOptions.toDictionary()))
            return request
        } else {
            return nil
        }

    }
}

public struct PlaybackContextOptions {

    public var playbackContextType: PlaybackType
    public var protocls: [String]
    public var assetFileIds: [String]?

    public init(playbackContextType:PlaybackType , protocls: [String], assetFileIds: [String]?){
        self.playbackContextType = playbackContextType
        self.protocls = protocls
        self.assetFileIds = assetFileIds
    }
    public func toDictionary() -> [String: Any] {

        var dict: [String: Any] = [:]
        dict["context"] = playbackContextType.rawValue
        dict["mediaProtocols"] = protocls
        if let fileIds = self.assetFileIds {
            dict["assetFileIds"] = fileIds.joined(separator: ",")
        }
        return dict
    }
}
