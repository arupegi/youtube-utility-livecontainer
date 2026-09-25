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



      function youtubeThemeCSS(mode) {
        const dark = `
          html, body,
          ytd-app,
          #page-manager,
          #content,
          #primary,
          #secondary,
          ytd-browse,
          ytd-search,
          ytd-watch-flexy,
          ytd-two-column-browse-results-renderer,
          ytd-two-column-search-results-renderer,
          ytd-section-list-renderer,
          ytd-rich-grid-renderer,
          tp-yt-app-drawer {
            background: #0b0b0c !important;
            color: #f5f5f7 !important;
          }

          /* top bar / masthead */
          ytd-masthead,
          #masthead-container,
          #container.ytd-masthead,
          #background.ytd-masthead {
            background: rgba(18,18,20,0.96) !important;
            color: #f5f5f7 !important;
            border-color: rgba(255,255,255,0.08) !important;
          }

          /* search box */
          ytd-searchbox,
          #container.ytd-searchbox,
          #search-form,
          #search-input,
          input#search,
          input.ytd-searchbox {
            background: #1c1c1e !important;
            color: #f5f5f7 !important;
            border-color: rgba(255,255,255,0.12) !important;
          }

          #search-icon-legacy,
          ytd-searchbox button,
          tp-yt-paper-icon-button {
            background: #2a2a2d !important;
            color: #f5f5f7 !important;
          }

          /* text */
          #video-title,
          a#video-title,
          #video-title-link,
          #channel-name,
          ytd-channel-name,
          ytd-channel-name a,
          #metadata-line,
          #metadata-line span,
          #byline-container,
          #description,
          yt-formatted-string,
          h1, h2, h3 {
            color: #f5f5f7 !important;
          }

          #metadata-line,
          #metadata-line span,
          #byline-container,
          #description,
          #subtitle,
          .metadata-snippet-text,
          #owner-sub-count {
            color: #a1a1a6 !important;
          }

          /* cards / panels */
          ytd-video-renderer,
          ytd-rich-item-renderer,
          ytd-rich-grid-media,
          ytd-grid-video-renderer,
          ytd-compact-video-renderer,
          ytd-playlist-video-renderer,
          ytd-comment-thread-renderer,
          ytd-comments,
          ytd-engagement-panel-section-list-renderer,
          ytd-menu-popup-renderer,
          tp-yt-paper-dialog,
          ytd-popup-container,
          yt-sheet-view-model {
            background: #141416 !important;
            color: #f5f5f7 !important;
            border-color: rgba(255,255,255,0.08) !important;
          }

          /* channel header / tabs */
          ytd-c4-tabbed-header-renderer,
          ytd-page-header-renderer,
          #channel-header-container,
          #tabs-container,
          #tabsContent,
          yt-tab-shape,
          tp-yt-paper-tab {
            background: #0b0b0c !important;
            color: #f5f5f7 !important;
          }

          /* chips / filter pills */
          yt-chip-cloud-chip-renderer,
          ytd-feed-filter-chip-bar-renderer,
          yt-chip-cloud-renderer,
          .ytChipShapeChip {
            background: #1f1f22 !important;
            color: #f5f5f7 !important;
            border-color: rgba(255,255,255,0.08) !important;
          }

          /* player surrounding area */
          #columns,
          #below,
          #info,
          #meta,
          ytd-watch-metadata {
            background: #0b0b0c !important;
            color: #f5f5f7 !important;
          }

          /* buttons */
          yt-button-shape button,
          ytd-button-renderer a,
          ytd-button-renderer button,
          .yt-spec-button-shape-next {
            background-color: #242427 !important;
            color: #f5f5f7 !important;
          }

          /* dividers */
          #separator,
          tp-yt-paper-listbox,
          ytd-horizontal-card-list-renderer,
          ytd-item-section-renderer {
            border-color: rgba(255,255,255,0.08) !important;
          }

          /* scrollbars */
          ::-webkit-scrollbar {
            width: 10px;
            height: 10px;
          }
          ::-webkit-scrollbar-track {
            background: #0b0b0c;
          }
          ::-webkit-scrollbar-thumb {
            background: #3a3a3c;
            border-radius: 999px;
            border: 2px solid #0b0b0c;
          }

          /* remove light flashes */
          html {
            color-scheme: dark !important;
            background-color: #0b0b0c !important;
          }
        `;

        const light = `
          html, body,
          ytd-app,
          #page-manager,
          #content,
          #primary,
          #secondary,
          ytd-browse,
          ytd-search,
          ytd-watch-flexy,
          ytd-two-column-browse-results-renderer,
          ytd-two-column-search-results-renderer,
          ytd-section-list-renderer,
          ytd-rich-grid-renderer {
            background: #ffffff !important;
            color: #111111 !important;
          }

          html {
            color-scheme: light !important;
            background-color: #ffffff !important;
          }

          ytd-masthead,
          #masthead-container,
          #container.ytd-masthead,
          #background.ytd-masthead {
            background: rgba(255,255,255,0.96) !important;
            color: #111111 !important;
          }

          ytd-searchbox,
          #container.ytd-searchbox,
          #search-form,
          #search-input,
          input#search,
          input.ytd-searchbox {
            background: #f5f5f7 !important;
            color: #111111 !important;
            border-color: rgba(0,0,0,0.12) !important;
          }
        `;

        if (mode === 'dark') return dark;
        if (mode === 'light') return light;

        return `
          @media (prefers-color-scheme: dark) {
            ${dark}
          }
          @media (prefers-color-scheme: light) {
            ${light}
          }
        `;
      }

      function listModeCSS() {
        return `
          /* ===== Text-first list mode ===== */

          /* Search results and normal video cards */
          ytd-video-renderer,
          ytd-compact-video-renderer,
          ytd-playlist-video-renderer,
          ytd-grid-video-renderer,
          ytd-rich-item-renderer,
          ytd-rich-grid-media {
            display: block !important;
            width: 100% !important;
            max-width: none !important;
            margin: 0 0 8px 0 !important;
            padding: 11px 14px !important;
            box-sizing: border-box !important;
            background: rgba(127,127,127,0.075) !important;
            border-radius: 13px !important;
            min-height: 0 !important;
          }

          /* Desktop channel page / Videos tab rich grid */
          ytd-rich-grid-renderer,
          ytd-rich-grid-row,
          #contents.ytd-rich-grid-renderer,
          ytd-two-column-browse-results-renderer #primary,
          ytd-section-list-renderer #contents {
            display: block !important;
            width: 100% !important;
            max-width: none !important;
          }

          ytd-rich-grid-renderer #contents {
            margin: 0 !important;
            padding: 8px 12px !important;
          }

          ytd-rich-grid-row #contents {
            display: block !important;
            width: 100% !important;
          }

          ytd-rich-item-renderer {
            --ytd-rich-grid-item-max-width: none !important;
            --ytd-rich-grid-item-min-width: 0 !important;
          }

          /* Remove thumbnail columns entirely instead of leaving blank space */
          ytd-thumbnail,
          yt-image,
          img.yt-core-image,
          .yt-core-image,
          #thumbnail,
          #thumbnail-container,
          .thumbnail-container,
          .ytd-thumbnail,
          .iv-player-content,
          .ytp-cued-thumbnail-overlay-image {
            display: none !important;
            visibility: hidden !important;
            width: 0 !important;
            height: 0 !important;
            min-width: 0 !important;
            min-height: 0 !important;
            margin: 0 !important;
            padding: 0 !important;
          }

          ytd-video-renderer #dismissible,
          ytd-grid-video-renderer #dismissible,
          ytd-compact-video-renderer #dismissible,
          ytd-playlist-video-renderer #content,
          ytd-rich-item-renderer #content,
          ytd-rich-grid-media #content {
            display: block !important;
            width: 100% !important;
            margin: 0 !important;
            padding: 0 !important;
          }

          ytd-video-renderer #details,
          ytd-grid-video-renderer #details,
          ytd-compact-video-renderer #details,
          ytd-playlist-video-renderer #meta,
          ytd-rich-grid-media #details,
          ytd-rich-item-renderer #details {
            display: block !important;
            width: 100% !important;
            max-width: none !important;
            min-width: 0 !important;
            margin: 0 !important;
            padding: 0 !important;
          }

          #video-title,
          a#video-title,
          #video-title-link {
            display: block !important;
            font-size: 15px !important;
            line-height: 1.38 !important;
            font-weight: 650 !important;
            margin: 0 0 5px 0 !important;
            white-space: normal !important;
            max-height: none !important;
            overflow: visible !important;
          }

          ytd-video-meta-block,
          #metadata,
          #metadata-line,
          #byline-container,
          #channel-name,
          ytd-channel-name,
          ytd-channel-name a {
            max-width: 100% !important;
            font-size: 12px !important;
            line-height: 1.45 !important;
            color: rgba(127,127,127,0.95) !important;
          }

          /* remove visual clutter from cards */
          ytd-badge-supported-renderer,
          ytd-menu-renderer,
          #menu,
          #buttons,
          .metadata-snippet-container,
          ytd-thumbnail-overlay-time-status-renderer,
          ytd-thumbnail-overlay-resume-playback-renderer {
            display: none !important;
          }

          /* Channel page header remains usable but tighter */
          ytd-c4-tabbed-header-renderer,
          ytd-page-header-renderer,
          #channel-header-container {
            margin-bottom: 6px !important;
          }

          /* Keep horizontal channel tabs scrollable */
          #tabsContent,
          yt-tab-shape,
          tp-yt-paper-tab {
            min-height: 38px !important;
          }

          /* Avoid grid gaps on desktop */
          ytd-rich-grid-renderer #contents > *,
          ytd-rich-grid-row #contents > * {
            width: 100% !important;
            max-width: none !important;
          }

          /* Search filter bar stays available */
          #chips-wrapper,
          ytd-feed-filter-chip-bar-renderer {
            position: sticky !important;
            top: 0 !important;
            z-index: 5 !important;
            background: inherit !important;
          }
        `;
      }

      function cleanupSpecialShelves(c) {
        if (c.hideShorts) {
          document.querySelectorAll(`
            ytd-reel-shelf-renderer,
            ytd-rich-shelf-renderer[is-shorts],
            ytd-rich-section-renderer:has(ytd-reel-shelf-renderer),
            ytd-video-renderer a[href*="/shorts/"],
            ytd-rich-item-renderer a[href*="/shorts/"],
            ytd-grid-video-renderer a[href*="/shorts/"],
            ytd-guide-entry-renderer a[href="/shorts"],
            yt-tab-shape[tab-title*="Shorts"],
            tp-yt-paper-tab:has(a[href*="/shorts"])
          `).forEach(el => {
            const card = el.closest('ytd-rich-item-renderer,ytd-grid-video-renderer,ytd-video-renderer,ytd-rich-section-renderer,ytd-reel-shelf-renderer,yt-tab-shape,tp-yt-paper-tab') || el;
            card.style.setProperty('display', 'none', 'important');
          });
        }

        if (c.hideMixes) {
          document.querySelectorAll(`
            ytd-radio-renderer,
            ytd-compact-radio-renderer,
            ytd-playlist-renderer,
            ytd-compact-playlist-renderer,
            ytd-rich-item-renderer,
            ytd-grid-playlist-renderer
          `).forEach(el => {
            const txt = (el.innerText || '').toLowerCase();
            const hrefs = Array.from(el.querySelectorAll('a')).map(a => a.href || '').join(' ');
            const isMix =
              txt.includes('mix') ||
              txt.includes('ミックス') ||
              hrefs.includes('list=RD') ||
              hrefs.includes('start_radio=1');

            if (isMix) {
              el.style.setProperty('display', 'none', 'important');
            }
          });
        }
      }

      window.__ytuApply = (c) => {
        window.__ytuLastConfig = c;
        let r = [];

        if (c.hideComments) r.push('#comments,ytd-comments,ytd-item-section-renderer[target-id="comments-section"]{display:none!important}');
        if (c.hideChat) r.push('#chat,#chat-container,ytd-live-chat-frame{display:none!important}');
        if (c.hideRelated) r.push('#related,ytd-watch-next-secondary-results-renderer{display:none!important}');
        if (c.hideThumbnails) r.push('ytd-thumbnail,yt-image,img.yt-core-image,.yt-core-image{display:none!important;visibility:hidden!important}');
        if (c.blockSeekPreview) r.push('.ytp-tooltip-bg,.ytp-tooltip-text-wrapper,.ytp-storyboard-framepreview,.ytp-preview{display:none!important}');
        if (c.audioOnly) r.push('video{opacity:0!important;background:#000!important}');
        if (c.textListMode) r.push(listModeCSS());
        if (c.syncYouTubeTheme) r.push(youtubeThemeCSS(c.appearanceMode || 'system'));

        if (c.hideShorts) {
          r.push(`
            ytd-reel-shelf-renderer,
            ytd-rich-shelf-renderer[is-shorts],
            a[href="/shorts"],
            ytd-guide-entry-renderer a[href="/shorts"] {
              display:none!important;
            }
          `);
        }

        style('__ytu_style', r.join('\n'));
        cleanupSpecialShelves(c);

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

          if (window.__ytuLastConfig) {
            cleanupSpecialShelves(window.__ytuLastConfig);
          }
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
