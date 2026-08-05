# cc-connect 一键安装脚本

两个版本的安装脚本，并行维护。

> 🌐 **主托管地址**: https://inst.xlm666.top  
> (备用: https://xlm666.top/install-cc-connect-pro.sh)

## 📜 文件清单

| 文件 | 大小 | 说明 |
|---|---:|---|
| `install-cc-connect-pro.sh` | 36KB | **Pro 版** · Ubuntu/Debian/RHEL/Arch/macOS · 6 家 LLM 预设 · 一行复制粘贴 |
| `provider-presets.json` | 2.6KB | Provider 元数据与模型列表 |
| `index.html` | — | inst.xlm666.top 主页 |
| `readme.html` | — | 本说明文档的 HTML 版本 |

## 🚀 Pro 版快速使用

### 准备工作：创建飞书机器人

安装脚本只需要 2 个飞书参数：`FEISHU_APP_ID` 和 `FEISHU_APP_SECRET`。飞书现在已经支持**一键创建智能体**，比原来的手动建应用简单很多。

#### 方式一：一键创建智能体（推荐，最简单）

飞书开放平台推出了"AI 智能体"快速创建入口，支持扫码或点按一键创建：

1. 打开 [飞书智能体启动台](https://open.feishu.cn/page/launcher?from=backend_oneclick)。
2. 按页面提示扫码或点击**一键创建**，选择创建为企业自建应用 / 智能体。
3. 创建完成后进入应用详情 → **凭证与基础信息**，复制：
   - `App ID`（形如 `cli_xxxxxxxxxxxxxxxx`）→ 对应环境变量 `FEISHU_APP_ID`
   - `App Secret`（点击显示）→ 对应环境变量 `FEISHU_APP_SECRET`
4. 进入 **事件与回调** → **事件配置**：
   - 订阅方式选择 **"使用长连接接收事件"**（cc-connect 默认 WebSocket 模式，无需公网地址）
   - 添加事件：`im.message.receive_v1`
5. 发布智能体（或申请发布）后即可使用。

> 💡 一键创建通常会自动开通常见 IM 权限。如果后续机器人发不出消息，再按方式二手动补一下权限即可。

#### 方式二：手动创建企业自建应用（备用）

如果一键创建不满足需求，可以手动创建：

1. 打开 [飞书开放平台](https://open.feishu.cn/app) → 点击**创建企业自建应用**。
2. 进入应用详情 → **凭证与基础信息**，复制 `App ID` / `App Secret`。
3. 进入 **事件与回调** → **事件配置**：
   - 订阅方式选择 **"使用长连接接收事件"**（无需公网 IP/域名）
   - 添加事件：`im.message.receive_v1`（接收消息）
   - 添加事件：`im.message.message_read_v1`（可选，已读回执）
   - 添加事件：`im.message.reaction.created_v1` / `im.message.reaction.deleted_v1`（可选，表情互动）
4. 进入 **权限管理**，申请并开通：
   - `im:chat:readonly`
   - `im:message:send_as_bot`
   - `im:message:group_msg`
   - `im:message:send`
5. 进入 **版本管理与发布** → 点击**创建版本** → 填写版本号、更新说明 → **申请发布**。
6. 在飞书管理后台或通过应用管理员审批后，机器人即可在群聊 / 私聊中被 @ 或私聊使用。

> 💡 如果你只需要本地调试，也可以先用 `CC_PROVIDER=custom` 自定义 Claude Code 入口，跳过飞书步骤。

### 一行复制粘贴 (env 模式)

下面每条命令都是**完整、可独立运行**的。把 `xxx` 换成你的真实密钥即可：

> 💻 **操作系统支持**：一键脚本支持 **Ubuntu / Debian / RHEL / Arch / macOS**。原生 Windows 不支持直接运行本 bash 脚本，推荐在 **WSL2 (Ubuntu)** 中执行；若必须在原生 Windows 上运行，请先安装 [Node.js 22](https://nodejs.org/)，再执行 `npm install -g cc-connect` 并手动配置 `config.toml`（cc-connect 本身是 Node.js 应用，跨平台可用）。

```bash
# ============================================
# 示例 1: Kimi Code（国内可用，代码/长上下文场景）
# ============================================
# CC_PROVIDER      : 固定填 kimi，脚本会识别为 Kimi Code 预设
# CC_API_KEY       : 从 https://platform.moonshot.cn 获取的 API Key
# FEISHU_APP_ID    : 飞书应用详情页的 App ID，形如 cli_xxx
# FEISHU_APP_SECRET: 飞书应用详情页的 App Secret
export CC_PROVIDER=kimi
export CC_API_KEY=sk-kimi-xxx
export FEISHU_APP_ID=cli_xxx
export FEISHU_APP_SECRET=xxx

# -E 保留上面 export 的环境变量；sudo 用于写 systemd 服务与 npm 全局包
# -fsSL: 静默下载，跟随 302 跳转，出错时显示错误
# 管道后面的 bash 会读取环境变量并自动安装
# 安装完成后，给飞书机器人发消息即可开始对话
curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh | sudo -E bash
```

```bash
# ============================================
# 示例 2: DeepSeek（国内性价比最高）
# ============================================
# 模型默认使用 deepseek-v4-flash；如需 Pro 版可切换 deepseek-v4-pro
export CC_PROVIDER=deepseek
export CC_API_KEY=sk-xxx
export FEISHU_APP_ID=cli_xxx
export FEISHU_APP_SECRET=xxx
curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh | sudo -E bash
```

```bash
# ============================================
# 示例 3: MiniMax
# ============================================
# API Key 是 JWT 格式，通常以 eyJ 开头
export CC_PROVIDER=minimax
export CC_API_KEY=eyJxxx
export FEISHU_APP_ID=cli_xxx
export FEISHU_APP_SECRET=xxx
curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh | sudo -E bash
```

```bash
# ============================================
# 示例 4: OpenRouter
# ============================================
# 脚本会自动追加 HTTP-Referer + X-Title headers，无需手动配置
export CC_PROVIDER=openrouter
export CC_API_KEY=sk-or-v1-xxx
export FEISHU_APP_ID=cli_xxx
export FEISHU_APP_SECRET=xxx
curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh | sudo -E bash
```

```bash
# ============================================
# 示例 5: 智谱 GLM
# ============================================
# 使用智谱 Anthropic 兼容接口: https://open.bigmodel.cn/api/anthropic
# 默认模型 glm-5.2；如需代码增强模型可切 glm-5.2-coding
export CC_PROVIDER=glm
export CC_API_KEY=xxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxx
export FEISHU_APP_ID=cli_xxx
export FEISHU_APP_SECRET=xxx
curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh | sudo -E bash
```

```bash
# ============================================
# 示例 6: Anthropic 官方
# ============================================
export CC_PROVIDER=anthropic
export CC_API_KEY=sk-ant-api03-xxx
export FEISHU_APP_ID=cli_xxx
export FEISHU_APP_SECRET=xxx
curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh | sudo -E bash
```

```bash
# ============================================
# 示例 7: 自定义 OpenAI/Anthropic 兼容端点
# ============================================
# CC_BASE_URL 必填；模型名按你的服务商填写
export CC_PROVIDER=custom
export CC_BASE_URL=https://your-api.example.com/v1
export CC_API_KEY=sk-xxx
export CC_MODEL=claude-sonnet-4-6
export FEISHU_APP_ID=cli_xxx
export FEISHU_APP_SECRET=xxx
curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh | sudo -E bash
```

### 交互模式 (download-then-bash)

如果你不想把密钥暴露在命令历史里，或者想逐项确认：

```bash
# 1. 先下载脚本到本地
# -o /tmp/inst.sh 表示保存为 /tmp/inst.sh
# 这一步不会执行任何安装操作，只是下载文件
curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh -o /tmp/inst.sh

# 2. 以交互方式运行
# 脚本会一步步提示你选择 LLM 服务商、输入 API Key、飞书凭据、管理员等
bash /tmp/inst.sh
```

### Dry-run（不实际安装，只打印计划）

```bash
# 设置一组测试值，加上 --dry-run 参数
# 脚本会打印：要安装的 npm 包、要写入的 config.toml 预览、systemd unit 预览
# 不会真正修改系统
export CC_PROVIDER=kimi CC_API_KEY=test FEISHU_APP_ID=cli_x FEISHU_APP_SECRET=sec_x
bash install-cc-connect-pro.sh --dry-run
```

### 卸载

```bash
bash install-cc-connect-pro.sh --uninstall
# 或等价写法:
CC_UNINSTALL=1 bash install-cc-connect-pro.sh
```

## 🛠️ 飞书 CLI 安装（可选，高级调试）

安装脚本本身不需要飞书 CLI，但如果你需要调试飞书开放平台权限、文档、审批等能力，可以单独安装：

```bash
# 方式 1: npx 临时运行（不需要全局安装）
npx @larksuite/cli@latest --help

# 方式 2: 全局安装（命令行直接用 lark）
npm install -g @larksuite/cli@latest

# 登录后会话 token 保存在 ~/.lark-cli/
lark login
lark app list
```

> ⚠️ 注意：npm 上有一个同名的第三方包 `lark-cli`，那不是官方工具。官方包是 `@larksuite/cli`。  
> 更多信息：https://github.com/larksuite/cli

## 🌐 LLM 服务商预设

| ID | 显示名 | Base URL | 默认 Model | 可选模型 | Key 前缀 |
|---|---|---|---|---|---|
| `anthropic` | Anthropic 官方 | `https://api.anthropic.com` | `claude-sonnet-4-6` | sonnet / opus / haiku | `sk-ant-` |
| `minimax` | MiniMax | `https://api.minimaxi.com/anthropic` | `MiniMax-M3` | M3 / M3-highspeed / M2.7 / M2.7-highspeed | `eyJ` (JWT) |
| `deepseek` | DeepSeek | `https://api.deepseek.com/anthropic` | `deepseek-v4-flash` | deepseek-v4-flash / deepseek-v4-pro | `sk-` |
| `glm` | 智谱 GLM | `https://open.bigmodel.cn/api/anthropic` | `glm-5.2` | glm-5.2 / glm-5.2-coding / glm-4-plus / glm-4-flash / glm-4-air | 任意 |
| `kimi` | 月之暗面 Kimi Code | `https://api.kimi.com/coding/` | `kimi-for-coding` | kimi-for-coding / kimi-for-coding-highspeed / k3 / k3-256k | `sk-kimi-` |
| `openrouter` | OpenRouter | `https://openrouter.ai/api/v1` | `anthropic/claude-sonnet-4-6` | anthropic/* 系列 | `sk-or-` |
| `custom` | 自定义 URL | (必填 CC_BASE_URL) | `claude-sonnet-4-6` | 自定义 | 任意 |

### 智谱 GLM 说明
- 使用 Anthropic 兼容端点 `https://open.bigmodel.cn/api/anthropic`。
- 默认模型已升级为 `glm-5.2`；如需代码能力更强的场景，可切换 `glm-5.2-coding`。
- 旧模型 `glm-4-plus` / `glm-4-flash` / `glm-4-air` 仍保留在可选列表中。
- 安装后可用 `/model switch glm-5.2` 或 `/model switch glm-5.2-coding` 切换模型。

### DeepSeek 说明
- 使用 Anthropic 兼容端点 `https://api.deepseek.com/anthropic`。
- Claude 模型名会自动映射：
  - `claude-opus*` → `deepseek-v4-pro`
  - `claude-haiku*` / `claude-sonnet*` → `deepseek-v4-flash`
- 安装后可用 `/model switch deepseek-v4-pro` 在聊天中切换模型。

### Kimi Code 说明
- 使用 Kimi 为 Claude Code 等第三方工具优化的端点 `https://api.kimi.com/coding/`。
- `k3[1m]` 表示 1M 上下文版本；Claude Code 环境变量写法参考 Kimi 官方文档。
- 安装后可用 `/model switch k3` 或 `/model switch kimi-for-coding-highspeed` 切换模型。

## ⚙️ 生成配置新增项 (cc-connect v1.4+)

Pro 版 v1.1.0 生成的 `config.toml` 已默认包含：

- `[display]` 显示模式设为 `compact`, 关闭 `thinking_messages` (减少 IM 噪音)
- `[stream_preview]` 流式预览启用, 更新间隔 1500ms
- `[cron] session_mode = "reuse"` — 定时任务复用活跃会话, 避免 cron 推送丢消息
- `[[providers.models]]` 模型列表 — 支持聊天命令 `/model switch <模型名>` 切换
- 飞书平台启用交互卡片 (`enable_feishu_card = true`) 与消息反应 (`reaction_emoji = "OnIt"`)

如需更多高级配置 (hooks、webhook、bridge、management API、user isolation 等), 安装后编辑 `~/.cc-connect/config.toml`, 参考 `cc-connect config example`。

## 📝 修改历史

- **2026-08-05** v1.1.0: 同步 cc-connect v1.4+ 新配置; 更新 DeepSeek 默认模型为 `deepseek-v4-flash` 并暴露 v4-pro; 更新 Kimi 端点为 `https://api.kimi.com/coding/` 并暴露 kimi-for-coding / k3 系列; 智谱 GLM 默认模型升级为 `glm-5.2`，新增 `glm-5.2-coding`; 生成配置默认加入 `[display]`, `[stream_preview]`, `[cron] session_mode = "reuse"`, `[[providers.models]]`; 补充飞书机器人创建流程与飞书 CLI 安装说明; 优化 env 模式示例注释; 修复 README.md 404 问题
- **2026-06-23** v1.0.1: secrets 改用 `${VAR}` 占位符 → `daemon install` 捕获到 systemd `Environment=`; 新增 `CC_ALLOW_FROM` 强白名单; 修正 `admin_from` 为字符串格式 (官方文档要求)
- **2026-06-23** v1.0.0: Pro 版首版发布 (6 provider 预设 + 双模式 + macOS)

## 🔗 引用

- cc-connect: https://github.com/chenhg5/cc-connect
- Claude Code: https://github.com/anthropics/claude-code
- 智谱 AI 开放文档: https://docs.bigmodel.cn/cn/guide/develop/claude/introduction
- DeepSeek Anthropic API: https://api-docs.deepseek.com/zh-cn/guides/anthropic_api
- Kimi Code for Claude Code: https://www.kimi.com/code/docs/third-party-tools/claude-code.html
- 飞书开放平台: https://open.feishu.cn/app
- 飞书 CLI: https://github.com/larksuite/cli
- 源站: https://inst.xlm666.top
