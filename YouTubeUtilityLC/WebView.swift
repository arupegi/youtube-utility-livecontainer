import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel
    @ObservedObject var settings: AppSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model, settings: settings)
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.allowsPictureInPictureMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []

        let uc = WKUserContentController()
        uc.add(context.coordinator, name: "traffic")
        uc.add(context.coordinator, name: "playerState")

        // Apply theme at document start to avoid YouTube painting a white page first.
        let bootstrap = Self.bootstrapScript(
            syncTheme: settings.syncYouTubeTheme,
            appearance: settings.appearanceMode
        )
        uc.addUserScript(
            WKUserScript(
                source: bootstrap,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        uc.addUserScript(
            WKUserScript(
                source: Self.pageScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        cfg.userContentController = uc

        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = context.coordinator
        w.uiDelegate = context.coordinator
        w.allowsBackForwardNavigationGestures = true
        w.isOpaque = true
        let darkNow: Bool
        switch settings.appearanceMode {
        case "dark":
            darkNow = true
        case "light":
            darkNow = false
        default:
            darkNow = UITraitCollection.current.userInterfaceStyle == .dark
        }
        let pageBackground = darkNow
            ? UIColor(red: 15/255, green: 15/255, blue: 15/255, alpha: 1)
            : UIColor.white
        w.backgroundColor = pageBackground
        w.scrollView.backgroundColor = pageBackground

        model.webView = w
        context.coordinator.installRules(on: w)

        if let u = URL(string: model.currentURL) {
            w.load(URLRequest(url: u))
        }
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {
        context.coordinator.settings = settings

        let darkNow: Bool
        switch settings.appearanceMode {
        case "dark":
            darkNow = true
        case "light":
            darkNow = false
        default:
            darkNow = UITraitCollection.current.userInterfaceStyle == .dark
        }

        let pageBackground = darkNow
            ? UIColor(red: 15/255, green: 15/255, blue: 15/255, alpha: 1)
            : UIColor.white

        if w.backgroundColor != pageBackground {
            w.backgroundColor = pageBackground
            w.scrollView.backgroundColor = pageBackground
        }

        context.coordinator.installRules(on: w)
        context.coordinator.applyPageSettings(in: w)
    }

    static func bootstrapScript(syncTheme: Bool, appearance: String) -> String {
        guard syncTheme else { return "" }

        let escaped = appearance.replacingOccurrences(of: "'", with: "")
        return """
        (() => {
          const requested = '\(escaped)';
          const wantsDark = requested === 'dark' ||
            (requested === 'system' && window.matchMedia &&
             window.matchMedia('(prefers-color-scheme: dark)').matches);

          window.__ytuBootstrapDark = wantsDark;

          const applyEarly = () => {
            const root = document.documentElement;
            if (!root) return;

            if (wantsDark) {
              root.setAttribute('dark', '');
              root.setAttribute('darker-dark-theme', '');
              root.style.setProperty('color-scheme', 'dark', 'important');
              root.style.setProperty('--yt-spec-base-background', '#0f0f0f', 'important');
              root.style.setProperty('--yt-spec-raised-background', '#212121', 'important');
              root.style.setProperty('--yt-spec-menu-background', '#282828', 'important');
              root.style.setProperty('--yt-spec-text-primary', '#f1f1f1', 'important');
              root.style.setProperty('--yt-spec-text-secondary', '#aaaaaa', 'important');
            } else {
              root.removeAttribute('dark');
              root.removeAttribute('darker-dark-theme');
              root.style.setProperty('color-scheme', 'light', 'important');
            }
          };

          // Apply once at document start. Do NOT observe root.style here:
          // observing and writing the same style attribute can create an
          // infinite MutationObserver loop and prevent YouTube from rendering.
          applyEarly();

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', applyEarly, { once: true });
          } else {
            applyEarly();
          }
        })();
        """
    }

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

      function shouldUseDark(mode) {
        if (mode === 'dark') return true;
        if (mode === 'light') return false;
        try {
          return window.matchMedia('(prefers-color-scheme: dark)').matches;
        } catch {
          return !!window.__ytuBootstrapDark;
        }
      }

      function forceYouTubeTheme(c) {
        if (!c.syncYouTubeTheme) return;

        const dark = shouldUseDark(c.appearanceMode || 'system');
        const root = document.documentElement;
        const body = document.body;
        const app = document.querySelector('ytd-app');

        if (dark) {
          root?.setAttribute('dark', '');
          root?.setAttribute('darker-dark-theme', '');
          app?.setAttribute('dark', '');

          const targets = [root, body, app].filter(Boolean);
          for (const el of targets) {
            el.style.setProperty('color-scheme', 'dark', 'important');
            el.style.setProperty('--yt-spec-base-background', '#0f0f0f', 'important');
            el.style.setProperty('--yt-spec-raised-background', '#212121', 'important');
            el.style.setProperty('--yt-spec-menu-background', '#282828', 'important');
            el.style.setProperty('--yt-spec-inverted-background', '#f1f1f1', 'important');
            el.style.setProperty('--yt-spec-text-primary', '#f1f1f1', 'important');
            el.style.setProperty('--yt-spec-text-secondary', '#aaaaaa', 'important');
            el.style.setProperty('--yt-spec-text-disabled', '#717171', 'important');
            el.style.setProperty('--yt-spec-general-background-a', '#181818', 'important');
            el.style.setProperty('--yt-spec-general-background-b', '#0f0f0f', 'important');
            el.style.setProperty('--yt-spec-general-background-c', '#030303', 'important');
            el.style.setProperty('--yt-spec-badge-chip-background', 'rgba(255,255,255,.10)', 'important');
            el.style.setProperty('--yt-spec-10-percent-layer', 'rgba(255,255,255,.10)', 'important');
          }
        } else {
          root?.removeAttribute('dark');
          root?.removeAttribute('darker-dark-theme');
          app?.removeAttribute('dark');

          const targets = [root, body, app].filter(Boolean);
          for (const el of targets) {
            el.style.setProperty('color-scheme', 'light', 'important');
            el.style.setProperty('--yt-spec-base-background', '#ffffff', 'important');
            el.style.setProperty('--yt-spec-raised-background', '#f9f9f9', 'important');
            el.style.setProperty('--yt-spec-menu-background', '#ffffff', 'important');
            el.style.setProperty('--yt-spec-text-primary', '#0f0f0f', 'important');
            el.style.setProperty('--yt-spec-text-secondary', '#606060', 'important');
          }
        }
      }

      function youtubeThemeCSS(c) {
        if (!c.syncYouTubeTheme) return '';
        const dark = shouldUseDark(c.appearanceMode || 'system');

        if (!dark) {
          return `
            html, body, ytd-app, #page-manager, ytd-browse, ytd-search,
            ytd-watch-flexy, ytd-two-column-browse-results-renderer,
            ytd-two-column-search-results-renderer, ytd-section-list-renderer,
            ytd-rich-grid-renderer {
              background-color:#fff !important;
              color:#0f0f0f !important;
            }
          `;
        }

        return `
          html, body, ytd-app,
          #page-manager, #content, #primary, #secondary,
          ytd-browse, ytd-search, ytd-watch-flexy,
          ytd-two-column-browse-results-renderer,
          ytd-two-column-search-results-renderer,
          ytd-section-list-renderer, ytd-rich-grid-renderer,
          tp-yt-app-drawer, ytd-mini-guide-renderer,
          ytd-guide-renderer {
            background-color:#0f0f0f !important;
            color:#f1f1f1 !important;
          }

          ytd-masthead, #masthead-container,
          #container.ytd-masthead, #background.ytd-masthead {
            background-color:#0f0f0f !important;
            color:#f1f1f1 !important;
            border-color:rgba(255,255,255,.08) !important;
          }

          ytd-searchbox, #container.ytd-searchbox,
          #search-form, #search-input,
          input#search, input.ytd-searchbox,
          yt-searchbox, yt-searchbox input {
            background-color:#181818 !important;
            color:#f1f1f1 !important;
            border-color:#303030 !important;
          }

          #search-icon-legacy, ytd-searchbox button,
          tp-yt-paper-icon-button {
            background-color:#222 !important;
            color:#f1f1f1 !important;
          }

          #video-title, a#video-title, #video-title-link,
          #channel-name, ytd-channel-name, ytd-channel-name a,
          #metadata-line, #metadata-line span,
          #byline-container, #description,
          yt-formatted-string, h1, h2, h3,
          yt-attributed-string, .yt-core-attributed-string {
            color:#f1f1f1 !important;
          }

          #metadata-line, #metadata-line span,
          #byline-container, #description, #subtitle,
          .metadata-snippet-text, #owner-sub-count,
          #subscriber-count {
            color:#aaa !important;
          }

          ytd-video-renderer, ytd-rich-item-renderer,
          ytd-rich-grid-media, ytd-grid-video-renderer,
          ytd-compact-video-renderer, ytd-playlist-video-renderer,
          ytd-comment-thread-renderer, ytd-comments,
          ytd-engagement-panel-section-list-renderer,
          ytd-menu-popup-renderer, tp-yt-paper-dialog,
          yt-sheet-view-model, tp-yt-paper-listbox {
            background-color:#181818 !important;
            color:#f1f1f1 !important;
            border-color:rgba(255,255,255,.08) !important;
          }

          ytd-c4-tabbed-header-renderer, ytd-page-header-renderer,
          #channel-header-container, #tabs-container,
          #tabsContent, yt-tab-shape, tp-yt-paper-tab,
          #columns, #below, #info, #meta, ytd-watch-metadata {
            background-color:#0f0f0f !important;
            color:#f1f1f1 !important;
          }

          yt-chip-cloud-chip-renderer,
          ytd-feed-filter-chip-bar-renderer,
          yt-chip-cloud-renderer, .ytChipShapeChip,
          .yt-spec-button-shape-next {
            background-color:#272727 !important;
            color:#f1f1f1 !important;
            border-color:rgba(255,255,255,.08) !important;
          }

          ::-webkit-scrollbar { width:10px; height:10px; }
          ::-webkit-scrollbar-track { background:#0f0f0f; }
          ::-webkit-scrollbar-thumb {
            background:#3f3f3f;
            border-radius:999px;
            border:2px solid #0f0f0f;
          }
        `;
      }

      function listModeCSS() {
        return `
          ytd-video-renderer,
          ytd-compact-video-renderer,
          ytd-playlist-video-renderer,
          ytd-grid-video-renderer,
          ytd-rich-item-renderer,
          ytd-rich-grid-media {
            display:block !important;
            width:100% !important;
            max-width:none !important;
            margin:0 0 8px 0 !important;
            padding:11px 14px !important;
            box-sizing:border-box !important;
            background:rgba(127,127,127,.075) !important;
            border-radius:13px !important;
            min-height:0 !important;
          }

          ytd-rich-grid-renderer,
          ytd-rich-grid-row,
          #contents.ytd-rich-grid-renderer,
          ytd-two-column-browse-results-renderer #primary,
          ytd-section-list-renderer #contents {
            display:block !important;
            width:100% !important;
            max-width:none !important;
          }

          ytd-rich-grid-renderer #contents {
            margin:0 !important;
            padding:8px 12px !important;
          }

          ytd-rich-grid-row #contents {
            display:block !important;
            width:100% !important;
          }

          ytd-rich-item-renderer {
            --ytd-rich-grid-item-max-width:none !important;
            --ytd-rich-grid-item-min-width:0 !important;
          }

          ytd-thumbnail, yt-image, img.yt-core-image,
          .yt-core-image, #thumbnail, #thumbnail-container,
          .thumbnail-container, .ytd-thumbnail,
          .iv-player-content, .ytp-cued-thumbnail-overlay-image {
            display:none !important;
            visibility:hidden !important;
            width:0 !important;
            height:0 !important;
            min-width:0 !important;
            min-height:0 !important;
            margin:0 !important;
            padding:0 !important;
          }

          ytd-video-renderer #dismissible,
          ytd-grid-video-renderer #dismissible,
          ytd-compact-video-renderer #dismissible,
          ytd-playlist-video-renderer #content,
          ytd-rich-item-renderer #content,
          ytd-rich-grid-media #content,
          ytd-video-renderer #details,
          ytd-grid-video-renderer #details,
          ytd-compact-video-renderer #details,
          ytd-playlist-video-renderer #meta,
          ytd-rich-grid-media #details,
          ytd-rich-item-renderer #details {
            display:block !important;
            width:100% !important;
            max-width:none !important;
            min-width:0 !important;
            margin:0 !important;
            padding:0 !important;
          }

          #video-title, a#video-title, #video-title-link {
            display:block !important;
            font-size:15px !important;
            line-height:1.38 !important;
            font-weight:650 !important;
            margin:0 0 5px 0 !important;
            white-space:normal !important;
            max-height:none !important;
            overflow:visible !important;
          }

          ytd-video-meta-block, #metadata, #metadata-line,
          #byline-container, #channel-name,
          ytd-channel-name, ytd-channel-name a {
            max-width:100% !important;
            font-size:12px !important;
            line-height:1.45 !important;
            color:rgba(127,127,127,.95) !important;
          }

          ytd-badge-supported-renderer, ytd-menu-renderer,
          #menu, #buttons, .metadata-snippet-container,
          ytd-thumbnail-overlay-time-status-renderer,
          ytd-thumbnail-overlay-resume-playback-renderer {
            display:none !important;
          }

          ytd-c4-tabbed-header-renderer,
          ytd-page-header-renderer,
          #channel-header-container {
            margin-bottom:6px !important;
          }

          #tabsContent, yt-tab-shape, tp-yt-paper-tab {
            min-height:38px !important;
          }

          ytd-rich-grid-renderer #contents > *,
          ytd-rich-grid-row #contents > * {
            width:100% !important;
            max-width:none !important;
          }
        `;
      }


      function playerFeatureCSS(c) {
        let css = '';

        if (!c.allowPiP) {
          css += `
            .ytp-pip-button,
            .ytp-miniplayer-button[aria-label*="Picture"],
            button[aria-label*="Picture-in-Picture"],
            button[aria-label*="ピクチャ"] {
              display:none!important;
              visibility:hidden!important;
            }
          `;
        }

        if (!c.allowFullscreen) {
          css += `
            .ytp-fullscreen-button,
            button[aria-label*="Full screen"],
            button[aria-label*="fullscreen"],
            button[aria-label*="全画面"] {
              display:none!important;
              visibility:hidden!important;
            }
          `;
        }

        return css;
      }

      function applyPlayerFeatures(c) {
        window.__ytuPlayerFeatures = {
          allowPiP: !!c.allowPiP,
          allowFullscreen: !!c.allowFullscreen
        };

        style('__ytu_player_feature_style', playerFeatureCSS(c));

        document.querySelectorAll('video').forEach(v => {
          try {
            v.disablePictureInPicture = !c.allowPiP;
          } catch {}

          // Keep normal inline playback available even when fullscreen is disabled.
          try {
            v.setAttribute('playsinline', '');
            v.setAttribute('webkit-playsinline', '');
          } catch {}
        });
      }

      if (!window.__ytuPlayerFeatureGuardsInstalled) {
        window.__ytuPlayerFeatureGuardsInstalled = true;

        const isFullscreenControl = (target) => {
          const el = target?.closest?.(
            '.ytp-fullscreen-button,' +
            'button[aria-label*="Full screen"],' +
            'button[aria-label*="fullscreen"],' +
            'button[aria-label*="全画面"]'
          );
          return !!el;
        };

        const isPiPControl = (target) => {
          const el = target?.closest?.(
            '.ytp-pip-button,' +
            'button[aria-label*="Picture-in-Picture"],' +
            'button[aria-label*="ピクチャ"]'
          );
          return !!el;
        };

        document.addEventListener('click', (ev) => {
          const f = window.__ytuPlayerFeatures || {};
          if (f.allowFullscreen === false && isFullscreenControl(ev.target)) {
            ev.preventDefault();
            ev.stopImmediatePropagation();
            return false;
          }
          if (f.allowPiP === false && isPiPControl(ev.target)) {
            ev.preventDefault();
            ev.stopImmediatePropagation();
            return false;
          }
        }, true);

        document.addEventListener('dblclick', (ev) => {
          const f = window.__ytuPlayerFeatures || {};
          if (f.allowFullscreen === false && ev.target?.closest?.('#movie_player, video')) {
            ev.preventDefault();
            ev.stopImmediatePropagation();
            return false;
          }
        }, true);
      }

      function miniPlayerCSS() {
        return `
          ytd-player.__ytu_custom_mini {
            position:fixed !important;
            right:18px !important;
            bottom:18px !important;
            width:min(360px, calc(100vw - 36px)) !important;
            height:auto !important;
            aspect-ratio:16 / 9 !important;
            z-index:2147483000 !important;
            background:#000 !important;
            border-radius:14px !important;
            overflow:hidden !important;
            box-shadow:0 12px 42px rgba(0,0,0,.45) !important;
          }

          ytd-player.__ytu_custom_mini #movie_player,
          ytd-player.__ytu_custom_mini video {
            width:100% !important;
            height:100% !important;
          }

          ytd-player.__ytu_custom_mini video {
            object-fit:contain !important;
            opacity:1 !important;
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
            const card = el.closest(
              'ytd-rich-item-renderer,ytd-grid-video-renderer,ytd-video-renderer,' +
              'ytd-rich-section-renderer,ytd-reel-shelf-renderer,yt-tab-shape,tp-yt-paper-tab'
            ) || el;
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
            const hrefs = Array.from(el.querySelectorAll('a'))
              .map(a => a.href || '').join(' ');

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

      window.__ytuSetMiniPlayer = (enabled) => {
        window.__ytuMiniPlayerEnabled = !!enabled;

        const movie = document.querySelector('#movie_player');
        const ytdPlayer = document.querySelector('ytd-player');

        if (enabled) {
          // Prefer YouTube's native mini player when available.
          const nativeButton = document.querySelector('.ytp-miniplayer-button');
          const alreadyNative =
            movie?.classList.contains('ytp-player-minimized') ||
            document.querySelector('.ytp-miniplayer-ui');

          if (nativeButton && !alreadyNative) {
            try {
              nativeButton.click();
              return true;
            } catch {}
          }

          // Fallback for layouts without the native desktop mini-player control.
          if (ytdPlayer) {
            style('__ytu_mini_style', miniPlayerCSS());
            ytdPlayer.classList.add('__ytu_custom_mini');
            return true;
          }

          return false;
        }

        // Restore native mini player to the watch page when possible.
        const expand =
          document.querySelector('.ytp-miniplayer-expand-watch-page-button') ||
          document.querySelector('.ytp-miniplayer-ui .ytp-miniplayer-expand-watch-page-button');
        if (expand) {
          try { expand.click(); } catch {}
        }

        ytdPlayer?.classList.remove('__ytu_custom_mini');
        return true;
      };

      window.__ytuApply = (c) => {
        window.__ytuLastConfig = c;
        let r = [];

        forceYouTubeTheme(c);

        if (c.hideComments)
          r.push('#comments,ytd-comments,ytd-item-section-renderer[target-id="comments-section"]{display:none!important}');
        if (c.hideChat)
          r.push('#chat,#chat-container,ytd-live-chat-frame{display:none!important}');
        if (c.hideRelated)
          r.push('#related,ytd-watch-next-secondary-results-renderer{display:none!important}');
        if (c.hideThumbnails || c.textListMode || c.blockImages)
          r.push('ytd-thumbnail,yt-image,img.yt-core-image,.yt-core-image{display:none!important;visibility:hidden!important}');
        if (c.blockSeekPreview)
          r.push('.ytp-tooltip-bg,.ytp-tooltip-text-wrapper,.ytp-storyboard-framepreview,.ytp-preview{display:none!important}');
        if (c.audioOnly && !c.miniPlayer)
          r.push('video{opacity:0!important;background:#000!important}');
        if (c.textListMode)
          r.push(listModeCSS());

        r.push(youtubeThemeCSS(c));
        r.push(playerFeatureCSS(c));

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
        applyPlayerFeatures(c);

        if (c.miniPlayer) {
          window.__ytuSetMiniPlayer(true);
        } else {
          document.querySelector('ytd-player')?.classList.remove('__ytu_custom_mini');
        }

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
          const c = window.__ytuLastConfig;
          if (c) {
            forceYouTubeTheme(c);
            cleanupSpecialShelves(c);
            applyPlayerFeatures(c);

            if (c.miniPlayer && !document.querySelector('.ytp-miniplayer-ui')) {
              const ytdPlayer = document.querySelector('ytd-player');
              if (ytdPlayer && !ytdPlayer.classList.contains('__ytu_custom_mini')) {
                style('__ytu_mini_style', miniPlayerCSS());
                ytdPlayer.classList.add('__ytu_custom_mini');
              }
            }
          }

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
            } else if (
              u.includes('ytimg.com') ||
              /\.(png|jpg|jpeg|webp|gif)(\?|$)/.test(u)
            ) {
              o.image += n;
            } else {
              o.other += n;
            }
          }

          window.webkit?.messageHandlers?.traffic?.postMessage(o);
          sendPlayerState();
        } catch {}
      }, 4000);
    })();
    """#

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let model: BrowserModel
        var settings: AppSettings
        private var key = ""
        private var pendingPauseWorkItem: DispatchWorkItem?
        private var isCompilingRules = false
        private var lastAppliedThemeKey = ""

        init(model: BrowserModel, settings: AppSettings) {
            self.model = model
            self.settings = settings
        }

        func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
            if m.name == "playerState",
               let d = m.body as? [String: Any] {
                let playing = (d["playing"] as? Bool) ?? false

                if playing {
                    // YouTube can report a very short "paused" state while
                    // replacing the player DOM or changing streams.
                    // A real playing event should win immediately.
                    pendingPauseWorkItem?.cancel()
                    pendingPauseWorkItem = nil

                    Task { @MainActor in
                        model.isPlaying = true
                    }
                } else {
                    // Do not flash "停止中" for transient pauses.
                    // Only commit the paused state if it remains paused.
                    pendingPauseWorkItem?.cancel()

                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }

                        Task { @MainActor in
                            guard let webView = self.model.webView else {
                                self.model.isPlaying = false
                                return
                            }

                            webView.evaluateJavaScript("""
                            (() => {
                              const v = document.querySelector('video');
                              return !!(v && !v.paused && !v.ended);
                            })()
                            """) { result, _ in
                                Task { @MainActor in
                                    let stillPlaying = (result as? Bool) ?? false
                                    self.model.isPlaying = stillPlaying
                                }
                            }
                        }
                    }

                    pendingPauseWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
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

        func webView(_ w: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WKWebView navigation failed: \(error.localizedDescription)")
            Task { @MainActor in model.isLoading = false }
        }

        func webView(_ w: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WKWebView provisional navigation failed: \(error.localizedDescription)")
            Task { @MainActor in model.isLoading = false }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            print("WKWebView content process terminated; reloading")
            webView.reload()
        }

        func applyPageSettings(in w: WKWebView) {
            // v0.8 bug fix: send every setting actually used by the page script.
            let d: [String: Any] = [
                "audioOnly": settings.audioOnly,
                "hideComments": settings.hideComments,
                "hideChat": settings.hideChat,
                "hideRelated": settings.hideRelated,
                "hideThumbnails": settings.hideThumbnails,
                "blockSeekPreview": settings.blockSeekPreview,
                "textListMode": settings.textListMode,
                "blockImages": settings.blockImages,
                "hideMixes": settings.hideMixes,
                "hideShorts": settings.hideShorts,
                "syncYouTubeTheme": settings.syncYouTubeTheme,
                "appearanceMode": settings.appearanceMode,
                "miniPlayer": model.isMiniPlayer,
                "allowPiP": settings.allowPiP,
                "allowFullscreen": settings.allowFullscreen
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: d),
                  let j = String(data: data, encoding: .utf8) else { return }

            w.evaluateJavaScript("window.__ytuApply && window.__ytuApply(\(j));")
        }

        func installRules(on w: WKWebView) {
            let newKey = [
                settings.adBlock ? "a1" : "a0",
                settings.audioOnly ? "v1" : "v0",
                settings.blockSeekPreview ? "s1" : "s0",
                settings.hideChat ? "c1" : "c0",
                settings.blockImages ? "i1" : "i0",
                settings.textListMode ? "t1" : "t0",
                settings.hideShorts ? "h1" : "h0"
            ].joined(separator: "-")

            guard newKey != key, !isCompilingRules else { return }
            isCompilingRules = true

            var rules: [[String: Any]] = []

            func block(_ regex: String, _ types: [String]) {
                rules.append([
                    "trigger": [
                        "url-filter": regex,
                        "resource-type": types
                    ],
                    "action": ["type": "block"]
                ])
            }

            if settings.adBlock {
                block(".*doubleclick\\.net.*", ["script","image","raw","media","document"])
                block(".*googleadservices\\.com.*", ["script","image","raw","media","document"])
                block(".*youtube\\.com/.*(pagead|ptracking|ad_break|adunit|ad_).*", ["raw","script","image","media","document"])
            }

            if settings.blockSeekPreview {
                block(".*ytimg\\.com/sb/.*", ["image","raw"])
                block(".*storyboard.*", ["image","raw"])
            }

            if settings.hideChat {
                block(".*youtube\\.com/live_chat.*", ["document","raw"])
                block(".*youtube\\.com/youtubei/v1/live_chat.*", ["raw"])
            }

            if settings.blockImages || settings.textListMode || settings.hideThumbnails {
                block(".*ytimg\\.com/.*", ["image"])
                block(".*i\\.ytimg\\.com/.*", ["image"])
                block(".*ggpht\\.com/.*", ["image"])
            }

            // Do not block /shorts/ as a document. Hiding it in the DOM is safer:
            // blocking navigation at the WebKit rule level can leave a blank page.
            if settings.audioOnly {
                block(".*googlevideo\\.com/.*mime=video.*", ["media","raw"])
                block(".*googlevideo\\.com/.*itag=(133|134|135|136|137|138|160|242|243|244|247|248|264|266|271|272|278|298|299|302|303|308|313|315).*", ["media","raw"])
            }

            guard let data = try? JSONSerialization.data(withJSONObject: rules),
                  let json = String(data: data, encoding: .utf8) else {
                isCompilingRules = false
                return
            }

            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "YouTubeUtilityLC-\(newKey)",
                encodedContentRuleList: json
            ) { [weak self, weak w] list, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isCompilingRules = false

                    guard error == nil, let list, let w else {
                        print("Content rule compile failed: \(error?.localizedDescription ?? "unknown")")
                        return
                    }

                    self.key = newKey
                    w.configuration.userContentController.removeAllContentRuleLists()
                    w.configuration.userContentController.add(list)

                    // One controlled reload only when the current document has
                    // already completed loading. If it is still navigating,
                    // the rule list will apply naturally to subsequent requests.
                    if !self.model.isLoading, w.url != nil {
                        w.reload()
                    }
                }
            }
        }
    }
}
