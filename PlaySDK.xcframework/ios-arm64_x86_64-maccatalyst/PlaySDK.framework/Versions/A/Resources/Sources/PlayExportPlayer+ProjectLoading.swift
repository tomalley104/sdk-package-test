//
//  File.swift
//  
//
//  Created by Eric Eng on 11/4/24.
//

import Foundation
import UIKit

#if !SWIFT_PACKAGE
@_implementationOnly import PlayNodes
#else
import PlayNodes
#endif

extension PlayRuntimeEngine {

    public static func loadingProjectJSON(bundle: Bundle, resource: String, ext: String,
                                          colors: [String : UIColor],
                                          gradients: [String : PlayGradient],
                                          typography: [String : PlayTypography],
                                          spacing: [String : CGFloat],
                                          radius: [String : CGFloat]) throws -> PlayRuntimeEngine {
        do {
            let project = try PlayRuntimeEngine.loadProject(bundle: bundle, resource: resource, ext: ext)
            
            /// Load runtime foundations
            colors.forEach { PlayRuntimeEngine.loadColor(into: project, id: $0.key, value: $0.value) }

            gradients.forEach { PlayRuntimeEngine.loadGradient(into: project, id: $0.key, value: $0.value) }

            typography.forEach { PlayRuntimeEngine.loadTypography(into: project, id: $0.key, value: $0.value) }

            spacing.forEach { PlayRuntimeEngine.loadSpacing(into: project, id: $0.key, value: $0.value) }

            radius.forEach { PlayRuntimeEngine.loadRadius(into: project, id: $0.key, value: $0.value) }
            
            return try PlayRuntimeEngine(project: project)
        } catch {
            print("⚠️ Play Runtime Engine :: Could not load project file", error)
            throw error
        }
    }

    static func loadProject(bundle: Bundle, resource: String, ext: String) throws -> ProjectModel {
        guard let projectUrl = bundle.url(forResource: resource, withExtension: ext) else {
            throw BuildErrors.missingProject
        }

        do {
            let data = try Data(contentsOf: projectUrl)
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: [])
            if let jsonResult = jsonResult as? Dictionary<String, Any> {
                let newProject = ProjectModel()
                newProject.syncAll(jsonResult)
                return newProject
            }
            throw BuildErrors.invalidType

        } catch {
            // handle error
            print("🚨 [Play] Load Project Error:", error)
            throw BuildErrors.invalidType
        }
    }

    static func loadColor(into model: ProjectModel, id: String, value: UIColor) {
        guard let curFound = model.foundation.getColorById(id) else { return }
        curFound.setValue(StyleFill(color: value))
        return
    }

    static func loadGradient(into model: ProjectModel, id: String, value: PlayGradient) {
        guard let curFound = model.foundation.getGradientById(id) else { return }
        curFound.styleFill.gradient = value._styleGradient
        return
    }

    static func loadTypography(into model: ProjectModel, id: String, value: PlayTypography) {
        guard let curFound = model.foundation.getTypographyById(id) else { return }
        curFound.typography = value._typographyModel
        return
    }

    static func loadRadius(into model: ProjectModel, id: String, value: CGFloat) {
        guard let curFound = model.foundation.getCornerRadiusById(id) else { return }
        curFound.setValue(StyleFloat(value))
        return
    }

    static func loadSpacing(into model: ProjectModel, id: String, value: CGFloat) {
        guard let curFound = model.foundation.getSpacingById(id) else { return }
        curFound.setValue(StyleFloat(value))
        return
    }
}

// NOTE: Maybe move this to the PlayNodes package in the future
extension ProjectModel {
    func syncAll(_ dictionary: [String: Any]) {
        if let mediaRaw = dictionary["media"] as? [String: Any] {
            mediaRaw.forEach { key, val in
                guard var dictionary = val as? [String: Any],
                      let typeRaw = dictionary["type"] as? String
                else { return }
                // TODO: Remove this later. right now we do this so initial load will create the model since the current logic
                // is for already loaded projects, and updates are blocked if the model does not exist in the project
                if dictionary[ModelFieldValue.crudKey] == nil {
                    dictionary[ModelFieldValue.crudKey] = ModelFieldValue.crudValCreate
                }
                
                switch typeRaw {
                case AssetType.image.rawValue:
                    syncImageAssets([key: dictionary])
                case AssetType.video.rawValue:
                    syncVideoAssets([key: dictionary])
                case AssetType.rive.rawValue:
                    syncRiveAssets([key: dictionary])
                case AssetType.svg.rawValue:
                    syncSVGAssets([key: dictionary])
                case AssetType.font.rawValue:
                    syncFontAssets([key: dictionary])
                default:
                    break
                }
            }
        }
        
        if let raw = dictionary["nodes"] as? [String: Any] {
            syncNodeModels(raw)
        }
        if let raw = dictionary["stylesheets"] as? [String: Any] {
            syncSheets(raw)
        }
        
        if let raw = dictionary["project"] as? [String: Any] {
            syncProjectModelUpdateData(raw)
        }
        
        guard let foundationDict = dictionary["foundation"] as? [String: Any] else { return }
        if let raw = foundationDict["spacing"] as? [String: AnyHashable] {
            syncFoundation(type: .spacing, data: raw)
        }
        if let raw = foundationDict["cornerRadius"] as? [String: AnyHashable] {
            syncFoundation(type: .cornerRadius, data: raw)
        }
        if let raw = foundationDict["colors"] as? [String: AnyHashable] {
            syncFoundation(type: .color, data: raw)
        }
        if let raw = foundationDict["gradients"] as? [String: AnyHashable] {
            syncFoundation(type: .gradient, data: raw)
        }
        if let raw = foundationDict["typography"] as? [String: AnyHashable] {
            syncFoundation(type: .typography, data: raw)
        }
        //        if let raw = foundationDict[DesignSystemFoundationType.shadow.rawValue] as? [String: AnyHashable] {
        //            syncFoundation(type: .shadow, data: raw)
        //        }
    }
    
    private func syncSheets(_ dictionary: [String: Any]) {
        dictionary.forEach { (id, data) in
            guard let data = data as? [String: Any] else { return }
            // If its a null value then remove it from the project
            if let crudVal = data[ModelFieldValue.crudKey] as? String,
               crudVal == ModelFieldValue.crudValDelete
            {
                self.stylesheets.removeValue(forKey: id)
            } else {
                var data = data
                
                // Sanitize special values
                data.forEach { field, val in
                    if let val = val as? [String: String], val == ModelFieldValue.EmptyArray {
                        data[field] = [] as [AnyHashable]
                    }
                }
                
                let sheet = self.stylesheets[id] ?? StyleSheet()
                sheet.id = id
                sheet.loadFromDictionary(data as [String: Any], merge: true)
                self.stylesheets[id] = sheet
            }
        }
    }
    
    func syncNodeModels(_ dictionary: [String: Any]) {
        dictionary.forEach { id, data in
            guard let data = data as? [String: Any] else { return }
            if let crudVal = data[ModelFieldValue.crudKey] as? String,
               crudVal == ModelFieldValue.crudValDelete
            {
                if let node: NodeModel = removeNode(id) {
                    node.removeFromParent()
                }
                return
            }
            let nodeModel: NodeModel = nodes[id] ?? .init(type: .container)
            nodeModel.id = id
            addNode(nodeModel)
            nodeModel.loadFromDictionary(data, repo: self)
        }
    }
    
    func syncFoundation(type: DesignSystemFoundationType, data: [String: AnyHashable]) {
        data.forEach { id, data in
            guard let data = data as? [String: Any] else { return }
            
            // If its a null value then remove it from the project
            if let crudVal = data[ModelFieldValue.crudKey] as? String,
               crudVal == ModelFieldValue.crudValDelete
            {
                self.foundation.removeFoundation(type: type, id: id)
                
            } else if let data = data as? [String: AnyHashable] {
                var doInsert: Bool = true
                let foundation: BaseFoundation
                let eventData: ProjectFoundationModelEvent
                
                if let existing: BaseFoundation = self.getFoundation(type: type, id: id) {
                    let currentIndex = existing.childIndex
                    foundation = existing
                    foundation.loadFromDictionary(data)
                    if currentIndex == foundation.childIndex {
                        doInsert = false
                    }
                    eventData = .init(id: id, foundationType: existing.type, action: .update)
                } else {
                    foundation = type.modelClassType.init(data)
                    foundation.id = id
                    eventData = .init(id: id, foundationType: foundation.type, action: .create)
                }
                
                if doInsert {
                    self.foundation.addFoundationByChildIndex(foundation)
                }
                
                // Publish event
                self.foundation.eventPublisher = eventData
            }
        }
    }
    
    func syncProjectModelUpdateData(_ dictionary: [String: Any]) {
        if let value = dictionary[ProjectModelUpdateId.events.rawValue] as? [String: Any] {
            let events: [String: Interaction.Event] = value.compactMapValues { eventDict in
                guard let dict: [String: AnyHashable] = eventDict as? [String: AnyHashable] else { return nil }
                return .init(dictionary: dict)
            }
            self.updateEventListenerData(updatedValue: events)
        }
        
        if let value = dictionary[ProjectModelUpdateId.tabBarData.rawValue] as? [String: Any] {
            let tabBarData: ProjectModel.GlobalTabBarData = .init()
            tabBarData.loadFromDictionary(value)
            self.updateTabBarData(updatedValue: tabBarData)
        }
        
        if let value = dictionary[ProjectModelUpdateId.initialPageId.rawValue] as? String {
            self.setInitialPageId(value, sendUpdateViaSubject: true)
        }
        
        if let value = dictionary[ProjectModelUpdateId.variables.rawValue] as? [String: Any] {
            self.variables.loadFromDictionary(value)
        }
        
        if let value = dictionary[ProjectModelUpdateId.prefabTriggers.rawValue] as? [String: Any] {
            self.prefabTriggers.loadFromDictionary(value, repo: self)
        }
    }
    
    // MARK: Image Assets
    private func syncImageAssets(_ dictionary: [String: Any]) {
        
        dictionary.forEach { key, value in
            guard let value = value as? [String: AnyHashable] else { return }
            
            do {
                var asset: ImageAssetModel? = self.getAsset(type: .image, id: key) as? ImageAssetModel
                
                /// Delete
                if asset != nil,
                   let crudVal = value[ModelFieldValue.crudKey] as? String,
                   crudVal == ModelFieldValue.crudValDelete
                {
                    self.removeAsset(type: .image, id: key)
                    return
                }
                
                // create
                if let crudAction = value[ModelFieldValue.crudKey] as? String {
                    
                    if crudAction ==  ModelFieldValue.crudValCreate {
                        print("[RTDB] 🚀 syncStateToModels - create image asset model \(key)")
                        asset = try ImageAssetModel.from(json: value)
                        if let asset = asset {
                            self.addAsset(type: .image, model: asset)
                        }
                    }
                    
                    if crudAction == ModelFieldValue.crudValDelete {
                        self.removeAsset(type: .image, id: key)
                    }
                }
                
                else if asset == nil {
                    print("[RTDB] 🚨 syncStateToModels - cant find image asset model \(key)")
                    return
                }
                
                
                // update
                else if let imageAsset = asset {
                    // Update
                    // TODO: rework "created" asset to auto set id. We shouldn't need to set this id here. Should init from URL if available.
                    imageAsset.id = key
                    
                    // let updateMessage = RTMessage.ImageAssetUpdateMessagePayload(fromDictionary: value)
                    
                    
                    // state
                    if let state: String = value["state"] as? String, let validState = AssetState(rawValue: state) {
                        imageAsset.state = validState
                    }
                    
                    if let urlString = value["url"] as? String, let url = URL(string: urlString) {
                        // note: matches raw size in available sizes
                        imageAsset.url = url
                    }
                    
                    // meta
                    if let meta = value["meta"] as? [String: AnyHashable] {
                        if let aspectRatio = meta["aspectRatio"] as? CGFloat {
                            imageAsset.meta.aspectRatio = aspectRatio
                        }
                        
                        if let availableSizesData = meta["availableSizes"] as? [String: AnyHashable],
                           let availableSizesObject = try? ImagePathSet.from(json: availableSizesData) {
                            imageAsset.meta.availableSizes = .merging(imageAsset.meta.availableSizes, availableSizesObject)
                            
                            if let rawURL = availableSizesObject.compressed?.url {
                                imageAsset.url = rawURL
                            }
                        }
                    }
                    
                    self.addAsset(type: .image, model: imageAsset)
                    
                }
                
            } catch {
                print("[RTDB] 🚨 syncStateToModels - cant sync image asset model \(key) - \(error)")
            }
        }
    }
    
    // MARK: Video Assets
    private func syncVideoAssets(_ dictionary: [String: Any]) {
        
        dictionary.forEach { key, value in
            guard let value = value as? [String: AnyHashable] else { return }
            
            do {
                var asset: VideoAssetModel? = self.videoAssets[key]
                
                /// Delete
                if asset != nil,
                   let crudVal = value[ModelFieldValue.crudKey] as? String,
                   crudVal == ModelFieldValue.crudValDelete
                {
                    self.removeAsset(type: .video, id: key)
                    return
                }
                
                // create
                if let crudAction = value[ModelFieldValue.crudKey] as? String {
                    
                    if crudAction ==  ModelFieldValue.crudValCreate {
                        print("[RTDB] 🚀 syncStateToModels - create image asset model \(key)")
                        asset = try VideoAssetModel.from(json: value)
                        if let asset = asset {
                            self.addAsset(type: .video, model: asset)
                        }
                        
                    }
                    
                    if crudAction == ModelFieldValue.crudValDelete {
                        self.removeAsset(type: .video, id: key)
                    }
                }
                
                else if asset == nil {
                    print("[RTDB] 🚨 syncStateToModels - cant find image asset model \(key)")
                    return
                }
                
                // TODO: Add CRUD FOR UPDATE VIDEO!
                
            } catch {
                print("[RTDB] 🚨 syncStateToModels - cant sync image asset model \(key) - \(error)")
            }
        }
    }
    
    // MARK: Rive Assets
    private func syncRiveAssets(_ dictionary: [String: Any]) {
        
        dictionary.forEach { key, value in
            guard let value = value as? [String: AnyHashable] else { return }
            
            do {
                var asset: RiveAssetModel? = self.riveAssets[key]
                
                /// Delete
                if asset != nil,
                   let crudVal = value[ModelFieldValue.crudKey] as? String,
                   crudVal == ModelFieldValue.crudValDelete
                {
                    self.removeAsset(type: .rive, id: key)
                    return
                }
                
                // create
                if let crudAction = value[ModelFieldValue.crudKey] as? String {
                    
                    if crudAction ==  ModelFieldValue.crudValCreate {
                        print("[RTDB] 🚀 syncStateToModels - create rive asset model \(key)")
                        asset = try RiveAssetModel.from(json: value)
                        if let asset = asset {
                            self.addAsset(type: .rive, model: asset)
                        }
                        
                    }
                    
                    if crudAction == ModelFieldValue.crudValDelete {
                        self.removeAsset(type: .rive, id: key)
                    }
                }
                
                else if asset == nil {
                    print("[RTDB] 🚨 syncStateToModels - cant find rive asset model \(key)")
                    return
                }
                
                // TODO: Add CRUD FOR UPDATE RIVE!
                
            } catch {
                print("[RTDB] 🚨 syncStateToModels - cant sync rive asset model \(key) - \(error)")
            }
        }
    }
    
    // MARK: SVG Assets
    private func syncSVGAssets(_ dictionary: [String: Any]) {
        
        dictionary.forEach { key, value in
            guard let value = value as? [String: AnyHashable] else { return }
            do {
                var asset: SVGAssetModel? = self.svgAssets[key]
                
                /// Delete
                if asset != nil, let nullVal = value as? [String: String],
                   let crudVal = value[ModelFieldValue.crudKey] as? String,
                   crudVal == ModelFieldValue.crudValDelete
                {
                    self.removeAsset(type: .svg, id: key)
                    return
                }
                
                // create
                if let crudAction = value[ModelFieldValue.crudKey] as? String {
                    
                    if crudAction ==  ModelFieldValue.crudValCreate {
                        print("[RTDB] 🚀 syncStateToModels - create svg asset model \(key)")
                        asset = try SVGAssetModel.from(json: value)
                        if let asset = asset {
                            self.addAsset(type: .svg, model: asset)
                        }
                        
                    }
                    
                    if crudAction == ModelFieldValue.crudValDelete {
                        self.removeAsset(type: .svg, id: key)
                    }
                }
                else if asset == nil {
                    print("[RTDB] 🚨 syncStateToModels - cant find svg asset model \(key)")
                    return
                }
            } catch {
                print("[RTDB] 🚨 syncStateToModels - cant sync svg asset model \(key) - \(error)")
            }
        }
    }
    
    // MARK: Font assets
    private func syncFontAssets(_ dictionary: [String: Any]) {
        
        dictionary.forEach { key, value in
            guard let value = value as? [String: AnyHashable] else { return }
            do {
                var asset: FontAssetModel? = self.fontAssets[key]
                
                // Delete
                if let crudVal = value[ModelFieldValue.crudKey] as? String,
                   crudVal == ModelFieldValue.crudValDelete
                {
                    self.removeAsset(type: .font, id: key)
                }
                
                // Create
                if let crudAction = value[ModelFieldValue.crudKey] as? String {
                    
                    if crudAction == ModelFieldValue.crudValCreate {
                        print("[RTDB] 🚀 syncStateToModels - create image asset model \(key)")
                        asset = try FontAssetModel.from(json: value)
                        if let asset = asset {
                            self.addAsset(type: .font, model: asset)
                        }
                    }
                    
                    if crudAction == ModelFieldValue.crudValDelete {
                        self.removeAsset(type: .font, id: key)
                    }
                }
                else if asset == nil {
                    print("[RTDB] 🚨 syncStateToModels - cant find font asset model \(key)")
                    return
                }
                // Update
                else if let fontAsset = asset {
                    
                    // TODO: rework "created" asset to auto set id. We shouldn't need to set this id here. Should init from URL if available.
                    fontAsset.id = key
                    
                    // state
                    if let state: String = value["state"] as? String, let validState = AssetState(rawValue: state) {
                        fontAsset.state = validState
                    }
                    
                    if let urlString = value["url"] as? String, let url = URL(string: urlString) {
                        fontAsset.url = url
                        
                        // TODO: update raw size in available sizes
                        
                    }
                    
                    // meta
                    if let meta = value["meta"] as? [String: AnyHashable] {
                        if let fontFamily = meta["fontFamily"] as? String {
                            fontAsset.meta.fontFamily = fontFamily
                        }
                        
                        if let fontSubFamily = meta["fontSubFamily"] as? String {
                            fontAsset.meta.fontSubFamily = fontSubFamily
                        }
                        
                        if let preferredFamily = meta["preferredFamily"] as? String {
                            fontAsset.meta.preferredFamily = preferredFamily
                        }
                        
                        if let preferredSubFamily = meta["preferredSubFamily"] as? String {
                            fontAsset.meta.preferredSubFamily = preferredSubFamily
                        }
                        
                        if let postScriptName = meta["postScriptName"] as? String {
                            fontAsset.meta.postScriptName = postScriptName
                        }
                        
                        if let fileExtension = meta["fileExtension"] as? String {
                            fontAsset.meta.fileExtension = fileExtension
                        }
                    }
                    
                    self.addAsset(type: .font, model: fontAsset)
                    
                } else {
                    print("[RTDB] 🚨 syncStateToModels - cant find font asset model \(key)")
                }
            } catch {
                print("[RTDB] 🚨 syncStateToModels - cant sync font asset model \(key) - \(error)")
            }
        }
    }
    
    private func syncVariables(_ dictionary: [String: Any]) {
        variables.loadFromDictionary(dictionary)
    }
}

enum ProjectModelUpdateId: String {
    case events
    case tabBarData
    case initialPageId
    case variables
    case prefabTriggers
    case prefabActions
}
