package com.labyrinth.course_block.widget

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import com.labyrinth.course_block.R
import kotlin.math.roundToInt

/** 小组件主题色与课程回退色，按应用主题方案同步。 */
object WidgetColors {

    private const val COURSE_COLOR_TOKEN_PREFIX = "palette:"
    private const val COURSE_COLOR_AUTO_PREFIX = "auto:"
    private const val COURSE_COLOR_POOL_PREFIX = "pool:"
    private val LEGACY_COURSE_COLORS = listOf(
        "#FF758F",
        "#9B9BFF",
        "#4ADBC8",
        "#FF9F46",
        "#A06CD5",
        "#FFB7B2",
        "#B5EAD7",
        "#C7CEEA",
        "#E2F0CB",
        "#FFDAC1",
        "#FF9AA2",
        "#6EB5FF",
    )

    data class PoolSelection(
        val slot: Int,
        val variant: Int = 0,
    )

    data class WidgetTheme(
        val isDark: Boolean,
        val backgroundRes: Int,
        val headerText: Int,
        val subtitleText: Int,
        val courseTitle: Int,
        val courseDetail: Int,
        val divider: Int,
        val emptyText: Int,
        val accent: Int,
        val openText: Int,
        val coursePalette: IntArray,
    )

    fun resolve(context: Context, prefs: SharedPreferences): WidgetTheme {
        val mode = prefs.getString("theme_mode", "system")
        val isDark = when (mode) {
            "light" -> false
            "dark" -> true
            else -> {
                val nightMode = context.resources.configuration.uiMode and
                        Configuration.UI_MODE_NIGHT_MASK
                nightMode == Configuration.UI_MODE_NIGHT_YES
            }
        }

        val baseTheme = when (prefs.getString("theme_scheme", "morning_mist")) {
            "spring_bud" -> if (isDark) springBudDark else springBudLight
            "apricot_glow" -> if (isDark) apricotGlowDark else apricotGlowLight
            "sakura_mist" -> if (isDark) sakuraMistDark else sakuraMistLight
            "tokyo_night" -> if (isDark) tokyoNightDark else tokyoNightLight
            else -> if (isDark) morningMistDark else morningMistLight
        }

        val rawCoursePalette = when (prefs.getString("course_palette", "candy_box")) {
            "mildliner_notes" -> mildlinerNotesPalette
            "jelly_soda" -> jellySodaPalette
            "tokyo_neon" -> tokyoNeonPalette
            else -> candyBoxPalette
        }

        return baseTheme.copy(
            coursePalette = balanceCoursePalette(rawCoursePalette, isDark)
        )
    }

    /** 根据课程名 hash 返回主题调板中的颜色；若 payload 自带颜色则优先使用。 */
    fun forCourse(name: String, theme: WidgetTheme, colorHex: String? = null): Int {
        resolveStoredSelection(colorHex, theme.coursePalette.size)?.let {
            return deriveOverflowPoolColor(
                palette = theme.coursePalette,
                slot = it.slot,
                variant = it.variant,
                isDark = theme.isDark,
            )
        }
        parseFixedColor(colorHex)?.let { return it }

        val hash = parseAutoColorHash(colorHex) ?: stableCourseColorHash(name.trim().lowercase())
        return generateLegacyCoursePaletteColor(theme.coursePalette, hash, theme.isDark)
    }

    /** 返回指定 alpha (0-255) 的半透明版本。 */
    fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))

    fun upcomingFill(theme: WidgetTheme, courseColor: Int): Int =
        withAlpha(courseColor, if (theme.isDark) 74 else 51)

    fun doneBackground(theme: WidgetTheme): Int =
        withAlpha(theme.subtitleText, if (theme.isDark) 52 else 24)

    fun doneText(theme: WidgetTheme): Int =
        withAlpha(theme.subtitleText, if (theme.isDark) 210 else 160)

    private fun resolveStoredSelection(colorValue: String?, paletteSize: Int): PoolSelection? {
        if (colorValue.isNullOrBlank() || paletteSize <= 0) {
            return null
        }

        parsePoolSelection(colorValue)?.let {
            return PoolSelection(
                slot = ((it.slot % paletteSize) + paletteSize) % paletteSize,
                variant = if (it.variant < 0) 0 else it.variant,
            )
        }

        if (colorValue.startsWith(COURSE_COLOR_TOKEN_PREFIX)) {
            val index = colorValue
                .removePrefix(COURSE_COLOR_TOKEN_PREFIX)
                .toIntOrNull()
                ?: return null
            val normalizedIndex = ((index % paletteSize) + paletteSize) % paletteSize
            return PoolSelection(slot = normalizedIndex, variant = 0)
        }

        val legacyIndex = LEGACY_COURSE_COLORS.indexOfFirst {
            it.equals(colorValue, ignoreCase = true)
        }
        if (legacyIndex >= 0) {
            return PoolSelection(slot = legacyIndex % paletteSize, variant = 0)
        }

        return null
    }

    private fun parsePoolSelection(colorValue: String?): PoolSelection? {
        if (colorValue.isNullOrBlank() || !colorValue.startsWith(COURSE_COLOR_POOL_PREFIX)) {
            return null
        }

        val parts = colorValue.removePrefix(COURSE_COLOR_POOL_PREFIX).split(':')
        if (parts.isEmpty() || parts.size > 2) {
            return null
        }

        val slot = parts[0].toIntOrNull() ?: return null
        val variant = if (parts.size == 2) {
            parts[1].toIntOrNull() ?: return null
        } else {
            0
        }
        return PoolSelection(slot = slot, variant = variant)
    }

    private fun parseAutoColorHash(colorValue: String?): Int? {
        if (colorValue.isNullOrBlank() || !colorValue.startsWith(COURSE_COLOR_AUTO_PREFIX)) {
            return null
        }
        return colorValue
            .removePrefix(COURSE_COLOR_AUTO_PREFIX)
            .toLongOrNull(16)
            ?.toInt()
    }

    private fun parseFixedColor(colorHex: String?): Int? {
        if (colorHex.isNullOrBlank() || !colorHex.startsWith("#")) {
            return null
        }
        return runCatching { Color.parseColor(colorHex) }.getOrNull()
    }

    private fun stableCourseColorHash(seed: String): Int {
        var hash = 0x811C9DC5L
        for (char in seed) {
            hash = hash xor char.code.toLong()
            hash = (hash * 0x01000193L) and 0xFFFFFFFFL
        }
        return (hash and 0x7FFFFFFFL).toInt()
    }

    private fun generateLegacyCoursePaletteColor(
        palette: IntArray,
        hash: Int,
        isDark: Boolean,
    ): Int {
        if (palette.isEmpty()) {
            return if (isDark) {
                Color.parseColor("#82AAFF")
            } else {
                Color.parseColor("#4C82C3")
            }
        }
        if (palette.size == 1) {
            return palette[0]
        }

        val primaryIndex = hash % palette.size
        val secondaryDistance = 1 + ((hash ushr 3) % (palette.size - 1))
        val secondaryIndex = (primaryIndex + secondaryDistance) % palette.size
        val mix = 0.18f + (((hash ushr 8) and 0xFF) / 255f) * 0.64f
        val blended = blendColors(palette[primaryIndex], palette[secondaryIndex], mix)

        val hsv = FloatArray(3)
        Color.colorToHSV(blended, hsv)
        val hueShift = ((((hash ushr 16) and 0xFF) / 255f) - 0.5f) * 24f
        val saturationShift = ((((hash ushr 24) and 0x0F) / 15f) - 0.5f) * 0.20f
        val valueShift = ((((hash ushr 28) and 0x07) / 7f) - 0.5f) * if (isDark) 0.14f else 0.12f

        hsv[0] = ((hsv[0] + hueShift) % 360f + 360f) % 360f
        hsv[1] = (hsv[1] + saturationShift).coerceIn(
            if (isDark) 0.48f else 0.44f,
            if (isDark) 0.88f else 0.84f,
        )
        hsv[2] = (hsv[2] + valueShift).coerceIn(
            if (isDark) 0.72f else 0.68f,
            if (isDark) 0.96f else 0.94f,
        )
        return balanceCourseColorDynamics(Color.HSVToColor(hsv), isDark)
    }

    private fun deriveOverflowPoolColor(
        palette: IntArray,
        slot: Int,
        variant: Int,
        isDark: Boolean,
    ): Int {
        val base = palette[slot % palette.size]
        if (variant <= 0 || palette.size == 1) {
            return base
        }

        val neighbor = palette[(slot + variant) % palette.size]
        val mix = (0.18f + ((variant - 1) % 4) * 0.12f).coerceIn(0.18f, 0.54f)
        val blended = blendColors(base, neighbor, mix)
        val hsv = FloatArray(3)
        Color.colorToHSV(blended, hsv)
        val cycle = (variant - 1) % 4
        val band = (variant - 1) / 4
        val hueBase = floatArrayOf(10f, -12f, 18f, -20f)[cycle]
        val saturationBase = floatArrayOf(0.06f, -0.05f, 0.04f, -0.07f)[cycle]
        val valueBase = if (isDark) {
            floatArrayOf(0.08f, -0.04f, 0.12f, -0.08f)[cycle]
        } else {
            floatArrayOf(0.06f, -0.05f, 0.10f, -0.09f)[cycle]
        }

        hsv[0] = ((hsv[0] + hueBase + band * 6f) % 360f + 360f) % 360f
        hsv[1] = (hsv[1] + saturationBase - band * 0.01f).coerceIn(
            if (isDark) 0.46f else 0.42f,
            if (isDark) 0.90f else 0.86f,
        )
        hsv[2] = (hsv[2] + valueBase - band * 0.015f).coerceIn(
            if (isDark) 0.70f else 0.66f,
            if (isDark) 0.97f else 0.95f,
        )
        return balanceCourseColorDynamics(Color.HSVToColor(hsv), isDark)
    }

    private fun blendColors(start: Int, end: Int, amount: Float): Int {
        val t = amount.coerceIn(0f, 1f)
        val r = (Color.red(start) + (Color.red(end) - Color.red(start)) * t).roundToInt()
        val g = (Color.green(start) + (Color.green(end) - Color.green(start)) * t).roundToInt()
        val b = (Color.blue(start) + (Color.blue(end) - Color.blue(start)) * t).roundToInt()
        return Color.rgb(r, g, b)
    }

    private fun balanceCoursePalette(palette: IntArray, isDark: Boolean): IntArray =
        IntArray(palette.size) { index ->
            balanceCourseColorDynamics(palette[index], isDark)
        }

    private fun balanceCourseColorDynamics(color: Int, isDark: Boolean): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        if (shouldPreserveMutedCourseTone(hsv)) {
            return color
        }

        val saturationCenter = if (isDark) 0.70f else 0.68f
        val saturationScale = if (isDark) 0.66f else 0.60f
        val valueCenter = if (isDark) 0.80f else 0.76f
        val valueScale = if (isDark) 0.42f else 0.36f

        hsv[1] = (saturationCenter + (hsv[1] - saturationCenter) * saturationScale).coerceIn(
            if (isDark) 0.52f else 0.50f,
            if (isDark) 0.82f else 0.78f,
        )
        hsv[2] = (valueCenter + (hsv[2] - valueCenter) * valueScale).coerceIn(
            if (isDark) 0.74f else 0.68f,
            if (isDark) 0.88f else 0.82f,
        )
        return Color.HSVToColor(hsv)
    }

    private fun shouldPreserveMutedCourseTone(hsv: FloatArray): Boolean =
        hsv[1] <= 0.12f || (hsv[1] <= 0.32f && hsv[2] <= 0.54f)

    private fun theme(
        isDark: Boolean,
        headerText: String,
        subtitleText: String,
        divider: String,
        emptyText: String,
        accent: String,
        openText: String,
        palette: IntArray,
    ) = WidgetTheme(
        isDark = isDark,
        backgroundRes = if (isDark) R.drawable.widget_today_bg_dark else R.drawable.widget_today_bg,
        headerText = Color.parseColor(headerText),
        subtitleText = Color.parseColor(subtitleText),
        courseTitle = Color.parseColor(headerText),
        courseDetail = Color.parseColor(subtitleText),
        divider = Color.parseColor(divider),
        emptyText = Color.parseColor(emptyText),
        accent = Color.parseColor(accent),
        openText = Color.parseColor(openText),
        coursePalette = palette,
    )

    private val mildlinerNotesPalette = intArrayOf(
        Color.parseColor("#D38A5C"),
        Color.parseColor("#C9A23F"),
        Color.parseColor("#90A94B"),
        Color.parseColor("#57A79B"),
        Color.parseColor("#6C98CF"),
        Color.parseColor("#9A85D6"),
        Color.parseColor("#D578A0"),
        Color.parseColor("#B6885E"),
        Color.parseColor("#E3A06A"),
        Color.parseColor("#D5B85A"),
        Color.parseColor("#A8B85A"),
        Color.parseColor("#69B88F"),
        Color.parseColor("#78B8B8"),
        Color.parseColor("#7DA8E0"),
        Color.parseColor("#B08FE5"),
        Color.parseColor("#DF8CB3"),
        Color.parseColor("#C59A74"),
        Color.parseColor("#8AB47C"),
    )

    private val candyBoxPalette = intArrayOf(
        Color.parseColor("#FF7B9C"),
        Color.parseColor("#FFB347"),
        Color.parseColor("#62C770"),
        Color.parseColor("#58B8FF"),
        Color.parseColor("#9B7BFF"),
        Color.parseColor("#FF8A65"),
        Color.parseColor("#44CFBF"),
        Color.parseColor("#F06CC6"),
        Color.parseColor("#FFD95A"),
        Color.parseColor("#9ADB5B"),
        Color.parseColor("#7BE495"),
        Color.parseColor("#67DDE6"),
        Color.parseColor("#7CA9FF"),
        Color.parseColor("#B88CFF"),
        Color.parseColor("#FF9DC2"),
        Color.parseColor("#FFAE7A"),
        Color.parseColor("#57E0A6"),
        Color.parseColor("#FF6FB5"),
    )

    private val jellySodaPalette = intArrayOf(
        Color.parseColor("#FF5D73"),
        Color.parseColor("#FF9F1C"),
        Color.parseColor("#2EC4B6"),
        Color.parseColor("#3A86FF"),
        Color.parseColor("#8338EC"),
        Color.parseColor("#FB5607"),
        Color.parseColor("#06D6A0"),
        Color.parseColor("#5E60CE"),
        Color.parseColor("#FF006E"),
        Color.parseColor("#FFBE0B"),
        Color.parseColor("#38B000"),
        Color.parseColor("#00BBF9"),
        Color.parseColor("#6A4CFF"),
        Color.parseColor("#FF7F51"),
        Color.parseColor("#00F5D4"),
        Color.parseColor("#4361EE"),
        Color.parseColor("#F72585"),
        Color.parseColor("#4CC9F0"),
    )

    private val tokyoNeonPalette = intArrayOf(
        Color.parseColor("#4C6EF5"),
        Color.parseColor("#7C63FF"),
        Color.parseColor("#159DB2"),
        Color.parseColor("#2FB7A8"),
        Color.parseColor("#9A67EA"),
        Color.parseColor("#3B5CCC"),
        Color.parseColor("#1F8EA3"),
        Color.parseColor("#F4B86A"),
        Color.parseColor("#82AAFF"),
        Color.parseColor("#6BE6FF"),
        Color.parseColor("#6CF2C2"),
        Color.parseColor("#B08CFF"),
        Color.parseColor("#2C7BE5"),
        Color.parseColor("#00BFA6"),
        Color.parseColor("#F7C66F"),
        Color.parseColor("#FF9E64"),
        Color.parseColor("#4DD2FF"),
        Color.parseColor("#C099FF"),
    )

    private val morningMistLight = theme(
        isDark = false,
        headerText = "#1B2238",
        subtitleText = "#66708A",
        divider = "#D1D9EA",
        emptyText = "#8A96B0",
        accent = "#7E96F0",
        openText = "#4C82C3",
        palette = candyBoxPalette,
    )

    private val morningMistDark = theme(
        isDark = true,
        headerText = "#E8ECF8",
        subtitleText = "#ABB4CE",
        divider = "#3A435E",
        emptyText = "#6F7A96",
        accent = "#9EB2FF",
        openText = "#82AAFF",
        palette = candyBoxPalette,
    )

    private val springBudLight = theme(
        isDark = false,
        headerText = "#1A3026",
        subtitleText = "#587266",
        divider = "#CFE2D8",
        emptyText = "#7C978B",
        accent = "#58B889",
        openText = "#449F78",
        palette = candyBoxPalette,
    )

    private val springBudDark = theme(
        isDark = true,
        headerText = "#E6F3EC",
        subtitleText = "#A4C2B4",
        divider = "#385046",
        emptyText = "#7E998D",
        accent = "#7ED1A4",
        openText = "#6ECBB6",
        palette = candyBoxPalette,
    )

    private val apricotGlowLight = theme(
        isDark = false,
        headerText = "#362313",
        subtitleText = "#7A6352",
        divider = "#E7D6C8",
        emptyText = "#9A7F6D",
        accent = "#E59A5C",
        openText = "#D9785D",
        palette = candyBoxPalette,
    )

    private val apricotGlowDark = theme(
        isDark = true,
        headerText = "#F8ECE3",
        subtitleText = "#CBB3A2",
        divider = "#564437",
        emptyText = "#A58B7C",
        accent = "#F0AF78",
        openText = "#E48B8B",
        palette = candyBoxPalette,
    )

    private val sakuraMistLight = theme(
        isDark = false,
        headerText = "#36212B",
        subtitleText = "#7D6370",
        divider = "#E7D5DD",
        emptyText = "#9B7F8D",
        accent = "#D98AA4",
        openText = "#A59AE6",
        palette = candyBoxPalette,
    )

    private val sakuraMistDark = theme(
        isDark = true,
        headerText = "#F8EAF0",
        subtitleText = "#C7AFBA",
        divider = "#5A4450",
        emptyText = "#A18793",
        accent = "#E2A5BA",
        openText = "#B7AEF1",
        palette = candyBoxPalette,
    )

    private val tokyoNightLight = theme(
        isDark = false,
        headerText = "#161B2C",
        subtitleText = "#4F5A77",
        divider = "#BEC7DA",
        emptyText = "#74809D",
        accent = "#4C6EF5",
        openText = "#2C7BE5",
        palette = candyBoxPalette,
    )

    private val tokyoNightDark = theme(
        isDark = true,
        headerText = "#C8D3F5",
        subtitleText = "#7D8AB3",
        divider = "#2E3550",
        emptyText = "#59688D",
        accent = "#82AAFF",
        openText = "#41C7D9",
        palette = candyBoxPalette,
    )
}
