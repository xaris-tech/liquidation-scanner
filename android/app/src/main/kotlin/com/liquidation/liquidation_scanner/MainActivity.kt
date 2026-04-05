package com.liquidation.liquidation_scanner

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.liquidation.liquidation_scanner/llm"
    private var isInitialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    isInitialized = true
                    result.success("Native LLM initialized")
                }
                "generate" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt != null) {
                        val response = extractReceiptData(prompt)
                        result.success(response)
                    } else {
                        result.error("INVALID_ARGUMENT", "Prompt is null", null)
                    }
                }
                "dispose" -> {
                    isInitialized = false
                    result.success("Native LLM disposed")
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extractReceiptData(text: String): String {
        Log.i("NativeLLM", "═══════════════════════════════════════════════════════")
        Log.i("NativeLLM", "📥 INPUT RECEIVED: ${text.length} chars")
        Log.i("NativeLLM", "═══════════════════════════════════════════════════════")

        // Extract only the actual receipt text (skip the prompt if present)
        var receiptText = text
        
        // Find the actual receipt text after "Extract" 
        val extractIndex = text.indexOf("Extract", ignoreCase = true)
        if (extractIndex >= 0) {
            // Get everything after "Extract..." instruction line
            val afterExtract = text.substring(extractIndex)
            val newlineIndex = afterExtract.indexOf('\n')
            if (newlineIndex > 0) {
                receiptText = afterExtract.substring(newlineIndex + 1).trim()
            }
        }
        
        Log.i("NativeLLM", "───────────────────────────────────────────────────────")
        Log.i("NativeLLM", "📄 RECEIPT TEXT TO PARSE:")
        Log.i("NativeLLM", receiptText.take(300))
        if (receiptText.length > 300) {
            Log.i("NativeLLM", "... [${receiptText.length - 300} more chars]")
        }
        Log.i("NativeLLM", "───────────────────────────────────────────────────────")

        val lines = receiptText.split("\n").filter { it.isNotBlank() }

        var vendor: String? = null
        var total: Double? = null
        var date: String? = null
        val items = mutableListOf<String>()
        val skipWords = listOf("subtotal", "total", "tax", "discount", "payment", "vat", "thank you", "receipt", "vendor", "store name", "amount", "date", "extract", "json")

        Log.i("NativeLLM", "───────────────────────────────────────────────────────")
        Log.i("NativeLLM", "🔍 PROCESSING ${lines.size} LINES:")
        
        for (line in lines) {
            val lowerLine = line.lowercase()

            if (total == null && lowerLine.contains("total") && !lowerLine.contains("subtotal")) {
                val match = Regex("(\\d+[.,]\\d{2})").find(line)
                if (match != null) {
                    total = match.value.replace(",", ".").toDoubleOrNull()
                    Log.i("NativeLLM", "   ✅ Found TOTAL: $total")
                }
            }

            if (date == null) {
                val dateMatch = Regex("(\\d{1,2}/\\d{1,2}/\\d{2,4})").find(line)
                if (dateMatch != null) {
                    date = dateMatch.value
                    Log.i("NativeLLM", "   ✅ Found DATE: $date")
                }
            }

            // Better vendor detection - look for store-like lines
            if (vendor == null && line.length > 3 && line.length < 40) {
                val cleaned = line.replace(Regex("[^a-zA-Z0-9\\s]"), "").trim()
                if (cleaned.isNotEmpty() && 
                    !skipWords.any { cleaned.lowercase().contains(it) } &&
                    !cleaned.contains(Regex("^\\d+$")) &&
                    !cleaned.contains(Regex("\\d{4,}")) &&
                    cleaned.length > 4) {
                    vendor = cleaned
                    Log.i("NativeLLM", "   ✅ Found VENDOR: $vendor")
                }
            }

            val itemMatch = Regex("(.+)\\s+(\\d+[.,]\\d{2,3})$").find(line)
            if (itemMatch != null) {
                val name = itemMatch.groupValues[1].trim()
                val price = itemMatch.groupValues[2].replace(",", ".").toDoubleOrNull()
                if (name.length > 2 && price != null && price > 0 && price < 10000 && !skipWords.any { name.lowercase().contains(it) }) {
                    items.add("{\"name\":\"${name.replace("\"", "'")}\",\"price\":$price}")
                    Log.i("NativeLLM", "   ✅ Found ITEM: $name = $price")
                }
            }
        }

        if (items.isNotEmpty() && total == null) {
            total = items.mapNotNull {
                val priceMatch = Regex("\"price\":([\\d.]+)").find(it)
                priceMatch?.groupValues?.get(1)?.toDoubleOrNull()
            }.sum()
            Log.i("NativeLLM", "   ✅ Calculated TOTAL from items: $total")
        }

        Log.i("NativeLLM", "───────────────────────────────────────────────────────")
        Log.i("NativeLLM", "📤 OUTPUT JSON:")
        
        val result = """
        {
            "vendor": "${vendor ?: ""}",
            "amount": ${total ?: 0.0},
            "date": "${date ?: ""}",
            "items": [${items.joinToString(",")}]
        }
        """.trimIndent()
        
        Log.i("NativeLLM", result)
        Log.i("NativeLLM", "═══════════════════════════════════════════════════════")
        
        return result
    }
}
