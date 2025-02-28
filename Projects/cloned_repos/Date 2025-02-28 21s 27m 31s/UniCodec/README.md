# UniCodec

> [**UniCodec: Unified Audio Codec with Single Domain-Adaptive Codebook**](https://arxiv.org/abs/2502.20067)<br>
> [Yidi Jiang](https://scholar.google.com/citations?user=le6gC58AAAAJ&hl=en&oi=ao),[Qian Chen](https://scholar.google.com/citations?user=8eosmSQAAAAJ&hl=en&oi=ao),[Shengpeng Ji](https://scholar.google.com/citations?user=zuRaB-oAAAAJ&hl=en&oi=ao),[Yu Xi](https://scholar.google.com/citations?user=dszdUXYAAAAJ&hl=zh-CN),[Wen Wang](https://scholar.google.com.hk/citations?user=85Tj1OwAAAAJ&hl=en),[Chong Zhang](https://scholar.google.com.sg/citations?user=nqcBaoYAAAAJ&hl=en),[Xianghu Yue](https://scholar.google.com/citations?user=jWNJCDIAAAAJ&hl=en),[Shiliang Zhang](https://scholar.google.com/citations?user=BcWMSE4AAAAJ&hl=zh-CN),[Haizhou Li](https://colips.org/~eleliha/)<br>
> National University of Singapore; Tongyi Speech Lab<br>

In this work, we introduce **UniCodec**, a unified audio codec with a single codebook to support multi-domain audio data, including **speech**, **music**, and **sound**. 

![comparison](https://github.com/Jiang-Yidi/UniCodec/blob/main/comparison%20table.png)

To achieve this, we propose a **partitioned domain-adaptive codebook** method with **domain Mixture-of-Experts** strategy to capture the distinct characteristics of each audio domain. Furthermore, to enrich the semantic density of the codec **without auxiliary modules**, we propose a self-supervised mask prediction modeling approach. 

<div align=center>
<img src="https://github.com/Jiang-Yidi/UniCodec/blob/main/overview.png" width="50%">
</div>

As a single unified codec model, UniCodec achieves **superior subjective reconstruction performance** while maintaining a **high compression rate** in all three domains (speech/music/sound).

![main](https://github.com/Jiang-Yidi/UniCodec/blob/main/main%20result.png)
