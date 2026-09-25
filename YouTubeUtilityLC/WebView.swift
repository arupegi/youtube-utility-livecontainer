import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel
    @ObservedObject var settings: AppSettings

    func makeCoordinator()->Coordinator { Coordinator(model:model, settings:settings) }

    func makeUIView(context:Context)->WKWebView {
        let cfg=WKWebViewConfiguration(); cfg.allowsInlineMediaPlayback=true; cfg.mediaTypesRequiringUserActionForPlayback=[]
        let uc=WKUserContentController(); uc.add(context.coordinator,name:"traffic"); uc.add(context.coordinator,name:"playerState")
        uc.addUserScript(WKUserScript(source:Self.pageScript,injectionTime:.atDocumentStart,forMainFrameOnly:false)); cfg.userContentController=uc
        let w=WKWebView(frame:.zero,configuration:cfg); w.navigationDelegate=context.coordinator; w.uiDelegate=context.coordinator; w.allowsBackForwardNavigationGestures=true
        model.webView=w; context.coordinator.installRules(on:w)
        if let u=URL(string:model.currentURL){ w.load(URLRequest(url:u)) }
        return w
    }
    func updateUIView(_ w:WKWebView, context:Context){ context.coordinator.settings=settings; context.coordinator.installRules(on:w); context.coordinator.applyPageSettings(in:w) }



    static let pageScript = #"""
    (() => {
      function style(id, txt) {
        let s = document.getElementById(id);
        if (!s) {
          s = document.createElement('style');
          s.id = id;
          (document.head || document.documentElement).appendChild(s);
        }
        s.textContent = txt;
      }

      function currentVideo() {
        return document.querySelector('video');
      }

      function sendPlayerState() {
        const v = currentVideo();
        try {
          window.webkit?.messageHandlers?.playerState?.postMessage({
            playing: !!(v && !v.paused && !v.ended)
          });
        } catch {}
      }

      function listModeCSS() {
        return `
          /* Search / home / channel video cards -> text list */
          ytd-video-renderer,
          ytd-rich-item-renderer,
          ytd-grid-video-renderer,
          ytd-compact-video-renderer,
          ytd-playlist-video-renderer {
            display: block !important;
            margin: 0 0 10px 0 !important;
            padding: 12px 14px !important;
            background: rgba(127,127,127,0.08) !important;
            border-radius: 14px !important;
            min-height: 0 !important;
          }

          ytd-rich-grid-renderer #contents,
          ytd-section-list-renderer #contents,
          ytd-two-column-browse-results-renderer #primary {
            display: block !important;
          }

          ytd-thumbnail,
          yt-image,
          img.yt-core-image,
          .yt-core-image,
          .iv-player-content,
          .ytp-cued-thumbnail-overlay-image {
            display: none !important;
            visibility: hidden !important;
          }

          ytd-video-renderer #dismissible,
          ytd-rich-item-renderer #content,
          ytd-grid-video-renderer #dismissible,
          ytd-compact-video-renderer #dismissible,
          ytd-playlist-video-renderer #content {
            display: block !important;
            margin: 0 !important;
            padding: 0 !important;
          }

          ytd-video-renderer #details,
          ytd-rich-item-renderer #details,
          ytd-grid-video-renderer #details,
          ytd-compact-video-renderer #details,
          ytd-playlist-video-renderer #meta {
            margin: 0 !important;
            min-width: 0 !important;
          }

          ytd-video-meta-block,
          #video-title,
          #channel-name,
          #metadata-line,
          #byline-container {
            max-width: 100% !important;
          }

          #video-title,
          a#video-title {
            font-size: 15px !important;
            line-height: 1.35 !important;
            font-weight: 600 !important;
            margin: 0 0 6px 0 !important;
            white-space: normal !important;
          }

          #metadata-line,
          #metadata-line span,
          #byline-container,
          #channel-name,
          ytd-channel-name,
          ytd-channel-name a {
            font-size: 12px !important;
            line-height: 1.45 !important;
            color: rgba(127,127,127,0.95) !important;
          }

          ytd-badge-supported-renderer,
          ytd-menu-renderer,
          #menu,
          #buttons,
          .metadata-snippet-container,
          ytd-thumbnail-overlay-time-status-renderer,
          ytd-thumbnail-overlay-resume-playback-renderer,
          .badge-style-type-live-now-alternate,
          .ytd-thumbnail-overlay-time-status-renderer {
            display: none !important;
          }

          ytd-rich-grid-media,
          ytd-video-renderer,
          ytd-grid-video-renderer {
            box-shadow: none !important;
          }

          /* tighter page chrome on list pages */
          #chips-wrapper,
          ytd-feed-filter-chip-bar-renderer {
            position: sticky !important;
            top: 0 !important;
            z-index: 5 !important;
            background: inherit !important;
          }
        `;
      }

      window.__ytuApply = (c) => {
        let r = [];

        if (c.hideComments) r.push('#comments,ytd-comments,ytd-item-section-renderer[target-id="comments-section"]{display:none!important}');
        if (c.hideChat) r.push('#chat,#chat-container,ytd-live-chat-frame{display:none!important}');
        if (c.hideRelated) r.push('#related,ytd-watch-next-secondary-results-renderer{display:none!important}');
        if (c.hideThumbnails) r.push('ytd-thumbnail,yt-image,img.yt-core-image,.yt-core-image{display:none!important;visibility:hidden!important}');
        if (c.blockSeekPreview) r.push('.ytp-tooltip-bg,.ytp-tooltip-text-wrapper,.ytp-storyboard-framepreview,.ytp-preview{display:none!important}');
        if (c.audioOnly) r.push('video{opacity:0!important;background:#000!important}');
        if (c.textListMode) r.push(listModeCSS());

        style('__ytu_style', r.join('\n'));

        document.querySelectorAll('video').forEach(v => {
          try { v.disablePictureInPicture = !!c.audioOnly; } catch {}
          if (!v.__ytuBound) {
            v.__ytuBound = true;
            ['play','pause','ended','playing','waiting'].forEach(name => {
              v.addEventListener(name, sendPlayerState, {passive:true});
            });
          }
        });

        sendPlayerState();
      };

      document.addEventListener('visibilitychange', () => {
        const v = currentVideo();
        if (!v) return;

        if (document.hidden) {
          window.__ytuWasPlayingBeforeBackground = !v.paused && !v.ended;
          if (window.__ytuWasPlayingBeforeBackground) {
            Promise.resolve().then(() => v.play()).catch(() => {});
            setTimeout(() => v.play().catch(() => {}), 120);
          }
        } else if (window.__ytuWasPlayingBeforeBackground && v.paused) {
          v.play().catch(() => {});
        }

        sendPlayerState();
      }, true);

      setInterval(() => {
        try {
          const es = performance.getEntriesByType('resource');
          const o = {total:0,audio:0,video:0,image:0,other:0,count:0};

          for (const x of es) {
            const n = x.transferSize || x.encodedBodySize || 0;
            if (!n) continue;

            const u = (x.name || '').toLowerCase();
            o.total += n;
            o.count++;

            if (u.includes('googlevideo.com')) {
              if (u.includes('mime=audio') || u.includes('audio/')) o.audio += n;
              else if (u.includes('mime=video') || u.includes('video/')) o.video += n;
              else o.other += n;
            } else if (u.includes('ytimg.com') || /\.(png|jpg|jpeg|webp|gif)(\?|$)/.test(u)) {
              o.image += n;
            } else {
              o.other += n;
            }
          }

          window.webkit?.messageHandlers?.traffic?.postMessage(o);
          sendPlayerState();
        } catch {}
      }, 2000);
    })();
    """#


    final class Coordinator:NSObject,WKNavigationDelegate,WKUIDelegate,WKScriptMessageHandler {
        let model:BrowserModel; var settings:AppSettings; private var key=""
        init(model:BrowserModel,settings:AppSettings){self.model=model;self.settings=settings}
        func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
            if m.name == "playerState",
               let d = m.body as? [String: Any] {
                let playing = (d["playing"] as? Bool) ?? false
                Task { @MainActor in
                    model.isPlaying = playing
                }
                return
            }

            guard m.name == "traffic",
                  let d = m.body as? [String: Any] else { return }

            let num: (String) -> Int64 = {
                Int64((d[$0] as? NSNumber)?.int64Value ?? 0)
            }

            Task { @MainActor in
                model.traffic = TrafficSnapshot(
                    totalBytes: num("total"),
                    audioBytes: num("audio"),
                    videoBytes: num("video"),
                    imageBytes: num("image"),
                    otherBytes: num("other"),
                    sampledResources: (d["count"] as? NSNumber)?.intValue ?? 0,
                    updatedAt: Date()
                )
            }
        }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
            Task { @MainActor in
                model.currentURL = w.url?.absoluteString ?? model.currentURL
                model.address = model.currentURL
                model.title = w.title ?? "YouTube"
                model.isLoading = false
            }
            applyPageSettings(in: w)
        }
        func webView(_ w: WKWebView, didCommit n: WKNavigation!) {
            Task { @MainActor in model.isLoading = true }
            applyPageSettings(in: w)
        }
        func applyPageSettings(in w:WKWebView){
            let d:[String:Any]=["audioOnly":settings.audioOnly,"hideComments":settings.hideComments,"hideChat":settings.hideChat,"hideRelated":settings.hideRelated,"hideThumbnails":settings.hideThumbnails,"blockSeekPreview":settings.blockSeekPreview]
            guard let data=try? JSONSerialization.data(withJSONObject:d),let j=String(data:data,encoding:.utf8) else{return};w.evaluateJavaScript("window.__ytuApply&&window.__ytuApply(\(j));")
        }
        func installRules(on w:WKWebView){
            let k="\(settings.adBlock)-\(settings.audioOnly)-\(settings.blockSeekPreview)-\(settings.hideChat)";if k==key{return};key=k
            var rules:[[String:Any]]=[]
            func block(_ regex:String,_ types:[String]){rules.append(["trigger":["url-filter":regex,"resource-type":types],"action":["type":"block"]])}
            if settings.adBlock{block(".*doubleclick\\.net.*",["script","image","raw","media","document"]);block(".*googleadservices\\.com.*",["script","image","raw","media","document"]);block(".*youtube\\.com/.*(pagead|ptracking|ad_break|adunit|ad_).*",["raw","script","image","media","document"])}
            if settings.blockSeekPreview{block(".*ytimg\\.com/sb/.*",["image","raw"]);block(".*storyboard.*",["image","raw"])}
            if settings.hideChat{block(".*youtube\\.com/live_chat.*",["document","raw"]);block(".*youtube\\.com/youtubei/v1/live_chat.*",["raw"])}
            if settings.audioOnly{block(".*googlevideo\\.com/.*mime=video.*",["media","raw"]);block(".*googlevideo\\.com/.*itag=(133|134|135|136|137|138|160|242|243|244|247|248|264|266|271|272|278|298|299|302|303|308|313|315).*",["media","raw"])}
            guard let data=try? JSONSerialization.data(withJSONObject:rules),let json=String(data:data,encoding:.utf8) else{return}
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier:"YouTubeUtilityLC-\(k)",encodedContentRuleList:json){list,_ in guard let list else{return};DispatchQueue.main.async{w.configuration.userContentController.removeAllContentRuleLists();w.configuration.userContentController.add(list);w.reload()}}
        }
    }
}
