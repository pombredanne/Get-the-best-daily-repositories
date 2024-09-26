# 数据格式

TorchEasyRec作为阿里云PAI的推荐算法包，可以无缝对接MaxCompute的数据表，也可以读取OSS、NAS或Local环境中的CSV, Parquet文件。

## DataConfig

**一个最简单的data config的配置**

这个配置里面，读取MaxCompute的表作为输入数据（OdpsDataset），并且输入数据已经编码好（fg_encoded），每个worker上以8192的batch_size，并行度为8来读取数据

```
data_config {
    batch_size: 8192
    dataset_type: OdpsDataset
    fg_encoded: true
    label_fields: "clk"
    num_workers: 8
}
```

### dataset_type

目前支持一下几种[input_type](../proto.html#tzrec.protos.DatasetType):

- OdpsDataset: 输入数据为MaxCompute表

  - **前置条件**:
    - 在[MaxCompute控制台](https://maxcompute.console.aliyun.com/)的「租户管理」->「租户属性」页面打开**开放存储(Storage API)开关**
    - 「租户管理」->「新增成员」给相应用户授予「admin」权限；或参考[租户权限](https://help.aliyun.com/zh/maxcompute/user-guide/perform-access-control-based-on-tenant-level-roles#section-mt7-tmu-f49)文档，编写如下Policy，精细授予用户Quota的使用权限
    ```
    {
        "Version": "1",
        "Statement": [
            {
                "Action": "odps:Usage",
                "Effect": "Allow",
                "Resource": [
                    "acs:odps:*:regions/*/quotas/pay-as-you-go"
                ]
            }
        ]
    }
    ```
  - input_path: 按如下格式设置
    - `odps://{project}/tables/{table_name}/{partition}`，多表按逗号分隔
    - 如果单表需要设置多个分区，可以用`&`简写，来分隔多个分区，`odps://{project}/tables/{table_name}/{partition1}&{partition2}`
  - 运行训练/评估/导出/预测等命令时
    - **本地环境 或 召回算法**：
      - 需要准备一个odps_conf文件，并在启动命令中设置在`ODPS_CONFIG_FILE_PATH`环境变量中
      ```bash
      cat << EOF >> odps_conf
      project_name=${PROJECT_NAME}
      access_id=${ACCESS_ID}
      access_key=${ACCESS_KEY}
      end_point=http://service.{region}.maxcompute.aliyun-inc.com/api
      EOF

      ODPS_CONFIG_FILE_PATH=odps_conf \
      torchrun --master_addr=$MASTER_ADDR --master_port=$MASTER_PORT \
      --nnodes=$WORLD_SIZE --nproc-per-node=$NPROC_PER_NODE --node_rank=$RANK \
      -m tzrec.train_eval \
      --pipeline_config_path ${PIPELINE_CONFIG}
      ```
    - **PAI-DLC/PAI-DSW环境**：
      - 需要设置`ODPS_ENDPOINT`的环境变量，并新建任务时，「角色信息」选择**PAI默认角色**
      ```bash
      ODPS_ENDPOINT=http://service.{region}.maxcompute.aliyun-inc.com/api \
      torchrun --master_addr=$MASTER_ADDR --master_port=$MASTER_PORT \
      --nnodes=$WORLD_SIZE --nproc-per-node=$NPROC_PER_NODE --node_rank=$RANK \
      -m tzrec.train_eval \
      --pipeline_config_path ${PIPELINE_CONFIG}
      ```
  - 如果是预付费Quota，可通过`odps_data_quota_name`传入购买的Quota名

- ParquetDataset: 输入数据为parquet格式

  - input_path: 按如下格式设置
    - `${PATH_TO_DATA_DIR}/*.parquet`
  - 注意: 训练和评估时需要csv文件数是 `nproc-per-node * nnodes * num_workers`的倍数，并且每个parquet文件的数据量基本相等

- CsvDataset: 输入数据为csv格式

  - input_path: 按如下格式设置
    - `${PATH_TO_DATA_DIR}/*.csv`
  - 需设置`delimiter`来指名列分隔符，默认为`,`
  - 注意:
    - 训练和评估时需要csv文件数是 `nproc-per-node * nnodes * num_workers`的倍数，并且每个csv文件的数据量基本相等
    - 暂不支持没有header的csv文件
    - csv格式数据读性能有瓶颈

### fg_encoded

- 输入数据是否为FG(Feature Generator)进行特征编码后的数据

  - FG是进入模型推理前的一层特征变换，可以保证离在线特征变换的一致性，特征变换包含Combo/Lookup/Match/Expr等类型，详见[特征](./feature.md)章节。以LookupFeature的一种配置为例，特征变换为从`cate_map`中用`cate_key`查出值后，用`boundaries`进行分箱再进入模型推理

  ```
  feature_configs {
      lookup_feature {
          feature_name: "lookup_feat"
          map: "user:cate_map"
          key: "item:cate_key"
          embedding_dim: 16
          boundaries: [0, 1, 2, 3, 4]
      }
  }
  ```

  - 特征输入的side一共支持四种 \[`user`, `item`, `context`, `feature`\]，上述`lookup_feat`中的`cate_map`则是属于`user`side
    - `user`: 用户侧特征输入，线上推理时从请求中传入
    - `item`: 物品侧特征输入，线上推理时会从实时缓存在内存中的特征表里获取
    - `context`: 由上下文产生物品侧特征输入，线上推理时从请求中传入，如`recall_name`等
    - `feature`: 来自其他特征FG的输出，如下述`lookup_age_feat`的输入`age_binning`来自于RawFeature `age`的分箱结果。
    ```
    feature_configs {
        raw_feature {
            feature_name: "age_binning"
            expression: "user:age"
            embedding_dim: 16
            boundaries: [18, 25, 30]
        }
    }
    feature_configs {
        lookup_feature {
            feature_name: "lookup_age_feat"
            map: "item:age_map"
            key: "feature:age_binning"
            embedding_dim: 16
            boundaries: [0, 1, 2, 3, 4]
        }
    }
    ```

- **fg_encoded=false:**

  - 训练时会在Dataset中执行FG，数据列名与各**特征的FG所依赖字段来源**同名，详见[特征](./feature.md)，Dataset会自动分析所有特征依赖的字段来源来读取数据。
    - 以上文LookupFeature为例，**特征FG所依赖字段来源**为`[cate_map, cate_key]`，Dataset会从输入表中读取名为`cate_map`和`cate_key`的列来做FG得到`lookup_feat`
  - 该模式可以帮忙我们快速验证FG的训练效果，调优FG的配置，但由于训练时多了FG的过程，训练速度会受到一定程度的影响

- **fg_encoded=true:**

  - 则认为输入数据为编码后的数据，数据列名与**特征名**(`feature_name`)同名，Dataset会自动分析所有特征的特征名来读取数据
    - 以上文LookupFeature为例，**特征名**为`lookup_feat`，Dataset会从输入表中直接读取编码后的`lookup_feat`列直接进行模型推理
  - 该模式训练速度最佳，但需提前对数据提前进行FG编码，目前仅提供MaxCompute方式，步骤如下：
    - 生成fg json配置，上传至Dataworks的资源中，如果有vocab_file等其他文件，也需要上传至资源中
      ```shell
      python -m tzrec.tools.create_fg_json \
          --pipeline_config_path ${PIPELINE_CONFIG_PATH} \
          --fg_output_dir fg_output
          --reserves ${COLS_YOU_WANT_RESERVE}
      ```
    - 在[Dataworks](https://workbench.data.aliyun.com/)的独享资源组中安装pyfg，「资源组列表」- 在一个调度资源组的「操作」栏 点「运维助手」-「创建命令」（选手动输入）-「运行命令」
      ```shell
      /home/tops/bin/pip3 install http://tzrec.oss-cn-beijing.aliyuncs.com/third_party/pyfg030-0.3.0-cp37-cp37m-linux_x86_64.whl
      ```
    - 在Dataworks中建立`PyODPS 3`节点运行FG，节点调度参数中配置好bizdate参数
      ```
      from pyfg030 import offline_pyfg
      offline_pyfg.run(
        o,
        input_table="YOU_PROJECT.TABLE_NAME",
        output_table="YOU_PROJECT.TABLE_NAME",
        fg_json_file="YOU_FG_FILE_NAME",
        partition_value=args['bizdate']
      )
      ```

  | 参数                      | 默认值 | 说明                                                                                                                                                                                                 |
  | ------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | input_table               | 无     | 输入表                                                                                                                                                                                               |
  | output_table              | 无     | 输出表，会自动创建                                                                                                                                                                                   |
  | fg_json_file              | 无     | FG 配置文件，json 格式                                                                                                                                                                               |
  | partition_value           | 无     | 指定输入表的分区作为 FG 的输入，可支持多分区表，以逗号分隔                                                                                                                                           |
  | force_delete_output_table | False  | 是否删除输出表，设置为 True 时会先自动删除输出表, 再运行任务                                                                                                                                         |
  | force_update_resource     | False  | 是否更新资源，设置为 True 时会先自动更新资源, 再运行任务                                                                                                                                             |
  | set_sql                   | 无     | 任务执行的[flag](https://help.aliyun.com/zh/maxcompute/user-guide/flag-parameters?spm=a2c4g.11186623.0.0.383a20d9CQnpaR#concept-2278178)，如set odps.stage.mapper.split.size=32;，注意需要以分号结尾 |

### fg_threads

- 每个dataloader worker上fg的运行线程数，默认为1，`nproc-per-node * num_workers * fg_threads`建议小于单机CPU核数
- 如果`fg_threads==0`，将不会以DAG模式运行fg，特征的输入中如果有`feature` side的输入，也需要在输入表中

### label_fields

- label相关的列名，至少设置一个，可以根据算法需要设置多个，如多目标算法

  ```
    label_fields: "click"
    label_fields: "buy"
  ```

### num_workers

- 每个`proc`上的读数据并发度，`nproc-per-node * num_workers`建议小于单机CPU核数
- 如果`num_workers==0`，数据进程和训练进程将会在一个进程中，便于调试

### fg_encoded_multival_sep

- fg_encoded=true时，数据的多值分割符，默认为chr(3)

### 更多配置

- [参考文档](../proto.html#tzrec.protos.DataConfig)
