//
//  File.swift
//
//
//  Created by Eric Eng on 11/15/24.
//

import Foundation
import UIKit

private var registeredFiles: Set<String> = []
private var allFontsRegisterd: Bool = false

extension PlayRuntimeEngine {

    public static func registerAllFonts(bundle: Bundle) {
        guard !allFontsRegisterd else { return }
        bundle.paths(forResourcesOfType: nil, inDirectory: nil).forEach { cur in
            guard let pathURL = URLComponents(string: cur)?.url else { return }
            let ext = pathURL.pathExtension
            let name = pathURL.deletingPathExtension().lastPathComponent
            registerFont(bundle: bundle, fileName: name, ext: ext)
        }
        allFontsRegisterd = true
    }

    static func registerFont(bundle: Bundle, fileName: String, ext: String) {
        let fileNamee = "\(registeredFiles).\(ext)"

        guard !registeredFiles.contains(fileNamee) else { return }
        guard let assetUrl = bundle.url(forResource: fileName, withExtension: ext) else { return }

        do {
            let data = try Data(contentsOf: assetUrl)
            registerFont(withData: data, reloadDuplicates: false)
            registeredFiles.insert(fileNamee)
        } catch {
            // handle error
            //        print("🚨 [Play] Error registering font:", error)
        }
    }

    static func registerFont(withData data: Data, reloadDuplicates: Bool) {
        var errorPtr: Unmanaged<CFError>?
        guard let provider: CGDataProvider = .init(data: data as CFData),
              let cgFont: CGFont = .init(provider)
        else {
            //        print("🚨 Could not get CGFont from data")
            return
        }

        guard CTFontManagerRegisterGraphicsFont(cgFont, &errorPtr) else {
            guard let cfError = errorPtr?.takeRetainedValue() else {
                print("🚨 Unknown error. Could not get errorPtr.")
                return
            }

            guard let ctFontManagerError = CTFontManagerError(rawValue: CFErrorGetCode(cfError)) else {
                print("🚨 Could not get CFErrorCode for cfError.")
                return
            }

            // If font already registered, unregister and attempt to re-register
            let allowedErrors: [CTFontManagerError] = [.alreadyRegistered, .duplicatedName]
            if allowedErrors.contains(ctFontManagerError) {
                guard reloadDuplicates else { return }

                print("[offline-storage][register-font] Font already registered, unregistering and re-registering")

                // attempt to unregister and re-register
                guard CTFontManagerUnregisterGraphicsFont(cgFont, &errorPtr) else {
                    if let cfError = errorPtr?.takeRetainedValue() { /// tells system to release once we're out of scope
                        print("🚨 \(cfError)")
                    } else {
                        print("🚨 Unknown")
                    }
                    return
                }
                try registerFont(withData: data, reloadDuplicates: false)
            }

            // Could not register font
            print("🚨 \(cfError)")
            return

        }

        print("[offline-storage][register-font] sending notification for \(String(describing: cgFont.postScriptName))")

        NotificationCenter.default.post(.init(name: Notification.Name(kCTFontManagerRegisteredFontsChangedNotification as String), object: nil, userInfo: ["postScriptName": cgFont.postScriptName ?? ""]))
    }

}
