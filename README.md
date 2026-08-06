# cc-connect-installer

本仓库在 GitHub 上直接托管 **cc-connect 一键安装脚本**，用户无需访问额外的分发站点，直接从 GitHub raw 地址下载执行即可。

## 快速使用

```bash
export CC_PROVIDER=kimi
export CC_API_KEY=YOUR_KIMI_API_KEY
export FEISHU_APP_ID=YOUR_FEISHU_APP_ID
export FEISHU_APP_SECRET=YOUR_FEISHU_APP_SECRET
curl -fsSL https://raw.githubusercontent.com/ZACKLZ/cc-connect-installer/main/install-cc-connect.sh | sudo -E bash
```

## 文件清单

| 文件 | 说明 |
|---|---|
| `install-cc-connect.sh` | 一键安装脚本，支持 6 家 LLM 服务商预设 + 自定义 URL |
| `provider-presets.json` | Provider 元数据与模型列表 |
| `index.html` | 本地预览用主页 |
| `readme.html` | 本地预览用 HTML 说明 |
| `.github/workflows/validate.yml` | 提交/PR 时校验脚本语法 |

## 本地测试

```bash
bash -n install-cc-connect.sh              # 语法检查
bash install-cc-connect.sh --help          # 查看帮助
bash install-cc-connect.sh --dry-run       # 打印执行计划
bash install-cc-connect.sh --uninstall     # 卸载
```

## 交互模式

```bash
curl -fsSL https://raw.githubusercontent.com/ZACKLZ/cc-connect-installer/main/install-cc-connect.sh -o /tmp/inst.sh
bash /tmp/inst.sh
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

## 自定义

如需 fork 后自己维护：

1. Fork 本仓库。
2. 修改 `install-cc-connect.sh` 中的 `SCRIPT_URL_DEFAULT` 为你自己的 raw 地址。
3. 修改 `index.html` / `readme.html` 中的下载链接。
4. 提交即可。

## 安全

- 仓库中不放任何真实 API Key、App Secret、Token。
- GitHub Actions 在提交/PR 时会扫描明文密钥；如匹配到真实密钥特征会失败。

## 上游链接

- [cc-connect](https://github.com/chenhg5/cc-connect)
- [Claude Code](https://github.com/anthropics/claude-code)
