import SwiftUI
import Foundation
import Combine

struct CalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var display = "0"
    @State private var currentNumber: Double = 0
    @State private var previousNumber: Double = 0
    @State private var operation: CalculatorOperation? = nil
    @State private var userIsTyping = false
    @State private var forceCount = 0
    // Use EnvironmentObject for settings to ensure consistency across app
    @EnvironmentObject var settings: CalculatorSettings
    @State private var lastButtonWasOperation = false
    @State private var lastMinuteChecked: Int? = nil
    @State private var hasUpdatedForMinuteChange = false
    @State private var showForceNumber = false
    @State private var showModeText = false
    
    // Plus Perfect state
    @State private var plusPerfectMode: PlusPerfectState = .inactive
    @State private var savedNumberForPlusPerfect: Double = 0
    @State private var lastOperationWasEquals = false
    @State private var isUpsideDown = false
    @StateObject private var plusPerfectHandler = PlusPerfectHandler()
    @State private var modeSyncCancellable: AnyCancellable?
    
    // For repeat equals functionality
    @State private var lastOperation: CalculatorOperation? = nil
    @State private var lastOperand: Double = 0
    @State private var hasEntryToClear = false
    
    init() {
        debugLog("🧮 CalculatorView: Initializing")
    }
    
    typealias Operation = CalculatorOperation
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Display Area
                VStack {
                    // Menu icon in top left
                    HStack {
                        Button(action: { 
                            debugLog("🔙 Menu button tapped - dismissing calculator")
                            dismiss() 
                        }) {
                            Image("icon-menu")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(settings.buttonTheme.color)
                        }
                        .padding(.leading, 24)
                        .padding(.top, 20)
                        Spacer()
                        
                        // Force number or mode display
                        if showForceNumber {
                            Text("\(settings.forceNumber)")
                                .font(.system(size: 16))
                                .foregroundColor(Color.gray.opacity(0.7))
                                .padding(.trailing, 24)
                                .padding(.top, 20)
                        } else if showModeText {
                            Text(settings.magicTrickMode.rawValue)
                                .font(.system(size: 16))
                                .foregroundColor(Color.gray.opacity(0.7))
                                .padding(.trailing, 24)
                                .padding(.top, 20)
                        }
                    }
                    
                    Spacer()
                    HStack {
                        Spacer()
                        Text(display)
                            .font(.custom("SF Pro Display", size: min(geometry.size.width * 0.22, 100)))
                            .fontWeight(.thin)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    .padding(.bottom, 30)
                }
                .frame(height: geometry.size.height * 0.35)
                
                // Button Grid
                CalculatorButtonGrid(
                    settings: settings,
                    showForceNumber: $showForceNumber,
                    showModeText: $showModeText,
                    digitAction: digitPressed,
                    decimalAction: decimalPressed,
                    backspaceAction: backspace,
                    clearAction: hasEntryToClear ? clearEntry : clearAll,
                    toggleSignAction: toggleSign,
                    toggleModeAction: toggleMode,
                    operationAction: { performOperation($0) },
                    equalsAction: equals
                )
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            debugLog("🧮 CalculatorView: onAppear called")
            debugLog("📊 Loading settings in CalculatorView")
            settings.loadSettings()
            debugLog("📊 Settings loaded: forceNumber=\(settings.forceNumber), mode=\(settings.magicTrickMode), plusPerfect=\(settings.plusPerfectEnabled)")
            forceCount = 0 // Reset force count when calculator appears
            
            // Always start monitoring device orientation for Plus Perfect
            // This allows detection when + is pressed while upside down
            debugLog("🎭 Plus Perfect: Starting orientation monitoring (enabled: \(settings.plusPerfectEnabled))")
            plusPerfectHandler.startMonitoring {
                calculatePerfectAddend()
            }
            
            // Observe handler's mode changes and sync to view state
            // This ensures view state stays in sync with handler state
            // Note: No need for [weak self] since CalculatorView is a struct, not a class
            modeSyncCancellable = plusPerfectHandler.$mode
                .receive(on: DispatchQueue.main)
                .sink { newMode in
                    if plusPerfectMode != newMode {
                        debugLog("🔄 Syncing Plus Perfect mode: \(plusPerfectMode) → \(newMode)")
                        plusPerfectMode = newMode
                    }
                }
            
            debugLog("✅ CalculatorView: onAppear completed")
        }
        .onDisappear {
            plusPerfectHandler.stopMonitoring()
            modeSyncCancellable?.cancel()
        }
    }
    
    // MARK: - Calculator Logic
    
    private func digitPressed(_ digit: String) {
        CalculatorOperations.digitPressed(
            digit,
            display: &display,
            userIsTyping: &userIsTyping,
            lastOperationWasEquals: &lastOperationWasEquals,
            plusPerfectMode: plusPerfectMode
        )
        hasEntryToClear = true
    }
    
    private func decimalPressed() {
        CalculatorOperations.decimalPressed(
            display: &display,
            userIsTyping: &userIsTyping,
            lastOperationWasEquals: &lastOperationWasEquals,
            plusPerfectMode: plusPerfectMode
        )
        hasEntryToClear = true
    }
    
    private func clearAll() {
        CalculatorOperations.clearAll(
            display: &display,
            currentNumber: &currentNumber,
            previousNumber: &previousNumber,
            operation: &operation,
            userIsTyping: &userIsTyping,
            forceCount: &forceCount,
            lastMinuteChecked: &lastMinuteChecked,
            hasUpdatedForMinuteChange: &hasUpdatedForMinuteChange,
            plusPerfectMode: &plusPerfectMode,
            savedNumberForPlusPerfect: &savedNumberForPlusPerfect,
            lastOperationWasEquals: &lastOperationWasEquals,
            lastOperation: &lastOperation,
            lastOperand: &lastOperand
        )
        hasEntryToClear = false
    }
    
    private func clearEntry() {
        CalculatorOperations.clearEntry(
            display: &display,
            userIsTyping: &userIsTyping
        )
        hasEntryToClear = false
    }
    
    private func backspace() {
        CalculatorOperations.backspace(
            display: &display,
            userIsTyping: &userIsTyping,
            plusPerfectMode: plusPerfectMode
        )
        // Update hasEntryToClear based on whether display is "0"
        hasEntryToClear = (display != "0")
    }
    
    private func toggleSign() {
        CalculatorOperations.toggleSign(
            display: &display,
            plusPerfectMode: plusPerfectMode
        )
    }
    
    private func toggleMode() {
        // Toggle between Force Number and Date/Time modes
        settings.magicTrickMode = settings.magicTrickMode == .forceNumber ? .exactDateTime : .forceNumber
        
        // Save settings
        Task { @MainActor in
            SettingsManager.shared.saveSettings(settings)
        }
        
        // Show mode text feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            showModeText = true
        }
        
        // Hide mode text after 0.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showModeText = false
            }
        }
        
        debugLog("🔄 Mode toggled to: \(settings.magicTrickMode)")
    }
    
    private func performOperation(_ op: CalculatorOperation) {
        CalculatorOperations.performOperation(
            op,
            display: &display,
            previousNumber: &previousNumber,
            operation: &operation,
            userIsTyping: &userIsTyping,
            lastButtonWasOperation: &lastButtonWasOperation,
            lastOperationWasEquals: &lastOperationWasEquals,
            settings: settings,
            plusPerfectMode: &plusPerfectMode,
            savedNumberForPlusPerfect: &savedNumberForPlusPerfect,
            plusPerfectHandler: plusPerfectHandler,
            equalsAction: equals
        )
        // Sync mode after operation
        plusPerfectMode = plusPerfectHandler.mode
        // After operation, there's no entry to clear (result is shown)
        hasEntryToClear = false
    }
    
    private func equals() {
        CalculatorOperations.equals(
            display: &display,
            currentNumber: &currentNumber,
            previousNumber: &previousNumber,
            operation: &operation,
            userIsTyping: &userIsTyping,
            lastButtonWasOperation: &lastButtonWasOperation,
            lastOperationWasEquals: &lastOperationWasEquals,
            forceCount: &forceCount,
            lastMinuteChecked: &lastMinuteChecked,
            hasUpdatedForMinuteChange: &hasUpdatedForMinuteChange,
            settings: settings,
            plusPerfectMode: &plusPerfectMode,
            lastOperation: &lastOperation,
            lastOperand: &lastOperand
        )
        // After equals, there's no entry to clear (result is shown)
        hasEntryToClear = false
    }
    
    private func calculatePerfectAddend() {
        plusPerfectHandler.calculatePerfectAddend(
            display: &display,
            operation: &operation,
            previousNumber: &previousNumber,
            currentNumber: &currentNumber,
            userIsTyping: &userIsTyping,
            settings: settings
        )
        plusPerfectMode = plusPerfectHandler.mode
    }
}
