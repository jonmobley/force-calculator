import SwiftUI
import ForceShared

struct ContentView: View {
    @EnvironmentObject private var settings: CalculatorSettings

    var body: some View {
        CalculatorView()
            .environmentObject(settings)
            .edgesIgnoringSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(CalculatorSettings())
    }
}
