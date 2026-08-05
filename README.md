# cc-connect 一键安装脚本 · GitHub 管理

本仓库托管 **cc-connect 一键安装脚本**，并通过 GitHub Actions 自动部署到 Web 服务器。

> 仓库中不包含任何真实密钥或域名；所有占位符均为 `example.com` / `YOUR_*_HERE`。

## 文件清单

| 文件 | 说明 |
|---|---|
| `install-cc-connect.sh` | **Pro 版安装脚本**，支持 6 家 LLM 服务商预设 + 自定义 URL |
| `provider-presets.json` | Provider 元数据与模型列表 |
| `index.html` | 安装脚本主页 |
| `readme.html` | 使用说明 HTML 版本 |
| `.github/workflows/validate.yml` | 提交/PR 时校验脚本语法 |
| `.github/workflows/deploy.yml` | 推送到 `main` 时自动部署到服务器 |

## GitHub 配置

在仓库中设置以下 **Repository secrets** 和 **Variables**：

### Secrets

| Secret | 说明 |
|---|---|
| `DEPLOY_HOST` | 目标服务器 IP 或域名 |
| `DEPLOY_USER` | SSH 用户名 |
| `DEPLOY_KEY` | SSH 私钥（对应服务器上的 authorized_keys） |
| `DEPLOY_PATH` | 服务器上的部署目录，如 `/var/www/html` |

### Variables

| Variable | 说明 |
|---|---|
| `DEPLOY_DOMAIN` | 脚本托管域名，如 `inst.example.com`；设置后 Actions 会自动替换 `example.com` 占位符 |

## 部署流程

1. 修改 `install-cc-connect.sh` / `index.html` / `provider-presets.json`。
2. 提交并推送到 `main`：
   ```bash
   git add .
   git commit -m "update install script"
   git push origin main
   ```
3. GitHub Actions 自动运行：
   - `validate.yml`：检查 bash 语法、shellcheck、扫描明文密钥。
   - `deploy.yml`：替换 `example.com` 为 `DEPLOY_DOMAIN`，然后通过 SCP 上传到服务器。
4. 部署完成后可通过以下命令验证：
   ```bash
   curl -fsSL https://YOUR_DOMAIN/install-cc-connect.sh | head -5
   ```

## 本地使用

### 一行安装（env 模式）

```bash
export CC_PROVIDER=kimi
export CC_API_KEY=YOUR_KIMI_API_KEY
export FEISHU_APP_ID=YOUR_FEISHU_APP_ID
export FEISHU_APP_SECRET=YOUR_FEISHU_APP_SECRET
curl -fsSL https://example.com/install-cc-connect.sh | sudo -E bash
```

> 把 `example.com` 换成你实际托管脚本的域名。

### 交互模式

```bash
curl -fsSL https://example.com/install-cc-connect.sh -o /tmp/inst.sh
bash /tmp/inst.sh
```

### Dry-run

```bash
export CC_PROVIDER=kimi CC_API_KEY=test FEISHU_APP_ID=cli_x FEISHU_APP_SECRET=sec_x
bash install-cc-connect.sh --dry-run
```

## 快速使用脚本

```bash
bash -n install-cc-connect.sh              # 语法检查
bash install-cc-connect.sh --help          # 查看帮助
bash install-cc-connect.sh --uninstall     # 卸载
```

## LLM 服务商预设

| ID | 显示名 | Base URL | 默认 Model |
|---|---|---|---|
| `anthropic` | Anthropic 官方 | `https://api.anthropic.com` | `claude-sonnet-4-6` |
| `minimax` | MiniMax | `https://api.minimaxi.com/anthropic` | `MiniMax-M3` |
| `deepseek` | DeepSeek | `https://api.deepseek.com/anthropic` | `deepseek-v4-flash` |
| `glm` | 智谱 GLM | `https://open.bigmodel.cn/api/anthropic` | `glm-5.2` |
| `kimi` | 月之暗面 Kimi | `https://api.kimi.com/coding/` | `kimi-for-coding` |
| `openrouter` | OpenRouter | `https://openrouter.ai/api/v1` | `anthropic/claude-sonnet-4-6` |
| `custom` | 自定义 URL | 必填 `CC_BASE_URL` | `claude-sonnet-4-6` |

## 安全

- 仓库中不放真实 API Key、App Secret、Token、域名。
- GitHub Actions 在部署前会扫描明文密钥；如匹配到 `sk-`、`cli_`、`eyJ` 等前缀会失败。
- 服务器部署目录权限由你在服务器端控制，建议脚本文件为 `644`，目录为 `755`。

## 上游链接

- [cc-connect](https://github.com/chenhg5/cc-connect)
- [Claude Code](https://github.com/anthropics/claude-code)
