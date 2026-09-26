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
        uc.add(context.coordinator, name: "hybridMode")

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
      if (window.__ytuV14Installed) return;
      window.__ytuV14Installed = true;

      let cfg = {};
      let cleanupTimer = null;
      let trafficTimer = null;
      let lastPlaying = null;

      const traffic = {
        total: 0,
        audio: 0,
        video: 0,
        image: 0,
        other: 0,
        count: 0
      };

      function style(id, text) {
        let el = document.getElementById(id);
        if (!el) {
          el = document.createElement('style');
          el.id = id;
          (document.head || document.documentElement).appendChild(el);
        }
        if (el.textContent !== text) el.textContent = text;
      }

      function currentVideo() {
        return document.querySelector('video');
      }

      function postPlayerState(force = false) {
        const v = currentVideo();
        const playing = !!(v && !v.paused && !v.ended);

        if (!force && playing === lastPlaying) return;
        lastPlaying = playing;

        try {
          window.webkit?.messageHandlers?.playerState?.postMessage({ playing });
        } catch {}
      }

      function wantsDark() {
        if (cfg.appearanceMode === 'dark') return true;
        if (cfg.appearanceMode === 'light') return false;
        try {
          return matchMedia('(prefers-color-scheme: dark)').matches;
        } catch {
          return false;
        }
      }

      function applyTheme() {
        if (!cfg.syncYouTubeTheme) return;

        const dark = wantsDark();
        const root = document.documentElement;
        const body = document.body;
        const app = document.querySelector('ytd-app');

        if (dark) {
          root?.setAttribute('dark', '');
          root?.setAttribute('darker-dark-theme', '');
          app?.setAttribute('dark', '');

          for (const el of [root, body, app].filter(Boolean)) {
            el.style.setProperty('color-scheme', 'dark', 'important');
            el.style.setProperty('--yt-spec-base-background', '#0f0f0f', 'important');
            el.style.setProperty('--yt-spec-raised-background', '#212121', 'important');
            el.style.setProperty('--yt-spec-menu-background', '#282828', 'important');
            el.style.setProperty('--yt-spec-text-primary', '#f1f1f1', 'important');
            el.style.setProperty('--yt-spec-text-secondary', '#aaaaaa', 'important');
            el.style.setProperty('--yt-spec-general-background-a', '#181818', 'important');
            el.style.setProperty('--yt-spec-general-background-b', '#0f0f0f', 'important');
            el.style.setProperty('--yt-spec-general-background-c', '#030303', 'important');
          }
        } else {
          root?.removeAttribute('dark');
          root?.removeAttribute('darker-dark-theme');
          app?.removeAttribute('dark');

          for (const el of [root, body, app].filter(Boolean)) {
            el.style.setProperty('color-scheme', 'light', 'important');
            el.style.setProperty('--yt-spec-base-background', '#ffffff', 'important');
            el.style.setProperty('--yt-spec-raised-background', '#f9f9f9', 'important');
            el.style.setProperty('--yt-spec-menu-background', '#ffffff', 'important');
            el.style.setProperty('--yt-spec-text-primary', '#0f0f0f', 'important');
            el.style.setProperty('--yt-spec-text-secondary', '#606060', 'important');
          }
        }
      }

      function commonCSS() {
        let css = '';

        if (cfg.syncYouTubeTheme && wantsDark()) {
          css += `
            html,body,ytd-app,#page-manager,#content,#primary,#secondary,
            ytd-browse,ytd-search,ytd-watch-flexy,
            ytd-two-column-browse-results-renderer,
            ytd-two-column-search-results-renderer,
            ytd-section-list-renderer,ytd-rich-grid-renderer,
            ytd-masthead,#masthead-container {
              background:#0f0f0f!important;
              color:#f1f1f1!important;
            }

            ytd-searchbox,#container.ytd-searchbox,#search-form,#search-input,
            input#search,input.ytd-searchbox,yt-searchbox,yt-searchbox input {
              background:#181818!important;
              color:#f1f1f1!important;
              border-color:#303030!important;
            }

            #video-title,a#video-title,#video-title-link,#channel-name,
            ytd-channel-name,ytd-channel-name a,#metadata-line,
            #metadata-line span,#byline-container,yt-formatted-string,
            yt-attributed-string,.yt-core-attributed-string,h1,h2,h3 {
              color:#f1f1f1!important;
            }

            #metadata-line,#metadata-line span,#byline-container,
            #description,#owner-sub-count,#subscriber-count {
              color:#aaa!important;
            }

            ytd-video-renderer,ytd-rich-item-renderer,ytd-rich-grid-media,
            ytd-grid-video-renderer,ytd-compact-video-renderer,
            ytd-playlist-video-renderer {
              border-color:rgba(255,255,255,.08)!important;
            }
          `;
        }

        if (cfg.hideComments || cfg.minimalBandwidthMode) {
          css += `#comments,ytd-comments,
            ytd-item-section-renderer[target-id="comments-section"]{display:none!important;}`;
        }

        if (cfg.hideChat || cfg.minimalBandwidthMode) {
          css += `#chat,#chat-container,ytd-live-chat-frame{display:none!important;}`;
        }

        if (cfg.hideRelated || cfg.minimalBandwidthMode) {
          css += `#related,ytd-watch-next-secondary-results-renderer{display:none!important;}`;
        }

        if (cfg.hideThumbnails || cfg.textListMode || cfg.blockImages || cfg.minimalBandwidthMode) {
          css += `
            ytd-thumbnail,yt-image,img.yt-core-image,.yt-core-image,
            #thumbnail,#thumbnail-container,.thumbnail-container {
              display:none!important;
              visibility:hidden!important;
            }
          `;
        }

        if (cfg.blockSeekPreview || cfg.minimalBandwidthMode) {
          css += `.ytp-tooltip-bg,.ytp-tooltip-text-wrapper,
            .ytp-storyboard-framepreview,.ytp-preview{display:none!important;}`;
        }

        if (cfg.audioOnly || cfg.minimalBandwidthMode) {
          css += `video{opacity:0.001!important;background:#000!important;}`;
        }

        if (cfg.hideShorts || cfg.minimalBandwidthMode) {
          css += `
            ytd-reel-shelf-renderer,
            ytd-rich-shelf-renderer[is-shorts],
            ytd-guide-entry-renderer a[href="/shorts"],
            a[href="/shorts"] {
              display:none!important;
            }
          `;
        }

        if (!cfg.allowPiP) {
          css += `
            .ytp-pip-button,
            button[aria-label*="Picture-in-Picture"],
            button[aria-label*="ピクチャ"] {
              display:none!important;
            }
          `;
        }

        if (!cfg.allowFullscreen) {
          css += `
            .ytp-fullscreen-button,
            button[aria-label*="Full screen"],
            button[aria-label*="fullscreen"],
            button[aria-label*="全画面"] {
              display:none!important;
            }
          `;
        }

        return css;
      }

      function listCSS() {
        if (!(cfg.textListMode || cfg.minimalBandwidthMode)) return '';

        return `
          ytd-video-renderer,ytd-compact-video-renderer,
          ytd-playlist-video-renderer,ytd-grid-video-renderer,
          ytd-rich-item-renderer,ytd-rich-grid-media {
            display:block!important;
            width:100%!important;
            max-width:none!important;
            margin:0 0 8px 0!important;
            padding:10px 13px!important;
            box-sizing:border-box!important;
            background:rgba(127,127,127,.07)!important;
            border-radius:12px!important;
            min-height:0!important;
          }

          ytd-rich-grid-renderer,ytd-rich-grid-row,
          #contents.ytd-rich-grid-renderer,
          ytd-two-column-browse-results-renderer #primary {
            display:block!important;
            width:100%!important;
            max-width:none!important;
          }

          ytd-rich-grid-row #contents {
            display:block!important;
            width:100%!important;
          }

          ytd-rich-item-renderer {
            --ytd-rich-grid-item-max-width:none!important;
            --ytd-rich-grid-item-min-width:0!important;
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
            display:block!important;
            width:100%!important;
            max-width:none!important;
            min-width:0!important;
            margin:0!important;
            padding:0!important;
          }

          #video-title,a#video-title,#video-title-link {
            display:block!important;
            font-size:15px!important;
            line-height:1.35!important;
            font-weight:600!important;
            margin:0 0 4px 0!important;
            white-space:normal!important;
            max-height:none!important;
            overflow:visible!important;
          }

          ytd-menu-renderer,#menu,.metadata-snippet-container,
          ytd-thumbnail-overlay-resume-playback-renderer {
            display:none!important;
          }

          ${cfg.minimalBandwidthMode ? `
            #metadata-line,
            #description-text,
            #description,
            .metadata-snippet-container,
            .inline-metadata-item,
            ytd-badge-supported-renderer,
            #overlays,
            ytd-thumbnail-overlay-time-status-renderer,
            ytd-thumbnail-overlay-now-playing-renderer,
            ytd-thumbnail-overlay-toggle-button-renderer,
            #channel-info,
            #avatar-link,
            #avatar,
            yt-img-shadow,
            ytd-channel-avatar-renderer,
            ytd-avatar,
            #byline-container span:not(:first-child) {
              display:none!important;
            }

            #channel-name,
            ytd-channel-name,
            ytd-channel-name a,
            #byline-container,
            #byline-container a {
              display:block!important;
              font-size:12px!important;
              line-height:1.35!important;
              color:rgba(127,127,127,.95)!important;
              margin:0!important;
              padding:0!important;
            }

            #byline-container {
              margin-top:2px!important;
            }
          ` : ''}
        `;
      }


      function applyLowBandwidthPlayback() {
        const v = currentVideo();
        const player = document.querySelector('#movie_player');
        if (!v) return;

        try {
          v.preload = 'auto';
          v.setAttribute('playsinline', '');
          v.setAttribute('webkit-playsinline', '');
        } catch {}

        if (cfg.audioOnly) {
          try {
            if (player && typeof player.setPlaybackQualityRange === 'function') {
              player.setPlaybackQualityRange('tiny', 'tiny');
            } else if (player && typeof player.setPlaybackQuality === 'function') {
              player.setPlaybackQuality('tiny');
            }
          } catch {}
        }
      }

      function installSeekRecovery() {
        const v = currentVideo();
        if (!v || v.__ytuSeekRecoveryInstalled) return;

        v.__ytuSeekRecoveryInstalled = true;
        let seekTimer = null;

        v.addEventListener('seeking', () => {
          window.__ytuWasPlayingBeforeSeek = !v.paused && !v.ended;
          if (seekTimer) clearTimeout(seekTimer);
        }, { passive: true });

        v.addEventListener('seeked', () => {
          if (seekTimer) clearTimeout(seekTimer);

          seekTimer = setTimeout(() => {
            if (
              window.__ytuWasPlayingBeforeSeek &&
              v.paused &&
              !v.ended
            ) {
              v.play().catch(() => {});
            }
          }, 700);
        }, { passive: true });
      }


      let hybridState = {
        aggressive: false,
        waitingSince: 0,
        stableSince: 0,
        retryTimer: null
      };

      function postHybridMode(aggressive) {
        if (!cfg.minimalBandwidthMode) aggressive = false;
        if (hybridState.aggressive === aggressive) return;

        hybridState.aggressive = aggressive;

        try {
          window.webkit?.messageHandlers?.hybridMode?.postMessage({
            aggressive
          });
        } catch {}
      }

      function installHybridBandwidthController() {
        const v = currentVideo();
        if (!v || v.__ytuHybridInstalled) return;

        v.__ytuHybridInstalled = true;

        const markHealthy = () => {
          if (!cfg.minimalBandwidthMode) {
            postHybridMode(false);
            return;
          }

          hybridState.waitingSince = 0;

          if (!hybridState.stableSince) {
            hybridState.stableSince = Date.now();
          }

          // After 12 seconds of stable playback, try the aggressive
          // video-blocking mode again.
          if (!hybridState.aggressive &&
              Date.now() - hybridState.stableSince > 12000) {
            postHybridMode(true);
          }
        };

        const markWaiting = () => {
          if (!cfg.minimalBandwidthMode) return;

          if (!hybridState.waitingSince) {
            hybridState.waitingSince = Date.now();
          }

          hybridState.stableSince = 0;

          if (hybridState.retryTimer) {
            clearTimeout(hybridState.retryTimer);
          }

          hybridState.retryTimer = setTimeout(() => {
            const video = currentVideo();
            if (!video || !cfg.minimalBandwidthMode) return;

            // If waiting/stalled persists for ~2.2 sec, fall back to tiny video.
            if (
              hybridState.waitingSince &&
              Date.now() - hybridState.waitingSince >= 2000
            ) {
              postHybridMode(false);

              const player = document.querySelector('#movie_player');
              try {
                if (player && typeof player.setPlaybackQualityRange === 'function') {
                  player.setPlaybackQualityRange('tiny', 'tiny');
                } else if (player && typeof player.setPlaybackQuality === 'function') {
                  player.setPlaybackQuality('tiny');
                }
              } catch {}

              video.play().catch(() => {});
            }
          }, 2200);
        };

        v.addEventListener('playing', markHealthy, { passive: true });
        v.addEventListener('canplay', markHealthy, { passive: true });
        v.addEventListener('timeupdate', () => {
          if (!v.paused && !v.seeking) markHealthy();
        }, { passive: true });

        v.addEventListener('waiting', markWaiting, { passive: true });
        v.addEventListener('stalled', markWaiting, { passive: true });

        v.addEventListener('seeking', () => {
          // Seeking on a poor link is more reliable in fallback mode.
          postHybridMode(false);
          hybridState.waitingSince = Date.now();
          hybridState.stableSince = 0;
        }, { passive: true });

        v.addEventListener('seeked', () => {
          hybridState.waitingSince = 0;
          hybridState.stableSince = Date.now();
        }, { passive: true });

        if (cfg.minimalBandwidthMode && !v.paused) {
          hybridState.stableSince = Date.now();
        }
      }

      function installPlayerButtons() {
        const right = document.querySelector('.ytp-right-controls');
        const video = currentVideo();

        if (!right || !video) return;

        let pip = document.getElementById('__ytu_pip_button');
        if (!pip && cfg.allowPiP) {
          pip = document.createElement('button');
          pip.id = '__ytu_pip_button';
          pip.className = 'ytp-button';
          pip.type = 'button';
          pip.title = 'PiP';
          pip.setAttribute('aria-label', 'PiP');
          pip.innerHTML = `
            <svg viewBox="0 0 36 36" width="100%" height="100%" aria-hidden="true">
              <path fill="currentColor"
                d="M7 9h22v16H19v-2h8V11H9v14h7v2H7V9zm12 8h8v6h-8v-6z"/>
            </svg>`;
          pip.addEventListener('click', async (e) => {
            e.preventDefault();
            e.stopPropagation();
            const v = currentVideo();
            if (!v) return;

            try {
              v.disablePictureInPicture = false;
            } catch {}

            try {
              if (typeof v.webkitSetPresentationMode === 'function') {
                v.webkitSetPresentationMode('picture-in-picture');
                return;
              }
            } catch {}

            try {
              if (document.pictureInPictureElement) {
                await document.exitPictureInPicture();
              } else if (v.requestPictureInPicture) {
                await v.requestPictureInPicture();
              }
            } catch (err) {
              console.log('PiP failed', err);
            }
          }, true);

          const nativeFull = right.querySelector('.ytp-fullscreen-button');
          right.insertBefore(pip, nativeFull || null);
        }

        if (pip) {
          pip.style.display = cfg.allowPiP ? '' : 'none';
        }

        let full = document.getElementById('__ytu_fullscreen_button');
        if (!full && cfg.allowFullscreen) {
          full = document.createElement('button');
          full.id = '__ytu_fullscreen_button';
          full.className = 'ytp-button';
          full.type = 'button';
          full.title = '全画面';
          full.setAttribute('aria-label', '全画面');
          full.innerHTML = `
            <svg viewBox="0 0 36 36" width="100%" height="100%" aria-hidden="true">
              <path fill="currentColor"
                d="M8 8h8v2h-6v6H8V8zm12 0h8v8h-2v-6h-6V8zM8 20h2v6h6v2H8v-8zm18 0h2v8h-8v-2h6v-6z"/>
            </svg>`;
          full.addEventListener('click', async (e) => {
            e.preventDefault();
            e.stopPropagation();
            const v = currentVideo();
            const player = document.querySelector('#movie_player') || v;
            if (!v) return;

            try {
              if (document.fullscreenElement && document.exitFullscreen) {
                await document.exitFullscreen();
                return;
              }
              if (player?.requestFullscreen) {
                await player.requestFullscreen();
                return;
              }
            } catch {}

            try {
              if (typeof v.webkitEnterFullscreen === 'function') {
                v.webkitEnterFullscreen();
              }
            } catch (err) {
              console.log('Fullscreen failed', err);
            }
          }, true);

          right.appendChild(full);
        }

        if (full) {
          full.style.display = cfg.allowFullscreen ? '' : 'none';
        }

        try {
          video.disablePictureInPicture = !cfg.allowPiP;
          video.setAttribute('playsinline', '');
          video.setAttribute('webkit-playsinline', '');
        } catch {}
      }

      function hideMixFromNode(node) {
        if (!(cfg.hideMixes || cfg.minimalBandwidthMode) || !node || node.nodeType !== 1) return;

        const candidates = [];

        if (node.matches?.(
          'ytd-radio-renderer,ytd-compact-radio-renderer,ytd-playlist-renderer,' +
          'ytd-compact-playlist-renderer,ytd-rich-item-renderer,ytd-grid-playlist-renderer'
        )) {
          candidates.push(node);
        }

        node.querySelectorAll?.(
          'ytd-radio-renderer,ytd-compact-radio-renderer,ytd-playlist-renderer,' +
          'ytd-compact-playlist-renderer,ytd-rich-item-renderer,ytd-grid-playlist-renderer'
        ).forEach(el => candidates.push(el));

        for (const el of candidates) {
          const txt = (el.innerText || '').toLowerCase();
          const hrefs = Array.from(el.querySelectorAll('a'))
            .map(a => a.href || '').join(' ');

          if (
            txt.includes('mix') ||
            txt.includes('ミックス') ||
            hrefs.includes('list=RD') ||
            hrefs.includes('start_radio=1')
          ) {
            el.style.setProperty('display', 'none', 'important');
          }
        }
      }

      function bindVideo() {
        const v = currentVideo();
        if (!v || v.__ytuBoundV14) return;
        v.__ytuBoundV14 = true;

        ['play','pause','ended','playing','waiting'].forEach(name => {
          v.addEventListener(name, () => postPlayerState(), { passive: true });
        });

        postPlayerState(true);
      }

      function applyDynamic(root = document) {
        applyTheme();
        bindVideo();
        applyLowBandwidthPlayback();
        installSeekRecovery();
        installHybridBandwidthController();
        installPlayerButtons();
        hideMixFromNode(root);
      }

      function scheduleDynamic(root) {
        if (cleanupTimer) return;
        cleanupTimer = setTimeout(() => {
          cleanupTimer = null;
          applyDynamic(root || document);
        }, 180);
      }

      function addResource(entry) {
        if (!entry) return;
        const n = entry.transferSize || entry.encodedBodySize || 0;
        if (!n) return;

        const u = (entry.name || '').toLowerCase();
        traffic.total += n;
        traffic.count += 1;

        if (u.includes('googlevideo.com')) {
          if (u.includes('mime=audio') || u.includes('audio/')) traffic.audio += n;
          else if (u.includes('mime=video') || u.includes('video/')) traffic.video += n;
          else traffic.other += n;
        } else if (
          u.includes('ytimg.com') ||
          /\.(png|jpg|jpeg|webp|gif)(\?|$)/.test(u)
        ) {
          traffic.image += n;
        } else {
          traffic.other += n;
        }
      }

      function postTraffic() {
        try {
          window.webkit?.messageHandlers?.traffic?.postMessage({...traffic});
        } catch {}
      }

      // Incremental resource monitoring: no repeated full performance-entry scans.
      try {
        performance.getEntriesByType('resource').forEach(addResource);

        const po = new PerformanceObserver(list => {
          list.getEntries().forEach(addResource);

          if (!trafficTimer) {
            trafficTimer = setTimeout(() => {
              trafficTimer = null;
              postTraffic();
            }, 1000);
          }
        });
        po.observe({ type: 'resource', buffered: false });
      } catch {}

      // Only react to newly added DOM nodes. Do not rescan the whole page periodically.
      const mo = new MutationObserver(records => {
        let root = null;
        for (const rec of records) {
          if (rec.addedNodes?.length) {
            root = rec.target;
            break;
          }
        }
        if (root) scheduleDynamic(root);
      });

      function startObserver() {
        if (!document.documentElement) return;
        mo.observe(document.documentElement, {
          childList: true,
          subtree: true
        });
      }

      window.__ytuApply = (next) => {
        cfg = next || {};
        window.__ytuLastConfig = cfg;

        if (!cfg.minimalBandwidthMode) {
          hybridState.waitingSince = 0;
          hybridState.stableSince = 0;
          postHybridMode(false);
        }

        style('__ytu_style', commonCSS() + listCSS());

        applyDynamic(document);
        postTraffic();
      };

      document.addEventListener('yt-navigate-finish', () => {
        scheduleDynamic(document);
      }, true);

      document.addEventListener('visibilitychange', () => {
        const v = currentVideo();
        if (!v) return;

        if (document.hidden) {
          window.__ytuWasPlayingBeforeBackground = !v.paused && !v.ended;
        } else {
          if (window.__ytuWasPlayingBeforeBackground && v.paused) {
            v.play().catch(() => {});
          }
          scheduleDynamic(document);
        }

        postPlayerState(true);
      }, true);

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
          startObserver();
          scheduleDynamic(document);
        }, { once: true });
      } else {
        startObserver();
        scheduleDynamic(document);
      }
    })();
    """#

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let model: BrowserModel
        var settings: AppSettings
        private var key = ""
        private var pendingPauseWorkItem: DispatchWorkItem?
        private var isCompilingRules = false
        private var hybridAggressiveVideoBlock = false
        
        init(model: BrowserModel, settings: AppSettings) {
            self.model = model
            self.settings = settings
        }

        func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
            if m.name == "hybridMode",
               let d = m.body as? [String: Any],
               let aggressive = d["aggressive"] as? Bool {
                if aggressive != hybridAggressiveVideoBlock {
                    hybridAggressiveVideoBlock = aggressive
                    key = ""
                    if let webView = model.webView {
                        installRules(on: webView)
                    }
                }
                return
            }

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
                "minimalBandwidthMode": settings.minimalBandwidthMode,
                "syncYouTubeTheme": settings.syncYouTubeTheme,
                "appearanceMode": settings.appearanceMode,
                "allowPiP": settings.allowPiP,
                "allowFullscreen": settings.allowFullscreen
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: d),
                  let j = String(data: data, encoding: .utf8) else { return }

            w.evaluateJavaScript("window.__ytuApply && window.__ytuApply(\(j));")
        }

        func installRules(on w: WKWebView) {
            let effectiveHideChat = settings.hideChat || settings.minimalBandwidthMode
            let effectiveBlockImages = settings.blockImages || settings.textListMode || settings.hideThumbnails || settings.minimalBandwidthMode
            let effectiveBlockSeekPreview = settings.blockSeekPreview || settings.minimalBandwidthMode

            let newKey = [
                settings.adBlock ? "a1" : "a0",
                settings.audioOnly ? "v1" : "v0",
                effectiveBlockSeekPreview ? "s1" : "s0",
                effectiveHideChat ? "c1" : "c0",
                effectiveBlockImages ? "i1" : "i0",
                settings.textListMode ? "t1" : "t0",
                settings.hideShorts ? "h1" : "h0",
                settings.minimalBandwidthMode ? "m1" : "m0",
                hybridAggressiveVideoBlock ? "hb1" : "hb0"
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

            if effectiveBlockSeekPreview {
                block(".*ytimg\\.com/sb/.*", ["image","raw"])
                block(".*storyboard.*", ["image","raw"])
            }

            if effectiveHideChat {
                block(".*youtube\\.com/live_chat.*", ["document","raw"])
                block(".*youtube\\.com/youtubei/v1/live_chat.*", ["raw"])
            }

            if effectiveBlockImages {
                block(".*ytimg\\.com/.*", ["image"])
                block(".*i\\.ytimg\\.com/.*", ["image"])
                block(".*ggpht\\.com/.*", ["image"])
            }

            // Do not block /shorts/ as a document. Hiding it in the DOM is safer:
            // blocking navigation at the WebKit rule level can leave a blank page.
            // v0.16: do not hard-block YouTube video segments in audio-only mode.
            // Hard blocking can deadlock the MSE player on poor connections.

            // v0.18 hybrid mode:
            // While playback is healthy, minimal bandwidth mode may temporarily
            // block video-only segments. If the player stalls, JavaScript asks
            // Swift to disable this rule immediately without reloading the page.
            if settings.minimalBandwidthMode && hybridAggressiveVideoBlock {
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

                    // Keep the current YouTube page alive. On slow connections,
                    // forcing a top-level reload here causes a long stall.
                    self.applyPageSettings(in: w)
                }
            }
        }
    }
}
