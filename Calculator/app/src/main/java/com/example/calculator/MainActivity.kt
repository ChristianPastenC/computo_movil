package com.example.calculator

import android.os.Bundle
import android.view.View
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import com.example.calculator.databinding.ActivityMainBinding
import java.math.BigDecimal
import java.text.DecimalFormat
import java.util.Stack
import kotlin.math.abs

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    /** Buffer del número que se está escribiendo actualmente */
    private var currentInput = StringBuilder()

    /** Tokens de la expresión en curso (números y operadores) */
    private val tokens = mutableListOf<Token>()

    /** Formateo amigable de números */
    private val numberFormat = DecimalFormat("#,###.########")

    /** Modelado mínimo de tokens */
    private sealed interface Token {
        data class Number(val value: Double) : Token
        data class Operator(val symbol: String, val precedence: Int) : Token
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setupListeners()
        updateDisplays()
    }

    private fun setupListeners() {
        val numberButtons = listOf(
            binding.btnZero, binding.btnOne, binding.btnTwo, binding.btnThree,
            binding.btnFour, binding.btnFive, binding.btnSix, binding.btnSeven,
            binding.btnEight, binding.btnNine
        )
        numberButtons.forEach { it.setOnClickListener { onNumberClicked(it) } }

        val operatorButtons = listOf(
            binding.btnAdd, binding.btnSubtract, binding.btnMultiply, binding.btnDivide
        )
        operatorButtons.forEach { it.setOnClickListener { onOperatorClicked(it) } }

        binding.btnClear.setOnClickListener { onClear() }
        binding.btnEquals.setOnClickListener { onEquals() }
        binding.btnDecimal.setOnClickListener { onDecimal() }
        binding.btnPercent.setOnClickListener { onPercent() }
        binding.btnToggleSign.setOnClickListener { onToggleSign() }
    }

    // --- Handlers ---

    private fun onNumberClicked(view: View) {
        val digit = (view as Button).text.toString()
        if (currentInput.toString() == "0") currentInput.clear()
        currentInput.append(digit)
        updateDisplays()
    }

    private fun onOperatorClicked(view: View) {
        val raw = (view as Button).text.toString()
        val op = toOperator(raw) ?: return

        if (currentInput.isNotEmpty() && currentInput.toString() != "-") {
            parseCurrentInput()?.let { tokens.add(Token.Number(it)) }
            currentInput.clear()
        } else if (tokens.isEmpty() && op.symbol == "-") {
            // permitir iniciar número negativo con operador menos
            if (currentInput.isEmpty()) currentInput.append("-")
            updateDisplays()
            return
        }

        // Si el último token es operador, reemplazarlo (corrección de operador)
        val last = tokens.lastOrNull()
        if (last is Token.Operator) {
            tokens[tokens.lastIndex] = op
        } else {
            tokens.add(op)
        }

        updateDisplays()
    }

    private fun onEquals() {
        val exprForPreview = buildExpressionString(includeCurrent = true)

        // Cerrar número en curso si existe
        if (currentInput.isNotEmpty() && currentInput.toString() != "-") {
            parseCurrentInput()?.let { tokens.add(Token.Number(it)) }
            currentInput.clear()
        }

        val result = evaluatePreview()
        if (result == null) {
            showError()
            return
        }

        // Mostrar preview "expr = resultado" y dejar el resultado como base
        tokens.clear()
        tokens.add(Token.Number(result))
        currentInput.clear()

        updateDisplays(
            showEqualsMark = true,
            customPreview = "$exprForPreview = ${formatNumber(result)}"
        )
    }

    private fun onClear() {
        currentInput.clear()
        tokens.clear()
        updateDisplays()
    }

    private fun onDecimal() {
        if (!currentInput.contains(".")) {
            if (currentInput.isEmpty() || currentInput.toString() == "-") {
                currentInput.append("0")
            }
            currentInput.append(".")
            updateDisplays()
        }
    }

    private fun onPercent() {
        // aplica % sobre el número que se está editando
        val v = parseCurrentInput() ?: return
        val pct = v / 100.0
        currentInput.clear().append(trimDouble(pct))
        updateDisplays()
    }

    private fun onToggleSign() {
        if (currentInput.startsWith("-")) {
            currentInput.deleteCharAt(0)
        } else {
            currentInput.insert(0, "-")
        }
        if (currentInput.toString() == "-0") currentInput.clear().append("-")
        updateDisplays()
    }

    // --- Utilidades de expresión y preview ---

    private fun toOperator(symbolRaw: String): Token.Operator? = when (symbolRaw) {
        "+", "＋" -> Token.Operator("+", 1)
        "-", "−" -> Token.Operator("-", 1)
        "x", "×" -> Token.Operator("x", 2)
        "/", "÷" -> Token.Operator("/", 2)
        else -> null
    }

    private fun parseCurrentInput(): Double? {
        if (currentInput.isEmpty() || currentInput.toString() == "-") return null
        return currentInput.toString().toDoubleOrNull()
    }

    /** Evalúa los tokens + el número en curso (si existe), ignorando un operador colgante al final. */
    private fun evaluatePreview(): Double? {
        val work = mutableListOf<Token>()
        work.addAll(tokens)

        parseCurrentInput()?.let { work.add(Token.Number(it)) }

        if (work.lastOrNull() is Token.Operator) {
            work.removeAt(work.lastIndex)
        }

        if (work.isEmpty()) return 0.0
        return evaluateWithPrecedence(work)
    }

    /** Shunting-yard (sin paréntesis) con control de división por cero */
    private fun evaluateWithPrecedence(tks: List<Token>): Double? {
        val values = Stack<Double>()
        val ops = Stack<Token.Operator>()
        var hadError = false

        fun applyOp(): Boolean {
            if (ops.isEmpty() || values.size < 2) return true
            val op = ops.pop()
            val b = values.pop()
            val a = values.pop()
            val res = when (op.symbol) {
                "+" -> a + b
                "-" -> a - b
                "x" -> a * b
                "/" -> {
                    if (abs(b) < 1e-12) {
                        hadError = true
                        return false
                    }
                    a / b
                }
                else -> return true
            }
            values.push(res)
            return true
        }

        for (tk in tks) {
            when (tk) {
                is Token.Number -> values.push(tk.value)
                is Token.Operator -> {
                    while (ops.isNotEmpty() && ops.peek().precedence >= tk.precedence) {
                        if (!applyOp()) break
                    }
                    if (hadError) break
                    ops.push(tk)
                }
            }
        }
        while (!hadError && ops.isNotEmpty()) {
            if (!applyOp()) break
        }

        if (hadError) {
            showError()
            return null
        }
        return values.lastOrNull()
    }

    private fun showError() {
        binding.tvDisplay.text = "Error"
        binding.tvPreview.text = buildExpressionString(includeCurrent = true)
    }

    /** Construye la cadena de la expresión para el preview */
    private fun buildExpressionString(includeCurrent: Boolean): String {
        val sb = StringBuilder()
        tokens.forEach { tk ->
            when (tk) {
                is Token.Number -> sb.append(formatNumber(tk.value)).append(" ")
                is Token.Operator -> {
                    val s = when (tk.symbol) {
                        "x" -> "×"
                        "/" -> "÷"
                        else -> tk.symbol
                    }
                    sb.append(s).append(" ")
                }
            }
        }
        if (includeCurrent && currentInput.isNotEmpty()) {
            sb.append(currentInput.toString())
        } else {
            if (sb.isNotEmpty() && sb[sb.lastIndex] == ' ') sb.deleteCharAt(sb.lastIndex)
        }
        return sb.toString()
    }

    private fun formatNumber(value: Double): String = numberFormat.format(value)

    private fun trimDouble(value: Double): String {
        val txt = BigDecimal.valueOf(value).stripTrailingZeros().toPlainString()
        return if (txt == "-0") "0" else txt
    }

    /**
     * Actualiza pantallas:
     * - Preview: "expresión = resultado" (si evaluable)
     * - Display principal: número en edición o resultado parcial
     */
    private fun updateDisplays(
        showEqualsMark: Boolean = false,
        customPreview: String? = null
    ) {
        if (customPreview != null) {
            binding.tvPreview.text = customPreview
        } else {
            val expr = buildExpressionString(includeCurrent = true)
            val preview = evaluatePreview()
            binding.tvPreview.text = if (expr.isBlank()) "" else {
                if (preview != null) {
                    val eq = if (showEqualsMark) " =" else " ="
                    "$expr$eq ${formatNumber(preview)}"
                } else {
                    expr
                }
            }
        }

        // Display principal
        if (currentInput.isNotEmpty()) {
            val s = currentInput.toString()
            binding.tvDisplay.text = when {
                s == "-" || s.endsWith(".") -> s
                s.toDoubleOrNull() != null -> formatNumber(s.toDouble())
                else -> s
            }
        } else {
            val preview = evaluatePreview()
            binding.tvDisplay.text = preview?.let { formatNumber(it) } ?: "0"
        }
    }
}
