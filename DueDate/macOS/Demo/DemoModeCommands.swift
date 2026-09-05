//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// Entering and leaving ``DemoMode``. Both restart the app, since the store is
/// chosen once when the environment is built.
struct DemoModeCommands: Commands {

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Divider()
            if DemoMode.isEnabled {
                Button("Exit Demo Mode…") {
                    DemoMode.exit()
                }
            } else {
                Button("Enter Demo Mode…") {
                    DemoMode.enter()
                }
            }
        }
    }
}
