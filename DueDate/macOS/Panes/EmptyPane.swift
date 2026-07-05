//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

struct EmptyPane: View {
    var body: some View {
        Pane {
            ContentUnavailableView(
                "Nothing Selected",
                systemImage: "sidebar.left",
                description: Text("Choose a section in the sidebar.")
            )
        }
    }
}

#Preview {
    EmptyPane()
}
