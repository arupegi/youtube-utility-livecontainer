import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var browser = BrowserModel()

    @State private var showSettings = false
    @State private var showTraffic = false
    @FocusState private var addressFocused: Bool

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                WebView(model: browser, settings: settings)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(browser: browser)
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTraffic) {
            TrafficView(browser: browser)
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                browser.prepareForBackground()
            case .active:
                browser.resumeAfterForeground()
            default:
                break
            }
        }
    }

    private var header: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                CircleButton(systemName: "chevron.left", action: browser.goBack)
                CircleButton(systemName: "chevron.right", action: browser.goForward)
                CircleButton(systemName: browser.isLoading ? "xmark" : "arrow.clockwise", action: browser.reload)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("YouTubeを検索 / URLを入力", text: $browser.address)
                        .focused($addressFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit {
                            browser.navigate()
                            addressFocused = false
                        }

                    if !browser.address.isEmpty && addressFocused {
                        Button {
                            browser.address = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.title.isEmpty ? "YouTube" : browser.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(displayHost)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                statusPill(
                    icon: settings.audioOnly ? "waveform" : "play.rectangle",
                    text: settings.audioOnly ? "音声のみ" : "通常再生",
                    active: settings.audioOnly
                )

                statusPill(
                    icon: settings.textListMode ? "text.justify" : "square.grid.2x2",
                    text: settings.textListMode ? "一覧モード" : "標準表示",
                    active: settings.textListMode
                )

                statusPill(
                    icon: browser.isPlaying ? "speaker.wave.2.fill" : "pause.fill",
                    text: browser.isPlaying ? "再生中" : "停止中",
                    active: browser.isPlaying
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }


    private var bottomBar: some View {
        HStack {
            HStack(spacing: 10) {
                Button {
                    settings.audioOnly.toggle()
                    browser.reload()
                } label: {
                    BottomBarItem(
                        systemName: settings.audioOnly ? "waveform.circle.fill" : "waveform.circle",
                        title: settings.audioOnly ? "音声のみ" : "通常",
                        emphasized: settings.audioOnly
                    )
                }

                Button {
                    settings.textListMode.toggle()
                    if settings.textListMode {
                        settings.hideThumbnails = true
                        settings.blockImages = true
                    }
                    browser.reload()
                } label: {
                    BottomBarItem(
                        systemName: settings.textListMode ? "text.justify" : "square.grid.2x2",
                        title: settings.textListMode ? "一覧" : "標準",
                        emphasized: settings.textListMode
                    )
                }

                Button {
                    showTraffic = true
                } label: {
                    BottomBarItem(
                        systemName: "chart.bar.fill",
                        title: shortBytes(browser.traffic.totalBytes),
                        emphasized: false
                    )
                }

                Button {
                    showSettings = true
                } label: {
                    BottomBarItem(
                        systemName: "slider.horizontal.3",
                        title: "設定",
                        emphasized: false
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color.clear)
        .overlay(alignment: .top) {
            Divider().opacity(0.18)
        }
    }

    private var displayHost: String {
        URL(string: browser.currentURL)?.host ?? browser.currentURL
    }

    private func statusPill(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(active ? settings.themeColor : Color.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            active ? settings.themeColor.opacity(0.10) : Color.secondary.opacity(0.08),
            in: Capsule()
        )
    }

    private func shortBytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

private struct CircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct BottomBarItem: View {
    @EnvironmentObject private var settings: AppSettings
    let systemName: String
    let title: String
    let emphasized: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(emphasized ? settings.themeColor : Color.primary)
        .frame(width: 72, height: 42)
        .contentShape(Rectangle())
    }
}
