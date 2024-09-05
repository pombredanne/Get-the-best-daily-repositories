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
package io.getstream.server.driven.core.designsystem.consumer

import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.getstream.server.driven.core.model.Handler
import io.getstream.server.driven.core.model.HandlerAction
import io.getstream.server.driven.core.model.HandlerType
import io.getstream.server.driven.core.model.NavigationHandler

@Composable
fun Modifier.consumeHandler(
  handler: Handler?,
  navigator: () -> Unit
): Modifier {
  if (handler == null) return this

  handler.actions.forEach { element ->
    val action =
      if (element.key == HandlerAction.NAVIGATION.value &&
        element.value == NavigationHandler.TO.value
      ) {
        { navigator }
      } else {
        {}
      }

    val newModifier = if (handler.type == HandlerType.CLICK.value) {
      Modifier.clickable { action.invoke() }
    } else {
      Modifier
    }

    then(newModifier)
  }
  return this
}
