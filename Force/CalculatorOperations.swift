import Foundation
import UIKit

enum PlusPerfectState {
    case inactive
    case activated  // = then + pressed
    case waitingForFlip  // Waiting for upside down
    case upsideDown  // Phone is upside down, ignoring input
    case calculated  // Perfect addend calculated and displayed
}

enum CalculatorOperation {
    case add, subtract, multiply, divide, percent
}

struct CalculatorOperations {
    // MARK: - Input Handling
    
    static func digitPressed(
        _ digit: String,
        display: inout String,
        userIsTyping: inout Bool,
        lastOperationWasEquals: inout Bool,
        plusPerfectMode: PlusPerfectState
    ) {
        lastOperationWasEquals = false
        
        // If Plus Perfect mode is active and upside down, ignore but show animation
        if plusPerfectMode == .upsideDown {
            debugLog("🎭 Plus Perfect: Ignoring digit \(digit) (upside down)")
            return
        }
        
        // Count only digits (excluding commas, decimal points, negative signs)
        let digitCount = display.filter { $0.isNumber }.count
        
        if userIsTyping {
            if digitCount < 9 { // Limit display to 9 digits
                display += digit
                // Format with commas
                display = CalculatorFormatter.formatDisplay(display)
            }
        } else {
            display = digit
            userIsTyping = true
        }
    }
    
    static func decimalPressed(
        display: inout String,
        userIsTyping: inout Bool,
        lastOperationWasEquals: inout Bool,
        plusPerfectMode: PlusPerfectState
    ) {
        lastOperationWasEquals = false
        
        // If Plus Perfect mode is active and upside down, ignore
        if plusPerfectMode == .upsideDown {
            debugLog("🎭 Plus Perfect: Ignoring decimal (upside down)")
            return
        }
        
        if !display.contains(".") {
            if userIsTyping {
                display += "."
            } else {
                display = "0."
                userIsTyping = true
            }
        }
    }
    
    static func backspace(
        display: inout String,
        userIsTyping: inout Bool,
        plusPerfectMode: PlusPerfectState
    ) {
        // If Plus Perfect mode is active and upside down, ignore
        if plusPerfectMode == .upsideDown {
            debugLog("🎭 Plus Perfect: Ignoring backspace (upside down)")
            return
        }
        
        // Remove commas, remove last character, then reformat
        let cleaned = display.replacingOccurrences(of: ",", with: "")
        if cleaned.count > 1 {
            let newCleaned = String(cleaned.dropLast())
            display = CalculatorFormatter.formatDisplay(newCleaned)
        } else {
            display = "0"
            userIsTyping = false
        }
    }
    
    static func toggleSign(
        display: inout String,
        plusPerfectMode: PlusPerfectState
    ) {
        // If Plus Perfect mode is active and upside down, ignore
        if plusPerfectMode == .upsideDown {
            debugLog("🎭 Plus Perfect: Ignoring toggle sign (upside down)")
            return
        }
        
        if display != "0" {
            if display.hasPrefix("-") {
                display.removeFirst()
                // Reformat to ensure commas are correct
                display = CalculatorFormatter.formatDisplay(display)
            } else {
                display = "-" + display
                // Reformat to ensure commas are correct
                display = CalculatorFormatter.formatDisplay(display)
            }
        }
    }
    
    static func clearAll(
        display: inout String,
        currentNumber: inout Double,
        previousNumber: inout Double,
        operation: inout CalculatorOperation?,
        userIsTyping: inout Bool,
        forceCount: inout Int,
        lastMinuteChecked: inout Int?,
        hasUpdatedForMinuteChange: inout Bool,
        plusPerfectMode: inout PlusPerfectState,
        savedNumberForPlusPerfect: inout Double,
        lastOperationWasEquals: inout Bool,
        lastOperation: inout CalculatorOperation?,
        lastOperand: inout Double
    ) {
        display = "0"
        currentNumber = 0
        previousNumber = 0
        operation = nil
        userIsTyping = false
        forceCount = 0 // Reset force count on clear all
        lastMinuteChecked = nil
        hasUpdatedForMinuteChange = false
        
        // Reset Plus Perfect mode
        plusPerfectMode = .inactive
        savedNumberForPlusPerfect = 0
        lastOperationWasEquals = false
        
        // Reset repeat equals state
        lastOperation = nil
        lastOperand = 0
        
        debugLog("🎭 Plus Perfect: Reset to inactive")
    }
    
    // MARK: - Operations
    
    static func performOperation(
        _ op: CalculatorOperation,
        display: inout String,
        previousNumber: inout Double,
        operation: inout CalculatorOperation?,
        userIsTyping: inout Bool,
        lastButtonWasOperation: inout Bool,
        lastOperationWasEquals: inout Bool,
        settings: CalculatorSettings,
        plusPerfectMode: inout PlusPerfectState,
        savedNumberForPlusPerfect: inout Double,
        plusPerfectHandler: PlusPerfectHandler,
        equalsAction: () -> Void
    ) {
        // Check for Plus Perfect activation: + pressed while phone is upside down
        if settings.plusPerfectEnabled && op == .add {
            let currentNumber = CalculatorFormatter.parseDisplay(display)
            debugLog("🎭➕ Plus Perfect: + button pressed!")
            debugLog("   Current display: \(display)")
            debugLog("   Parsed number: \(currentNumber)")
            debugLog("   Phone is upside down: \(plusPerfectHandler.isUpsideDown)")
            
            if plusPerfectHandler.isUpsideDown {
                debugLog("🎭✅ Plus Perfect: ACTIVATED! (+ pressed while upside down)")
                debugLog("   Saved number: \(currentNumber)")
                savedNumberForPlusPerfect = currentNumber
                plusPerfectMode = .activated
                plusPerfectHandler.mode = .activated
                plusPerfectHandler.savedNumber = savedNumberForPlusPerfect
                lastOperationWasEquals = false
                // Don't actually perform the addition operation yet
                return
            } else {
                // + pressed but not upside down - check if we should wait for flip
                // Save the number and set up to activate when phone flips
                debugLog("🎭⏳ Plus Perfect: + pressed, WAITING for phone to flip upside down")
                debugLog("   Saved number: \(currentNumber)")
                debugLog("   Current orientation: \(UIDevice.current.orientation.rawValue)")
                savedNumberForPlusPerfect = currentNumber
                plusPerfectHandler.savedNumber = savedNumberForPlusPerfect
                // Set mode to waitingForFlip so orientation handler can activate it
                plusPerfectMode = .waitingForFlip
                plusPerfectHandler.mode = .waitingForFlip
                lastOperationWasEquals = false
                // Don't perform addition yet - wait for flip
                return
            }
        }
        
        lastOperationWasEquals = false
        
        // If there's already an operation pending and user has entered a number, calculate it first
        // This allows chaining operations like "5 + 5 +" to show intermediate results (10)
        if let currentOp = operation, userIsTyping {
            debugLog("🔢 performOperation: Pending operation detected, calculating first")
            debugLog("   Before equals: display=\(display), previousNumber=\(previousNumber), operation=\(currentOp)")
            // User has entered a new number, calculate the previous operation
            // This will update display with the result (e.g., 5 + 5 = 10)
            equalsAction()
            debugLog("   After equals: display=\(display), previousNumber=\(previousNumber)")
            // After equalsAction(), display now shows the result and previousNumber is updated
            // The result is now ready to be used as the first operand for the new operation
        }
        
        // Set up for the new operation
        // Get the current display value (either the result from equalsAction() or the current number)
        // Note: If equalsAction() was called above, previousNumber was already updated to the result
        // So we need to get the current value from display to ensure we have the latest
        let currentDisplayValue = CalculatorFormatter.parseDisplay(display)
        previousNumber = currentDisplayValue
        operation = op
        userIsTyping = false
        lastButtonWasOperation = true
        
        debugLog("🔢 performOperation: Set previousNumber=\(previousNumber), operation=\(op), display=\(display)")
        
        if op == .percent {
            let result = previousNumber / 100
            display = CalculatorFormatter.formatResult(result)
            operation = nil
        }
    }
    
    static func equals(
        display: inout String,
        currentNumber: inout Double,
        previousNumber: inout Double,
        operation: inout CalculatorOperation?,
        userIsTyping: inout Bool,
        lastButtonWasOperation: inout Bool,
        lastOperationWasEquals: inout Bool,
        forceCount: inout Int,
        lastMinuteChecked: inout Int?,
        hasUpdatedForMinuteChange: inout Bool,
        settings: CalculatorSettings,
        plusPerfectMode: inout PlusPerfectState,
        lastOperation: inout CalculatorOperation?,
        lastOperand: inout Double
    ) {
        // Handle Plus Perfect mode - complete the "addition"
        if plusPerfectMode == .calculated {
            let forceNumber = settings.magicTrickMode == .forceNumber ? 
                Double(settings.forceNumber) : 
                Double(settings.getCurrentDateTimeNumber())
            
            display = CalculatorFormatter.formatResult(forceNumber)
            debugLog("🎭 Plus Perfect: Showing force number \(forceNumber)")
            plusPerfectMode = .inactive
            lastOperationWasEquals = false
            return
        }
        
        // If no operation but equals was pressed before, repeat the last operation
        guard let currentOp = operation ?? lastOperation else { 
            // No operation and no last operation, just mark that equals was pressed
            lastOperationWasEquals = true
            return 
        }
        
        // If we're repeating (no current operation), use the display as the new operand
        // Otherwise, use the current number
        if operation == nil {
            // Repeating last operation: use display as previousNumber, lastOperand as currentNumber
            previousNumber = CalculatorFormatter.parseDisplay(display)
            currentNumber = lastOperand
            debugLog("🟰 equals: Repeating operation - previousNumber=\(previousNumber), currentNumber=\(currentNumber)")
        } else {
            // Normal operation: use display as currentNumber
            currentNumber = CalculatorFormatter.parseDisplay(display)
            debugLog("🟰 equals: Normal operation - previousNumber=\(previousNumber), currentNumber=\(currentNumber), operation=\(operation!)")
        }
        
        var result: Double = 0
        
        switch currentOp {
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
        debugLog("Force count: \(forceCount), activation count: \(settings.activationCount), force number: \(settings.forceNumber), mode: \(settings.magicTrickMode)")
        if forceCount >= settings.activationCount {
            // Use the appropriate magic trick mode
            if settings.magicTrickMode == .forceNumber {
                result = Double(settings.forceNumber)
                debugLog("Forcing result to: \(settings.forceNumber)")
            } else {
                let currentMinute = Calendar.current.component(.minute, from: Date())
                
                // If this is the first force activation, capture the current minute
                if lastMinuteChecked == nil {
                    lastMinuteChecked = currentMinute
                    result = Double(settings.getCurrentDateTimeNumber())
                    debugLog("Forcing result to current date/time: \(result)")
                } else if !hasUpdatedForMinuteChange && currentMinute != lastMinuteChecked {
                    // If minute has changed and we haven't updated yet, update the result
                    hasUpdatedForMinuteChange = true
                    result = Double(settings.getCurrentDateTimeNumber())
                    debugLog("Updating force result to new minute: \(result)")
                } else {
                    // Use the last captured result
                    result = Double(settings.getCurrentDateTimeNumber())
                    debugLog("Using last captured date/time: \(result)")
                }
            }
            forceCount = 0
            // Reset operation to allow normal calculations after force
            operation = nil
        }
        
        display = CalculatorFormatter.formatResult(result)
        
        // Update previousNumber to the result so chained operations work correctly
        // This ensures that when user presses another operation button, it uses this result
        previousNumber = result
        
        debugLog("🟰 equals: Calculated result=\(result), display=\(display), previousNumber=\(previousNumber)")
        
        // Store operation and operand for repeat equals functionality
        if operation != nil {
            lastOperation = operation
            lastOperand = currentNumber
        }
        
        if forceCount == 0 {
            // Only reset operation if force was just activated
            operation = nil
        }
        userIsTyping = false
        lastButtonWasOperation = false
        lastOperationWasEquals = true
        
        debugLog("🟰 equals: Final state - display=\(display), previousNumber=\(previousNumber), operation=\(operation != nil ? String(describing: operation!) : "nil")")
    }
    
    // MARK: - Clear Entry
    
    static func clearEntry(
        display: inout String,
        userIsTyping: inout Bool
    ) {
        display = "0"
        userIsTyping = false
    }
    
}
