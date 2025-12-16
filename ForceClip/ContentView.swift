import SwiftUI
import Combine

struct ContentView: View {
    var body: some View {
        CalculatorView()
            .edgesIgnoringSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
