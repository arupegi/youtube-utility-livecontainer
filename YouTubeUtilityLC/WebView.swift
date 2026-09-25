import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel
    @ObservedObject var settings: AppSettings

    func makeCoordinator()->Coordinator { Coordinator(model:model, settings:settings) }

    func makeUIView(context:Context)->WKWebView {
        let cfg=WKWebViewConfiguration(); cfg.allowsInlineMediaPlayback=true; cfg.mediaTypesRequiringUserActionForPlayback=[]
        let uc=WKUserContentController(); uc.add(context.coordinator,name:"traffic")
        uc.addUserScript(WKUserScript(source:Self.pageScript,injectionTime:.atDocumentStart,forMainFrameOnly:false)); cfg.userContentController=uc
        let w=WKWebView(frame:.zero,configuration:cfg); w.navigationDelegate=context.coordinator; w.uiDelegate=context.coordinator; w.allowsBackForwardNavigationGestures=true
        model.webView=w; context.coordinator.installRules(on:w)
        if let u=URL(string:model.currentURL){ w.load(URLRequest(url:u)) }
        return w
    }
    func updateUIView(_ w:WKWebView, context:Context){ context.coordinator.settings=settings; context.coordinator.installRules(on:w); context.coordinator.applyPageSettings(in:w) }

    static let pageScript = #"""
    (()=>{
      function style(id,txt){let s=document.getElementById(id);if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement).appendChild(s)}s.textContent=txt}
      window.__ytuApply=(c)=>{let r=[];
        if(c.hideComments)r.push('#comments,ytd-comments,ytd-item-section-renderer[target-id="comments-section"]{display:none!important}');
        if(c.hideChat)r.push('#chat,#chat-container,ytd-live-chat-frame{display:none!important}');
        if(c.hideRelated)r.push('#related,ytd-watch-next-secondary-results-renderer{display:none!important}');
        if(c.hideThumbnails)r.push('ytd-thumbnail,yt-image,img.yt-core-image{visibility:hidden!important}');
        if(c.blockSeekPreview)r.push('.ytp-tooltip-bg,.ytp-tooltip-text-wrapper,.ytp-storyboard-framepreview,.ytp-preview{display:none!important}');
        if(c.audioOnly)r.push('video{opacity:0!important;background:#000!important}'); style('__ytu_style',r.join('\n'));
        document.querySelectorAll('video').forEach(v=>{try{v.disablePictureInPicture=!!c.audioOnly}catch(e){}})
      };
      setInterval(()=>{try{const es=performance.getEntriesByType('resource'),o={total:0,audio:0,video:0,image:0,other:0,count:0};
        for(const x of es){const n=x.transferSize||x.encodedBodySize||0;if(!n)continue;const u=(x.name||'').toLowerCase();o.total+=n;o.count++;
          if(u.includes('googlevideo.com')){if(u.includes('mime=audio')||u.includes('audio/'))o.audio+=n;else if(u.includes('mime=video')||u.includes('video/'))o.video+=n;else o.other+=n}
          else if(u.includes('ytimg.com')||/\.(png|jpg|jpeg|webp|gif)(\?|$)/.test(u))o.image+=n;else o.other+=n}
        window.webkit?.messageHandlers?.traffic?.postMessage(o)}catch(e){}},2500)
    })();
    """#

    final class Coordinator:NSObject,WKNavigationDelegate,WKUIDelegate,WKScriptMessageHandler {
        let model:BrowserModel; var settings:AppSettings; private var key=""
        init(model:BrowserModel,settings:AppSettings){self.model=model;self.settings=settings}
        func userContentController(_ u:WKUserContentController,didReceive m:WKScriptMessage){
            guard m.name=="traffic",let d=m.body as? [String:Any] else{return}
            let num:(String)->Int64={ Int64((d[$0] as? NSNumber)?.int64Value ?? 0) }
            Task{@MainActor in model.traffic=TrafficSnapshot(totalBytes:num("total"),audioBytes:num("audio"),videoBytes:num("video"),imageBytes:num("image"),otherBytes:num("other"),sampledResources:(d["count"] as? NSNumber)?.intValue ?? 0,updatedAt:Date())}
        }
        func webView(_ w:WKWebView,didFinish n:WKNavigation!){Task{@MainActor in model.currentURL=w.url?.absoluteString ?? model.currentURL;model.address=model.currentURL;model.title=w.title ?? ""};applyPageSettings(in:w)}
        func webView(_ w:WKWebView,didCommit n:WKNavigation!){applyPageSettings(in:w)}
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
