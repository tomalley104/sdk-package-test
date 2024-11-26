//
//  File.swift
//  
//
//  Created by Eric Eng on 11/4/24.
//

import Foundation

extension PlayRuntimeEngine {
    public enum BuildErrors: Error {
        case notFound
        case invalidType
        case couldNotCreateView
        case missingProject
    }
}
