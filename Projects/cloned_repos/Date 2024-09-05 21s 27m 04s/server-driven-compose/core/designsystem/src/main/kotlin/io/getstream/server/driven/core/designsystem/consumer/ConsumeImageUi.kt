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

import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.skydoves.landscapist.ImageOptions
import com.skydoves.landscapist.components.rememberImageComponent
import com.skydoves.landscapist.glide.GlideImage
import com.skydoves.landscapist.placeholder.shimmer.Shimmer
import com.skydoves.landscapist.placeholder.shimmer.ShimmerPlugin
import io.getstream.server.driven.core.designsystem.R
import io.getstream.server.driven.core.designsystem.extension.size
import io.getstream.server.driven.core.designsystem.preview.MockUtils
import io.getstream.server.driven.core.designsystem.theme.ServerDrivenTheme
import io.getstream.server.driven.core.designsystem.version.UiVersion
import io.getstream.server.driven.core.model.ImageUi
import io.getstream.server.driven.core.model.UiComponent

@Composable
fun ConsumeImageUi(
  imageUi: ImageUi,
  modifier: Modifier = Modifier,
  version: UiVersion,
  navigator: (UiComponent) -> Unit = {},
  imageOptions: ImageOptions? = null
) {
  val newModifier = if (version == UiVersion.VERSION_1_0) {
    modifier
      .consumeHandler(
        handler = imageUi.handler,
        navigator = { navigator.invoke(imageUi) }
      )
      .size(imageUi.size)
      .clip(RoundedCornerShape(8.dp))
  } else {
    modifier
      .consumeHandler(
        handler = imageUi.handler,
        navigator = { navigator.invoke(imageUi) }
      )
      .size(imageUi.size)
      .clip(RoundedCornerShape(16.dp))
      .border(
        width = 4.dp,
        color = ServerDrivenTheme.colors.primary,
        shape = RoundedCornerShape(16.dp)
      )
  }

  GlideImage(
    modifier = newModifier
      .size(imageUi.size)
      .clip(RoundedCornerShape(8.dp)),
    imageModel = { imageUi.url },
    imageOptions = imageOptions ?: ImageOptions(
      contentScale = imageUi.scaleType.toContentScale(),
      contentDescription = imageUi.title
    ),
    component = rememberImageComponent {
      +ShimmerPlugin(
        Shimmer.Resonate(
          baseColor = ServerDrivenTheme.colors.shimmerBase,
          highlightColor = ServerDrivenTheme.colors.shimmerHighlight
        )
      )
    },
    previewPlaceholder = painterResource(R.drawable.preview)
  )
}

@Preview
@Composable
private fun ConsumeImageUiV1Preview() {
  ServerDrivenTheme {
    ConsumeImageUi(imageUi = MockUtils.mockImageUi, version = UiVersion.VERSION_1_0)
  }
}

@Preview
@Composable
private fun ConsumeImageUiV2Preview() {
  ServerDrivenTheme {
    ConsumeImageUi(imageUi = MockUtils.mockImageUi, version = UiVersion.VERSION_2_0)
  }
}
