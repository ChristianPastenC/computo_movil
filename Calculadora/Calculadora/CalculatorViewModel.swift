//
//  CalculatorViewModel.swift
//  Calculadora
//
//  Created by Christian Pasten on 13/11/25.
//

import Foundation

enum Operation {
    case add, subtract, multiply, divide, none
}

class CalculatorViewModel: ObservableObject {
    
    @Published var displayValue = "0"
    @Published var expressionText = ""
    
    private var currentNumber: Double = 0
    private var previousNumber: Double?
    private var currentOperation: Operation = .none
    private var newNumberBegan = false
    
    var currentOpSymbol: String? {
        currentOperation == .none ? nil : symbol(for: currentOperation)
    }
    
    func tapped(button: CalculatorButton) {
        switch button {
        case .digit(let digit):
            handleDigit(digit)
        case .operation(let op):
            handleOperation(op)
        case .equals:
            handleEquals()
        case .clear:
            handleClear()
        case .decimal:
            handleDecimal()
        case .percent:
            handlePercent()
        case .plusMinus:
            handlePlusMinus()
        }
    }
    
    private func handleDigit(_ digit: Int) {
        if newNumberBegan {
            displayValue = String(digit)
            newNumberBegan = false
        } else {
            if displayValue == "0" {
                displayValue = String(digit)
            } else {
                displayValue += String(digit)
            }
        }
        currentNumber = Double(displayValue) ?? 0
        updateExpression()
    }
    
    private func handleDecimal() {
        if newNumberBegan {
            displayValue = "0."
            newNumberBegan = false
            currentNumber = 0
            updateExpression()
            return
        }
        
        if !displayValue.contains(".") {
            displayValue += "."
            currentNumber = Double(displayValue) ?? currentNumber
            updateExpression()
        }
    }
    
    private func handleOperation(_ op: Operation) {
        if currentOperation == .none {
            previousNumber = currentNumber
            currentOperation = op
            newNumberBegan = true
            expressionText = "\(formatResult(previousNumber ?? 0)) \(symbol(for: op))"
            return
        }
        
        if newNumberBegan {
            currentOperation = op
            expressionText = "\(formatResult(previousNumber ?? currentNumber)) \(symbol(for: op))"
            return
        } else {
            if let prev = previousNumber {
                let result = evaluate(lhs: prev, rhs: currentNumber, with: currentOperation)
                
                displayValue = formatResult(result)
                currentNumber = result
                previousNumber = result
                currentOperation = op
                newNumberBegan = true
                
                expressionText = "\(formatResult(result)) \(symbol(for: op))"
            } else {
                previousNumber = currentNumber
                currentOperation = op
                newNumberBegan = true
                expressionText = "\(formatResult(previousNumber ?? 0)) \(symbol(for: op))"
            }
        }
    }
    
    private func handleEquals() {
        guard let prev = previousNumber, currentOperation != .none else { return }
        
        let secondOperand: Double = currentNumber
        let result = evaluate(lhs: prev, rhs: secondOperand, with: currentOperation)
        
        expressionText = "\(formatResult(prev)) \(symbol(for: currentOperation)) \(formatResult(secondOperand)) ="
        
        displayValue = formatResult(result)
        currentNumber = result
        previousNumber = nil
        currentOperation = .none
        newNumberBegan = true
    }
    
    private func handleClear() {
        displayValue = "0"
        resetCalculator()
    }
    
    private func handlePercent() {
        currentNumber = currentNumber / 100
        displayValue = formatResult(currentNumber)
        updateExpression()
    }
    
    private func handlePlusMinus() {
        currentNumber = currentNumber * -1
        displayValue = formatResult(currentNumber)
        updateExpression()
    }
    
    private func evaluate(lhs: Double, rhs: Double, with op: Operation) -> Double {
        switch op {
        case .add:      return lhs + rhs
        case .subtract: return lhs - rhs
        case .multiply: return lhs * rhs
        case .divide:
            if rhs == 0 {
                displayValue = "Error"
                resetCalculator()
                return 0
            }
            return lhs / rhs
        case .none:     return rhs
        }
    }
    
    private func resetCalculator() {
        currentNumber = 0
        previousNumber = nil
        currentOperation = .none
        newNumberBegan = false
        expressionText = ""
    }
    
    private func updateExpression() {
        guard currentOperation != .none else {
            expressionText = ""
            return
        }
        if newNumberBegan {
            expressionText = "\(formatResult(previousNumber ?? currentNumber)) \(symbol(for: currentOperation))"
        } else {
            expressionText = "\(formatResult(previousNumber ?? 0)) \(symbol(for: currentOperation)) \(displayValue)"
        }
    }
    
    private func symbol(for op: Operation) -> String {
        switch op {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        case .none: return ""
        }
    }
    
    private func formatResult(_ result: Double) -> String {
        if result.isNaN || result.isInfinite { return "Error" }
        if result.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", result)
        } else {
            var s = String(format: "%.7f", result)
            while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
            return s
        }
    }
}

enum CalculatorButton: Hashable {
    case digit(Int)
    case operation(Operation)
    case equals
    case clear
    case decimal
    case percent
    case plusMinus
    
    var title: String {
        switch self {
        case .digit(let int): return "\(int)"
        case .operation(let op):
            switch op {
            case .add: return "+"
            case .subtract: return "−"
            case .multiply: return "×"
            case .divide: return "÷"
            case .none: return ""
            }
        case .equals: return "="
        case .clear: return "AC"
        case .decimal: return "."
        case .percent: return "%"
        case .plusMinus: return "±"
        }
    }
}
