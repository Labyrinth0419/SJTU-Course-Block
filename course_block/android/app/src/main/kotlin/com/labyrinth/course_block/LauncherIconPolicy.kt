package com.labyrinth.course_block

data class IconComponent(val name: String, val alias: Boolean, val state: Int)

object LauncherIconPolicy {
    const val DEFAULT = 0
    const val ENABLED = 1
    const val DISABLED = 2

    fun changes(
        mainActivity: String,
        defaultAlias: String,
        chosenAlias: String,
        components: List<IconComponent>,
    ): Map<String, Int> {
        val aliases = components.filter { it.alias }.map { it.name }
        require(defaultAlias in aliases && chosenAlias in aliases) { "Unknown launcher icon" }
        val changes = linkedMapOf(mainActivity to ENABLED, chosenAlias to ENABLED)
        for (component in components) {
            if (component.alias && component.name != chosenAlias) {
                changes[component.name] = DISABLED
            } else if (!component.alias && component.name != mainActivity && component.state == DISABLED) {
                // The old icon plugin disabled every real activity, not just the launcher.
                changes[component.name] = DEFAULT
            }
        }
        return changes.filter { (name, state) -> components.firstOrNull { it.name == name }?.state != state }
    }
}
