# Ollama 服务监控系统

这是一个用于监控和检测 Ollama 服务可用性和性能的系统。它提供了一个现代化的 Web 界面，支持多语言（中文/英文），并具有实时检测和数据展示功能。

![](https://pic-bed-1302552283.cos.ap-guangzhou.myqcloud.com/undefined20250224210925629.png?imageSlim)

在线体验：https://awesome-ollama-server.vercel.app

## 功能特点

- 🔍 服务检测
  - 支持批量检测 Ollama 服务
  - 实时显示检测状态和结果
  - 支持检测结果导出
  - 支持自动 FOFA 扫描

- 📊 性能监控
  - 测试服务响应时间和 TPS
  - 展示可用模型列表
  - 性能数据可视化

- 🌐 多语言支持
  - 中文界面
  - 英文界面
  - 一键切换语言

- 🎯 高级筛选
  - 模型过滤
  - TPS/更新时间排序
  - 分页显示

## 技术栈

- ⚡️ Next.js 14 - React 框架
- 🔥 TypeScript - 类型安全
- 🎨 Tailwind CSS - 样式框架
- 🌍 next-intl - 国际化
- 🔄 Server Components - 服务端组件
- 📱 响应式设计 - 移动端适配

## 快速开始

### 前置要求

- Node.js 18.0 或更高版本
- npm 或 yarn 包管理器

### 安装

```bash
# 克隆项目
git clone git@github.com:forrany/Awesome-Ollama-Server.git
cd Awesome-Ollama-Server

# 安装依赖
npm install
# 或
yarn install
```

### 开发环境

```bash
# 启动开发服务器
npm run dev
# 或
yarn dev
```

访问 http://localhost:3000 查看应用。

### 生产环境

```bash
# 构建项目
npm run build
# 或
yarn build

# 启动服务
npm start
# 或
yarn start
```

## 使用说明

### 检测服务

1. 点击"检测服务"按钮
2. 在弹出的对话框中输入 Ollama 服务地址（每行一个）
3. 点击"开始检测"
4. 等待检测完成，查看结果
5. 可选择下载检测结果

### 筛选和排序

- 使用模型过滤器选择特定模型
- 点击 TPS 或更新时间进行排序
- 使用搜索框快速查找模型

### 语言切换

- 点击右上角的语言切换按钮
- 选择中文或英文

## 项目结构

```
src/
├── app/              # Next.js 应用目录
├── components/       # React 组件
├── i18n/            # 国际化文件
├── lib/             # 工具函数
├── types/           # TypeScript 类型定义
└── config/          # 配置文件
```

## 环境变量

创建 `.env` 文件并设置以下变量，填写后 Github Actions 会自动执行监控和上传

```env
# 可选：Redis 配置（如果使用）
UPSTASH_REDIS_URL=your-redis-url
UPSTASH_REDIS_TOKEN=your-redis-token

# 可选：FOFA扫描国家列表（如果使用）
COUNTRYS=US,CN,RU
```

## 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 许可证

本项目基于 MIT 协议开源 - 详见 [LICENSE](LICENSE) 文件

## 作者

VincentKo (@forrany) - [GitHub](https://github.com/forrany)

## 免责声明

1. 本项目仅用于安全研究和教育目的
2. 不得将本项目用于任何非法用途
3. 作者不对使用本项目造成的任何损失负责
4. 数据来源于网络，如有侵权，请联系作者删除


## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=forrany/Awesome-Ollama-Server&type=Date)](https://star-history.com/#forrany/Awesome-Ollama-Server&Date)
