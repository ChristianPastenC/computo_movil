//
//  ContentView.swift
//  Calculadora
//
//  Created by Christian Pasten on 13/11/25.
//


import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CalculatorViewModel()
    
    let buttonLayout: [[CalculatorButton]] = [
        [.clear, .plusMinus, .percent, .operation(.divide)],
        [.digit(7), .digit(8), .digit(9), .operation(.multiply)],
        [.digit(4), .digit(5), .digit(6), .operation(.subtract)],
        [.digit(1), .digit(2), .digit(3), .operation(.add)],
        [.digit(0), .decimal, .equals]
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.7),
                    Color.blue.opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 12) {
                Spacer()
                
                CalculatorDisplay(
                    displayText: viewModel.displayValue,
                    expressionText: viewModel.expressionText
                )
                .padding(.horizontal)
                
                VStack(spacing: 12) {
                    ForEach(buttonLayout, id: \.self) { row in
                        HStack(spacing: 12) {
                            let activeSymbol = viewModel.currentOpSymbol
                            ForEach(row, id: \.self) { button in
                                let isActive = (button.operationSymbol == activeSymbol)
                                
                                CalculatorButtonView(
                                    button: button,
                                    isActive: isActive,
                                    displayValue: viewModel.displayValue
                                ) { pressedButton in
                                    HapticFeedbackManager.shared.generateImpactFeedback()
                                    viewModel.tapped(button: pressedButton)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 30)
        }
    }
}

struct CalculatorDisplay: View {
    let displayText: String
    let expressionText: String
    
    private let expressionRowHeight: CGFloat = 28
    private let panelMinHeight: CGFloat = 160
    
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                ExpressionChipsRow(expressionText: expressionText)
                    .frame(height: expressionRowHeight)
                    .accessibilityIdentifier("expressionChipsRow")
                
                Text(displayText)
                    .font(.system(size: 90, weight: .light))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText(value: Double(displayText) ?? 0))
                    .accessibilityIdentifier("displayValue")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 10)
        .frame(minHeight: panelMinHeight, alignment: .bottom)
    }
}

struct ExpressionChipsRow: View {
    let tokens: [ExpressionToken]
    
    init(expressionText: String) {
        self.tokens = ExpressionToken.parse(from: expressionText)
    }
    
    var body: some View {
        if tokens.isEmpty {
            Text(" ")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .opacity(0)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tokens, id: \.self) { token in
                        switch token {
                        case .operand(let t):
                            Chip(text: t, bg: .white.opacity(0.15), fg: .white)
                        case .op(let t):
                            Chip(text: t, bg: .orange.opacity(0.45), fg: .white)
                        case .equals:
                            Chip(text: "=", bg: .white.opacity(0.25), fg: .white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct Chip: View {
    let text: String
    let bg: Color
    let fg: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(.white.opacity(0.2), lineWidth: 1)
            )
    }
}

enum ExpressionToken: Hashable {
    case operand(String)
    case op(String)
    case equals
    
    static func parse(from expression: String) -> [ExpressionToken] {
        guard !expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let ops: Set<String> = ["+", "−", "×", "÷"]
        
        return expression
            .split(separator: " ")
            .map { part -> ExpressionToken in
                let s = String(part)
                if s == "=" { return .equals }
                if ops.contains(s) { return .op(s) }
                return .operand(s)
            }
    }
}

struct CalculatorButtonView: View {
    let button: CalculatorButton
    let isActive: Bool
    let displayValue: String
    let action: (CalculatorButton) -> Void
    
    private enum ButtonType {
        case digit, operation, control
    }
    
    var body: some View {
        Button(action: { action(button) }) {
            Text(buttonTitle)
                .font(.system(size: 32))
                .fontWeight(buttonType == .operation ? .semibold : .regular)
                .frame(width: buttonWidth(button), height: buttonHeight())
                .foregroundColor(buttonForegroundColor)
                .background(
                    ZStack {
                        Circle()
                            .fill(buttonBackgroundColor)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(isActive ? 0.7 : 0.4),
                                        Color.white.opacity(isActive ? 0.3 : 0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isActive ? 2.5 : 1.5
                            )
                    }
                )
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 10, x: 0, y: 10
                )
        }
        .buttonStyle(GlassPressStyle())
    }
    
    private var buttonTitle: String {
        if button == .clear { return (displayValue == "0") ? "AC" : "C" }
        return button.title
    }
    
    private var buttonType: ButtonType {
        switch button {
        case .digit, .decimal: return .digit
        case .operation, .equals: return .operation
        case .clear, .plusMinus, .percent: return .control
        }
    }
    
    private var buttonBackgroundColor: Color {
        if buttonType == .operation && isActive {
            return Color.white.opacity(0.9)
        }
        switch buttonType {
        case .digit: return Color.white.opacity(0.2)
        case .operation: return Color.orange.opacity(0.4)
        case .control: return Color.white.opacity(0.5)
        }
    }
    
    private var buttonForegroundColor: Color {
        if buttonType == .operation && isActive {
            return Color.orange
        }
        switch buttonType {
        case .control: return .black.opacity(0.8)
        default: return .white
        }
    }
    
    private func buttonWidth(_ button: CalculatorButton) -> CGFloat {
        let spacing: CGFloat = 12
        let totalPadding: CGFloat = 2 * 12
        let buttonCount: CGFloat = 4
        let diameter = (UIScreen.main.bounds.width - totalPadding - (buttonCount - 1) * spacing) / buttonCount
        if button == .digit(0) { return diameter * 2 + spacing }
        return diameter
    }
    
    private func buttonHeight() -> CGFloat {
        let spacing: CGFloat = 12
        let totalPadding: CGFloat = 2 * 12
        let buttonCount: CGFloat = 4
        return (UIScreen.main.bounds.width - totalPadding - (buttonCount - 1) * spacing) / buttonCount
    }
}

struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private init() { impactGenerator.prepare() }
    func generateImpactFeedback() {
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
    }
}

extension CalculatorButton {
    var operationSymbol: String? {
        guard case let .operation(op) = self else { return nil }
        switch op {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        case .none: return nil
        }
    }
}

#Preview {
    ContentView()
}
