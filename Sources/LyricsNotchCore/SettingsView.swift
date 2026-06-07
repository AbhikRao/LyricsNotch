import SwiftUI

struct SettingsView: View {
    @AppStorage("showLyrics") private var showLyrics = true
    @AppStorage("showGlow") private var showGlow = true
    @AppStorage("showCamera") private var showCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LyricsNotch")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Toggle("Show lyrics", isOn: $showLyrics)
            Toggle("Show ambient glow", isOn: $showGlow)
            Toggle("Show camera preview", isOn: $showCamera)

            Spacer(minLength: 0)
        }
        .toggleStyle(.switch)
        .padding(24)
        .frame(width: 320, height: 190, alignment: .topLeading)
    }
}
