import SwiftUI

struct LibraryWindow: View {
    let model: LibraryModel

    var body: some View {
        NavigationSplitView {
            DeviceSwitcher(model: model)
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationSplitViewColumnWidth(236)
        } detail: {
            if case .ready = model.connection {
                Text("캡처 \(model.captures.count)개")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ConnectionGuide(model: model)
            }
        }
        .task { await model.watchConsoles() }
    }
}
