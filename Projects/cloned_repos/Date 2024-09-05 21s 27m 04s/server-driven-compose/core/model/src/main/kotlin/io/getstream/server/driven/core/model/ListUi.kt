/*
 * Designed and developed by 2024 skydoves (Jaewoong Eum)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.getstream.server.driven.core.model

import androidx.compose.runtime.Immutable
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

@Immutable
@Serializable
data class ListUi(
  val layout: String,
  val itemSize: DpSizeUi,
  val items: List<ImageUi>,
  val handler: Handler? = null,
  val extra: Map<String, JsonElement> = mapOf()
) : UiComponent

fun String.toLayoutType(): LayoutType {
  return if (this == "grid") LayoutType.GRID
  else if (this == "column") LayoutType.COLUMN
  else LayoutType.ROW
}

enum class LayoutType(val value: String) {
  GRID("grid"), COLUMN("column"), ROW("row")
}
