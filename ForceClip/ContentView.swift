import SwiftUI
import ForceShared

struct ContentView: View {
    @EnvironmentObject private var settings: CalculatorSettings

    var body: some View {
        // Only the black backdrop reaches the screen edges, which `CalculatorView`
        // handles itself. Ignoring the safe area out here would push the top controls
        // under the status bar and the bottom keys under the home indicator.
        CalculatorView()
            .environmentObject(settings)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(CalculatorSettings())
    }
}
