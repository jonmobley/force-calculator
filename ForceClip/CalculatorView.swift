import SwiftUI
import Foundation

struct CalculatorView: View {
    @State private var display = "0"
    @State private var currentNumber: Double = 0
    @State private var previousNumber: Double = 0
    @State private var operation: Operation? = nil
    @State private var userIsTyping = false
    @State private var showBackButton = false
    @State private var forceCount = 0
    @State private var settings = SettingsManager.shared.loadSettings()
    @State private var lastButtonWasOperation = false
    @State private var lastMinuteChecked: Int? = nil
    @State private var hasUpdatedForMinuteChange = false
    
    enum Operation {
        case add, subtract, multiply, divide, percent
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Display Area
                CalculatorDisplayArea(display: display, geometry: geometry)
                
                // Button Grid
                CalculatorButtonGridClip(
                    settings: settings,
                    showBackButton: showBackButton,
                    digitAction: digitPressed,
                    decimalAction: decimalPressed,
                    backspaceAction: backspace,
                    clearAction: clearAll,
                    toggleSignAction: toggleSign,
                    operationAction: performOperation,
                    equalsAction: equals,
                    toggleModeAction: toggleMode
                )
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            settings = SettingsManager.shared.loadSettings()
        }
    }
    
    // MARK: - Calculator Logic
    
    private func digitPressed(_ digit: String) {
        if userIsTyping {
            if display.count < 9 { // Limit display to 9 digits
                display += digit
            }
        } else {
            display = digit
            userIsTyping = true
        }
        showBackButton = true
    }
    
    private func decimalPressed() {
        if !display.contains(".") {
            if userIsTyping {
                display += "."
            } else {
                display = "0."
                userIsTyping = true
            }
            showBackButton = true
        }
    }
    
    private func clearAll() {
        display = "0"
        currentNumber = 0
        previousNumber = 0
        operation = nil
        userIsTyping = false
        showBackButton = false
        forceCount = 0 // Reset force count on clear all
        lastMinuteChecked = nil
        hasUpdatedForMinuteChange = false
    }
    
    private func backspace() {
        if display.count > 1 {
            display.removeLast()
        } else {
            display = "0"
            userIsTyping = false
            showBackButton = false
        }
    }
    
    private func toggleSign() {
        if display != "0" {
            if display.hasPrefix("-") {
                display.removeFirst()
            } else {
                display = "-" + display
            }
        }
    }
    
    private func performOperation(_ op: Operation) {
        if let _ = operation, userIsTyping {
            equals()
        }
        
        previousNumber = Double(display) ?? 0
        operation = op
        userIsTyping = false
        lastButtonWasOperation = true
        
        if op == .percent {
            let result = previousNumber / 100
            display = CalculatorFormatter.formatResult(result)
            operation = nil
        }
    }
    
    private func equals() {
        guard let operation = operation else { return }
        
        currentNumber = Double(display) ?? 0
        var result: Double = 0
        
        switch operation {
        case .add:
            result = previousNumber + currentNumber
        case .subtract:
            result = previousNumber - currentNumber
        case .multiply:
            result = previousNumber * currentNumber
        case .divide:
            if currentNumber != 0 {
                result = previousNumber / currentNumber
            } else {
                display = "Error"
                return
            }
        case .percent:
            return // Already handled in performOperation
        }
        
        // Magic trick logic for Force functionality
        forceCount += 1
        if forceCount >= settings.activationCount {
            // Use the appropriate magic trick mode
            if settings.magicTrickMode == .forceNumber {
                result = Double(settings.forceNumber)
            } else {
                let currentMinute = Calendar.current.component(.minute, from: Date())
                
                // If this is the first force activation, capture the current minute
                if lastMinuteChecked == nil {
                    lastMinuteChecked = currentMinute
                    result = Double(settings.getCurrentDateTimeNumber())
                } else if !hasUpdatedForMinuteChange && currentMinute != lastMinuteChecked {
                    // If minute has changed and we haven't updated yet, update the result
                    hasUpdatedForMinuteChange = true
                    result = Double(settings.getCurrentDateTimeNumber())
                } else {
                    // Use the last captured result
                    result = Double(settings.getCurrentDateTimeNumber())
                }
            }
            forceCount = 0
            // Reset operation to allow normal calculations after force
            self.operation = nil
        }
        
        display = CalculatorFormatter.formatResult(result)
        if forceCount == 0 {
            // Only reset operation if force was just activated
            self.operation = nil
        }
        userIsTyping = false
        showBackButton = false
        lastButtonWasOperation = false
    }
    
    private func toggleMode() {
        settings.magicTrickMode = settings.magicTrickMode == .forceNumber ? .exactDateTime : .forceNumber
        SettingsManager.shared.saveSettings(settings)
    }
}
