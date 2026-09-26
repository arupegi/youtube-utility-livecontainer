import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @AppStorage("minimalBandwidthMode") var minimalBandwidthMode = false
    @AppStorage("allowFullscreen") var allowFullscreen = true
    @AppStorage("allowPiP") var allowPiP = true
    @AppStorage("syncYouTubeTheme") var syncYouTubeTheme = true
    @AppStorage("hideShorts") var hideShorts = true
    @AppStorage("hideMixes") var hideMixes = true
    @AppStorage("blockImages") var blockImages = true
    @AppStorage("textListMode") var textListMode = true
    @AppStorage("themeColorHex") var themeColorHex = "#FF3B30"
    @AppStorage("appearanceMode") var appearanceMode = "system"
    @AppStorage("adBlock") var adBlock = true
    @AppStorage("audioOnly") var audioOnly = false
    @AppStorage("hideComments") var hideComments = true
    @AppStorage("hideChat") var hideChat = true
    @AppStorage("hideRelated") var hideRelated = true
    @AppStorage("hideThumbnails") var hideThumbnails = false
    @AppStorage("blockSeekPreview") var blockSeekPreview = true
    @AppStorage("downloadEndpoint") var downloadEndpoint = ""


    var themeColor: Color {
        Color(hex: themeColorHex)
    }

    var themeColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: self.themeColorHex) },
            set: { self.themeColorHex = $0.toHex() }
        )
    }


    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

}
