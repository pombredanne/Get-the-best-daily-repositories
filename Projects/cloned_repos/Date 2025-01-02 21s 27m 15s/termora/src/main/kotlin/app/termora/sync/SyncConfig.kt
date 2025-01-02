package app.termora.sync

enum class SyncType {
    GitLab,
    GitHub,
    Gitee,
}

enum class SyncRange {
    Hosts,
    KeyPairs,
    KeywordHighlights,
    Macros,
}

data class SyncConfig(
    val type: SyncType,
    val token: String,
    val gistId: String,
    val options: Map<String, String>,
    val ranges: Set<SyncRange> = setOf(SyncRange.Hosts, SyncRange.KeyPairs, SyncRange.KeywordHighlights),
)

data class GistFile(
    val filename: String,
    val content: String
)

data class GistResponse(
    val config: SyncConfig,
    val gists: List<GistFile>
)