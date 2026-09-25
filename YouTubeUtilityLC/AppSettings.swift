import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @AppStorage("adBlock") var adBlock = true
    @AppStorage("audioOnly") var audioOnly = false
    @AppStorage("hideComments") var hideComments = true
    @AppStorage("hideChat") var hideChat = true
    @AppStorage("hideRelated") var hideRelated = true
    @AppStorage("hideThumbnails") var hideThumbnails = false
    @AppStorage("blockSeekPreview") var blockSeekPreview = true
    @AppStorage("downloadEndpoint") var downloadEndpoint = ""
}
