# 🍭 ComfyUI Flux Accelerator

ComfyUI Flux Acceleratorは、[ComfyUI](https://github.com/comfyanonymous/ComfyUI])用のカスタムノードです。
Flux.1をこのカスタムノードに通すだけで、画像生成を高速化できます。

<p align="center">
  <img src="./assets/sample.gif" width=60%>
</p>

## How does ComfyUI Flux Accelerator work?

ComfyUI Flux Acceleratorは以下の方法で画像生成を高速化します:

1. **[TAEF1](https://github.com/madebyollin/taesd)の使用**

    TAEF1はデフォルトと比較してパラメータサイズが小さいAEです。わずかな品質低下と引き換えに、非常に短い時間で画像をエンコード・デコードできます。

2. **量子化とコンパイル**

    [`torchao`](https://github.com/pytorch/ao)と[`torch.compile()`](https://pytorch.org/docs/stable/generated/torch.compile.html)を利用して、AEを`float8`/`int8`に量子化するほか、モデルをコンパイルすることで動作を高速化します。

3. **冗長なDiT Blocksのスキップ**

    ComfyUI Flux Acceleratorは、Flux.1内のTransformer Blockの評価を部分的にスキップするオプションを提供します。これにより、生成速度が直接的に向上します。

    当ノードのオプションでスキップするBlockのインデックスを選択できます（デフォルトはMMDiT Blocksの3,12）。

## How much faster is ComfyUI Flux Accelerator?

ComfyUI Flux Acceleratorは、デフォルト設定よりも最大で **_37.25%_** 高速に画像を生成できます。

以下にいくつかの例を示します（RTX 4090でテスト）:

### 512x512 4steps: 0.51s → 0.32s (37.25% faster)

<p align="center">
  <img src="./assets/512x512_4steps.png" width=80%>
</p>

### 1024x1024 4steps: 1.94s → 1.24s (36.08% faster)

<p align="center">
  <img src="./assets/1024x1024_4steps.png" width=80%>
</p>

### 1024x1024 20steps: 8.77s → 5.74s (34.55% faster)

<p align="center">
  <img src="./assets/1024x1024_20steps.png" width=80%>
</p>

## How to install ComfyUI Flux Accelerator?

1. **リポジトリをクローンして、ComfyUIの`custom_nodes`フォルダに配置する**

    ```bash
    git clone https://github.com/discus0434/comfyui-flux-accelerator.git
    mv comfyui-flux-accelerator custom_nodes/
    ```

2. **PyTorchとxFormersをインストール**

    ```bash
    ## Copied and modified https://github.com/facebookresearch/xformers/blob/main/README.md

    # cuda 11.8 version
    pip3 install -U torch torchvision torchao triton xformers --index-url https://download.pytorch.org/whl/cu118
    # cuda 12.1 version
    pip3 install -U torch torchvision torchao triton xformers --index-url https://download.pytorch.org/whl/cu121
    # cuda 12.4 version
    pip3 install -U torch torchvision torchao triton xformers --index-url https://download.pytorch.org/whl/cu124
    ```

3. **[TAEF1](https://github.com/madebyollin/taesd)をダウンロード**

    以下のコマンドを使用してダウンロードします。
    ```bash
    cd custom_nodes/comfyui-flux-accelerator
    chmod +x scripts/download_taef1.sh
    ./scripts/download_taef1.sh
    ```

4. **ComfyUIを起動**

    _起動コマンドは環境によって異なる場合があります。_

    **a. H100、L40、またはそれ以上に新しいGPUの場合**

    ```bash
    python main.py --fast --highvram --disable-cuda-malloc
    ```

    **b. RTX 4090の場合**

    ```bash
    python main.py --fast --highvram
    ```

    **c. その他**

    ```bash
    python main.py
    ```

5. **`workflow`フォルダ内の[ワークフロー](./workflow/flux-accelerator-workflow.json)をロード**

      ComfyUIの`Load`ボタンをクリックしてワークフローをロードできます。

6. **Enjoy!**

## How to use ComfyUI Flux Accelerator?

ワークフロー内で `FluxAccelerator` ノードを使用し、`MODEL`と`VAE`を接続するだけです。

_**もしGPUのVRAMが24GB以下の場合、パラメータの変更時頻繁にOut Of Memoryエラーに遭遇するかもしれませんが、単に無視してもう一度実行し直せば動作します。**_

## What are the limitations of ComfyUI Flux Accelerator?

ComfyUI Flux Acceleratorには以下の制限があります：

1. **品質**

    ComfyUI Flux Acceleratorは、TAEF1の使用や冗長なDiTレイヤーのスキップによって、_わずかに_ 品質を犠牲にします。高品質な画像が必要な場合は、デフォルト設定の使用をお勧めします。

2. **コンパイル時間**

    ComfyUI Flux Acceleratorは、ComfyUIの起動後、または生成解像度等の設定を変更した後の初回の画像生成時にモデルコンパイルを行いますが、その際に _30～60秒_ の時間を要します。これは、モデルを最適化するために `torch.compile()` を使用するためです。

3. **互換性**

    ComfyUI Flux Acceleratorは現在 _Linux_ のみで動作します。Windowsの場合はWSL2やDockerを使用してください。
    さらに、ControlNetやその他のカスタムノードとの互換性が保証されていません。

## ライセンス

ComfyUI Flux AcceleratorはMITライセンスの下でライセンスされています。詳細は[LICENSE](./LICENSE)をご覧ください。
