package com.labyrinth.course_block.widget

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import com.labyrinth.course_block.R
import kotlin.math.abs

/** 小组件主题色与课程回退色，按应用主题方案同步。 */
object WidgetColors {

    private const val COURSE_COLOR_TOKEN_PREFIX = "palette:"
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

        return baseTheme.copy(
            coursePalette = when (prefs.getString("course_palette", "candy_box")) {
                "mildliner_notes" -> mildlinerNotesPalette
                "jelly_soda" -> jellySodaPalette
                "tokyo_neon" -> tokyoNeonPalette
                else -> candyBoxPalette
            }
        )
    }

    /** 根据课程名 hash 返回主题调板中的颜色；若 payload 自带颜色则优先使用。 */
    fun forCourse(name: String, theme: WidgetTheme, colorHex: String? = null): Int {
        resolvePaletteColor(colorHex, theme.coursePalette)?.let { return it }
        parseFixedColor(colorHex)?.let { return it }
        return theme.coursePalette[abs(name.hashCode()) % theme.coursePalette.size]
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

    private fun resolvePaletteColor(colorValue: String?, palette: IntArray): Int? {
        if (colorValue.isNullOrBlank()) {
            return null
        }

        if (colorValue.startsWith(COURSE_COLOR_TOKEN_PREFIX)) {
            val index = colorValue
                .removePrefix(COURSE_COLOR_TOKEN_PREFIX)
                .toIntOrNull()
                ?: return null
            val normalizedIndex = ((index % palette.size) + palette.size) % palette.size
            return palette[normalizedIndex]
        }

        val legacyIndex = LEGACY_COURSE_COLORS.indexOfFirst {
            it.equals(colorValue, ignoreCase = true)
        }
        if (legacyIndex >= 0) {
            return palette[legacyIndex % palette.size]
        }

        return null
    }

    private fun parseFixedColor(colorHex: String?): Int? {
        if (colorHex.isNullOrBlank() || !colorHex.startsWith("#")) {
            return null
        }
        return runCatching { Color.parseColor(colorHex) }.getOrNull()
    }

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
