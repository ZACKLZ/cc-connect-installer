#!/usr/bin/env bash
# ============================================================================
#  Claude Code + cc-connect 一键安装脚本 (Pro 版)
#  --------------------------------------------
#  支持 6 家 LLM 服务商预设 + 自定义 URL:
#    1. Anthropic 官方      2. MiniMax (MiniMax M3)
#    3. DeepSeek (v4)       4. 智谱 GLM
#    5. 月之暗面 Kimi Code  6. OpenRouter
#    7. 自定义 URL
#  支持飞书 (Feishu) 平台 (后续可扩展 Telegram/DingTalk/...)
#  支持 OS:  Ubuntu/Debian/RHEL/Arch/macOS
#  支持双模式: 环境变量 (curl|bash) + 交互式 (download-then-bash)
#
#  准备工作 (飞书机器人):
#    1. 访问 https://open.feishu.cn/app 创建企业自建应用
#    2. 在「凭证与基础信息」复制 App ID / App Secret
#    3. 在「事件与回调」→「事件配置」选择「使用长连接接收事件」，
#       订阅 im.message.receive_v1 (cc-connect 默认 WebSocket 模式，无需公网地址)
#    4. 在「权限管理」开通 im:chat:readonly / im:message:send_as_bot 等权限
#    5. 在「版本管理与发布」创建版本并申请发布
#
#  使用 (env 模式, 一行复制粘贴):
#    # CC_PROVIDER:  LLM 服务商, 可选 anthropic / minimax / deepseek / glm / kimi / openrouter / custom
#    # CC_API_KEY:   对应服务商的 API Key
#    # FEISHU_APP_ID / FEISHU_APP_SECRET: 飞书机器人凭证
#    export CC_PROVIDER=kimi
#    export CC_API_KEY=sk-kimi-xxx
#    export FEISHU_APP_ID=cli_xxx
#    export FEISHU_APP_SECRET=xxx
#    # -E 保留 export 的环境变量; sudo 用于写 systemd 与 npm 全局包
#    curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh | sudo -E bash
#
#  使用 (交互模式, 适合不想把密钥留在命令历史的场景):
#    curl -fsSL https://inst.xlm666.top/install-cc-connect-pro.sh -o /tmp/inst.sh
#    bash /tmp/inst.sh
#
#  调试:
#    CC_PROVIDER=kimi CC_API_KEY=test FEISHU_APP_ID=cli_x FEISHU_APP_SECRET=sec_x \
#      bash install-cc-connect-pro.sh --dry-run
#
#  来源: https://inst.xlm666.top
# ============================================================================
set -euo pipefail

# ----- 颜色 / 输出 --------------------------------------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

PREFIX="${BLUE}[cc-install]${NC}"
ok()    { echo -e "${GREEN}${PREFIX}${NC}  $*"; }
warn()  { echo -e "${YELLOW}${PREFIX}${NC}  $*" >&2; }
err()   { echo -e "${RED}${PREFIX}${NC}  $*" >&2; }
die()   { err "$@"; exit 1; }
section() { echo -e "\n${BOLD}${CYAN}==> $*${NC}"; }
step()  { echo -e "  ${BLUE}▸${NC} $*"; }

# ----- 版本 / 元信息 -------------------------------------------------------
SCRIPT_VERSION="1.1.0"
SCRIPT_URL_DEFAULT="https://inst.xlm666.top/install-cc-connect-pro.sh"

# ----- 全局状态 (在 main() 里被赋值) --------------------------------------
OS_ID="" OS_VERSION="" OS_FAMILY="" PKG_INSTALL=""
REAL_USER="" REAL_HOME="" SUDO=""
SVC_DOMAIN=""
INTERACTIVE=0
# 注: PROV_* 关联数组在 load_provider_presets() 里用 declare -gA 初始化,
# 不要在这里用 PROV_X=() 预先声明为 indexed, 否则 declare -A 会报
# "cannot convert indexed to associative array".
declare -a PROV_ORDER_REF=()
EFFECTIVE_PROVIDER="" EFFECTIVE_BASE_URL="" EFFECTIVE_MODEL="" EFFECTIVE_API_KEY="" \
  EFFECTIVE_HEADERS="" EFFECTIVE_FAID="" EFFECTIVE_FASEC="" EFFECTIVE_ADMIN="" EFFECTIVE_ALLOW="" \
  EFFECTIVE_NAME="" EFFECTIVE_WORK_DIR="" EFFECTIVE_MODE=""

# ============================================================================
#  Provider 预设数据 (6 家 + custom)
# ============================================================================
load_provider_presets() {
  # declare -gA 强制声明为全局关联数组 (set -u 下不带 declare 不会被自动转换)
  declare -gA PROV_NAME_REF=(
    ["anthropic"]="Anthropic 官方"
    ["minimax"]="MiniMax (MiniMax M3)"
    ["deepseek"]="DeepSeek (deepseek-v4-flash / v4-pro)"
    ["glm"]="智谱 GLM (glm-5.2 / Anthropic 兼容)"
    ["kimi"]="月之暗面 Kimi Code (kimi-for-coding / k3)"
    ["openrouter"]="OpenRouter (Claude 透传)"
    ["custom"]="自定义 URL"
  )

  declare -gA PROV_BASE_URL_REF=(
    ["anthropic"]="https://api.anthropic.com"
    ["minimax"]="https://api.minimaxi.com/anthropic"
    ["deepseek"]="https://api.deepseek.com/anthropic"
    ["glm"]="https://open.bigmodel.cn/api/anthropic"
    ["kimi"]="https://api.kimi.com/coding/"
    ["openrouter"]="https://openrouter.ai/api/v1"
  )

  declare -gA PROV_DEFAULT_MODEL_REF=(
    ["anthropic"]="claude-sonnet-4-6"
    ["minimax"]="MiniMax-M3"
    ["deepseek"]="deepseek-v4-flash"
    ["glm"]="glm-5.2"
    ["kimi"]="kimi-for-coding"
    ["openrouter"]="anthropic/claude-sonnet-4-6"
    ["custom"]="claude-sonnet-4-6"
  )

  declare -gA PROV_KEY_PREFIX_REF=(
    ["anthropic"]="sk-ant-"
    ["minimax"]="eyJ"
    ["deepseek"]="sk-"
    ["glm"]=""
    ["kimi"]="sk-kimi-"
    ["openrouter"]="sk-or-"
    ["custom"]=""
  )

  # 仅 OpenRouter 需要 HTTP-Referer + X-Title (leaderboard 归属, 非必须但建议)
  declare -gA PROV_NEEDS_EXTRA_HEADER_REF=(
    ["openrouter"]="HTTP-Referer: https://inst.xlm666.top
X-Title: cc-connect"
  )

  # cc-connect 内部 provider slug (与现有 example/config 一致)
  declare -gA PROV_PROVIDER_REF_REF=(
    ["anthropic"]="anthropic"
    ["minimax"]="minimax-cn"
    ["deepseek"]="deepseek"
    ["glm"]="glm"
    ["kimi"]="kimi"
    ["openrouter"]="openrouter"
    ["custom"]="custom"
  )

  # 可选模型列表 (用于生成 [[providers.models]], 支持 /model 命令切换)
  declare -gA PROV_MODELS_REF=(
    ["anthropic"]="claude-sonnet-4-6 claude-opus-4-6 claude-haiku-3-5"
    ["minimax"]="MiniMax-M3 MiniMax-M3-highspeed MiniMax-M2.7 MiniMax-M2.7-highspeed"
    ["deepseek"]="deepseek-v4-flash deepseek-v4-pro"
    ["glm"]="glm-5.2 glm-5.2-coding glm-4-plus glm-4-flash glm-4-air"
    ["kimi"]="kimi-for-coding kimi-for-coding-highspeed k3 k3-256k"
    ["openrouter"]="anthropic/claude-sonnet-4-6 anthropic/claude-opus-4-6 anthropic/claude-haiku-3-5"
    ["custom"]=""
  )

  PROV_ORDER_REF=(anthropic minimax deepseek glm kimi openrouter custom)
}

# 通过名字引用全局变量 (因为 bash 4 关联数组的 declare -g 在函数内也能用)
# 上面把数组放进 *_REF 命名, 这里提供 getter
prov_name() { echo "${PROV_NAME_REF[$1]:-}"; }
prov_base_url() { echo "${PROV_BASE_URL_REF[$1]:-}"; }
prov_default_model() { echo "${PROV_DEFAULT_MODEL_REF[$1]:-}"; }
prov_key_prefix() { echo "${PROV_KEY_PREFIX_REF[$1]:-}"; }
prov_extra_header() { echo "${PROV_NEEDS_EXTRA_HEADER_REF[$1]:-}"; }
prov_ref_slug() { echo "${PROV_PROVIDER_REF_REF[$1]:-}"; }
prov_models() { echo "${PROV_MODELS_REF[$1]:-}"; }
prov_is_known() {
  local needle="$1"
  local p
  for p in "${PROV_ORDER_REF[@]}"; do
    [[ "$p" == "$needle" ]] && return 0
  done
  return 1
}

# ============================================================================
#  1. 基础检查
# ============================================================================
check_bash_version() {
  local v="${BASH_VERSINFO[0]:-0}"
  if (( v < 4 )); then
    die "需要 Bash 4+ (关联数组), 当前: $v。请升级: brew install bash / apt install bash"
  fi
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
      SUDO="sudo"
    else
      die "需要 root 权限 (请用 sudo 或 root 运行)"
    fi
  else
    SUDO=""
  fi
}

# ============================================================================
#  2. OS / 平台检测
# ============================================================================
detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="${VERSION_ID:-unknown}"
    case "$OS_ID" in
      ubuntu|debian|linuxmint|pop)         OS_FAMILY="linux-deb" ;;
      rhel|centos|rocky|almalinux|fedora|amazon)
                                            OS_FAMILY="linux-rpm" ;;
      arch|manjaro)                        OS_FAMILY="linux-arch" ;;
      alpine)                              OS_FAMILY="linux-deb" ;;  # 用 apt 风格包名
      *)
        if command -v apt-get &>/dev/null; then
          OS_FAMILY="linux-deb"
        elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
          OS_FAMILY="linux-rpm"
        elif command -v pacman &>/dev/null; then
          OS_FAMILY="linux-arch"
        else
          die "未识别的 Linux 发行版: $OS_ID (无 apt/dnf/pacman)"
        fi
        ;;
    esac
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    OS_FAMILY="macos"
    OS_ID="macos"
    OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
  else
    die "不支持的 OS: $(uname -s)"
  fi

  case "$OS_FAMILY" in
    linux-deb)  PKG_INSTALL="apt-get install -y -qq" ;;
    linux-rpm)  PKG_INSTALL="dnf install -y" ;;
    linux-arch) PKG_INSTALL="pacman -S --noconfirm" ;;
    macos)
      PKG_INSTALL="brew install"
      if ! command -v brew &>/dev/null; then
        die "macOS 需要 Homebrew:  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      fi
      ;;
  esac

  ok "OS: ${OS_FAMILY} (${OS_ID} ${OS_VERSION})"
}

real_user_and_home() {
  # 简化模式: root 用户始终装到 /root, macOS 装到 $HOME (无 /root 概念)
  if [[ $EUID -eq 0 ]]; then
    REAL_USER="root"
    REAL_HOME="/root"
  else
    REAL_USER="$(id -un)"
    REAL_HOME="$HOME"
  fi
  if [[ -z "$REAL_HOME" || ! -d "$REAL_HOME" ]]; then
    die "无法确定家目录 (REAL_USER=$REAL_USER, REAL_HOME=$REAL_HOME)"
  fi
  step "安装用户: $REAL_USER  目录: $REAL_HOME"
}

decide_interactive() {
  if [[ -t 0 && -t 1 ]]; then
    INTERACTIVE=1
  else
    INTERACTIVE=0
  fi
}

# ============================================================================
#  3. 工具链 (Node.js + npm)
# ============================================================================
need_node() {
  if command -v node &>/dev/null; then
    local v
    v="$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1 || echo 0)"
    if [[ "$v" =~ ^[0-9]+$ ]] && (( v >= 22 )); then
      ok "Node $(node -v) 已安装, 跳过"
      return
    fi
    warn "Node $(node -v 2>/dev/null) 版本过低, 需要 22+"
  fi

  step "安装 Node.js 22 LTS..."
  case "$OS_FAMILY" in
    linux-deb)
      # $SUDO 可能为空 (root 直接跑), 用 case 决定是否加 -E
      if [[ -n "$SUDO" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO -E bash - >/dev/null
      else
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null
      fi
      $SUDO apt-get update -qq
      $SUDO apt-get install -y -qq nodejs
      ;;
    linux-rpm)
      curl -fsSL https://rpm.nodesource.com/setup_22.x | $SUDO bash - >/dev/null
      $SUDO "$PKG_INSTALL" nodejs
      ;;
    linux-arch)
      $SUDO pacman -S --noconfirm nodejs npm
      ;;
    macos)
      brew install node@22
      brew link --force --overwrite node@22 2>/dev/null || true
      hash -r
      ;;
  esac

  if ! command -v node &>/dev/null; then
    die "Node 安装失败, 请手动安装 Node 22+ 后重试"
  fi
  ok "Node $(node -v) 安装完成"
}

# ============================================================================
#  4. npm 全局包安装
# ============================================================================
install_cc_connect() {
  if command -v cc-connect &>/dev/null && [[ "${CC_FORCE_NPM:-0}" != "1" ]]; then
    ok "cc-connect $(cc-connect --version 2>/dev/null | head -1) 已安装, 跳过 (CC_FORCE_NPM=1 强制重装)"
  else
    step "安装 cc-connect..."
    $SUDO npm install -g cc-connect
    ok "cc-connect $(cc-connect --version 2>/dev/null | head -1) 安装完成"
  fi
}

install_claude_code() {
  if command -v claude &>/dev/null && [[ "${CC_FORCE_NPM:-0}" != "1" ]]; then
    ok "Claude Code $(claude --version 2>/dev/null) 已安装, 跳过"
  else
    step "安装 Claude Code..."
    $SUDO npm install -g @anthropic-ai/claude-code
    ok "Claude Code $(claude --version 2>/dev/null) 安装完成"
  fi
}

# ============================================================================
#  5. 输入收集 (env 模式 + 交互模式)
# ============================================================================
prompt_provider() {
  local i=1 choice
  echo
  step "选择 LLM 服务商 (回车默认 1):"
  local p
  for p in "${PROV_ORDER_REF[@]}"; do
    printf "    ${CYAN}%d)${NC} %s  ${YELLOW}%s${NC}\n" "$i" "$(prov_name "$p")" "$(prov_base_url "$p")"
    ((i++))
  done
  echo
  read -r -p "$(echo -e "${BLUE}${PREFIX}${NC}  选择 [1]: ")" choice
  choice="${choice:-1}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#PROV_ORDER_REF[@]} )); then
    die "无效选择: $choice"
  fi
  echo "${PROV_ORDER_REF[$((choice-1))]}"
}

prompt_api_key() {
  local provider="$1" prefix="$2" key=""
  while [[ -z "$key" ]]; do
    read -r -s -p "$(echo -e "${BLUE}${PREFIX}${NC}  $provider API Key (输入不显示): ")" key
    echo
    if [[ -z "$key" ]]; then
      warn "不能为空, 请重试"
    fi
  done
  if [[ -n "$prefix" && "$key" != "$prefix"* ]]; then
    warn "API Key 通常以 '${prefix}' 开头, 已确认请忽略"
  fi
  echo "$key"
}

prompt_text() {
  local prompt="$1" default="$2" var="$3" val=""
  # shellcheck disable=SC2034  # val is read for use by eval below
  read -r -p "$(echo -e "${BLUE}${PREFIX}${NC}  $prompt [$default]: ")" val
  # shellcheck disable=SC2154
  eval "$var=\${val:-\$default}"
}

prompt_feishu() {
  local id="" sec=""
  while [[ -z "$id" ]]; do
    read -r -s -p "$(echo -e "${BLUE}${PREFIX}${NC}  飞书 App ID (cli_xxx 开头, 不显示): ")" id
    echo
    [[ -z "$id" ]] && warn "不能为空, 请重试"
  done
  if [[ ! "$id" =~ ^cli_ ]]; then
    warn "飞书 App ID 通常以 'cli_' 开头, 请确认是否正确"
  fi
  while [[ -z "$sec" ]]; do
    read -r -s -p "$(echo -e "${BLUE}${PREFIX}${NC}  飞书 App Secret (不显示): ")" sec
    echo
    [[ -z "$sec" ]] && warn "不能为空, 请重试"
  done
  EFFECTIVE_FAID="$id"
  EFFECTIVE_FASEC="$sec"
}

collect_inputs() {
  section "收集配置"

  # 1. provider
  if [[ -n "${CC_PROVIDER:-}" ]]; then
    if prov_is_known "$CC_PROVIDER"; then
      EFFECTIVE_PROVIDER="$CC_PROVIDER"
      step "Provider (env): $(prov_name "$EFFECTIVE_PROVIDER")"
    else
      die "未知 CC_PROVIDER: $CC_PROVIDER (可选: ${PROV_ORDER_REF[*]})"
    fi
  elif [[ "$INTERACTIVE" == "1" ]]; then
    EFFECTIVE_PROVIDER="$(prompt_provider)"
  else
    die "非 TTY 模式且未设置 CC_PROVIDER"
  fi

  # 2. base_url / model
  if [[ "$EFFECTIVE_PROVIDER" == "custom" ]]; then
    if [[ -z "${CC_BASE_URL:-}" ]]; then
      if [[ "$INTERACTIVE" == "1" ]]; then
        local u=""
        while [[ -z "$u" ]]; do
          read -r -p "$(echo -e "${BLUE}${PREFIX}${NC}  自定义 Base URL: ")" u
          [[ -z "$u" ]] && warn "不能为空"
        done
        EFFECTIVE_BASE_URL="$u"
      else
        die "CC_PROVIDER=custom 必须在非 TTY 模式下设置 CC_BASE_URL"
      fi
    else
      EFFECTIVE_BASE_URL="$CC_BASE_URL"
    fi
  else
    EFFECTIVE_BASE_URL="${CC_BASE_URL:-$(prov_base_url "$EFFECTIVE_PROVIDER")}"
  fi
  EFFECTIVE_MODEL="${CC_MODEL:-$(prov_default_model "$EFFECTIVE_PROVIDER")}"
  step "Base URL: $EFFECTIVE_BASE_URL"
  step "Model:    $EFFECTIVE_MODEL"

  # 3. API key
  if [[ -n "${CC_API_KEY:-}" ]]; then
    EFFECTIVE_API_KEY="$CC_API_KEY"
    step "API Key (env): $(mask_key "$EFFECTIVE_API_KEY")"
  elif [[ "$INTERACTIVE" == "1" ]]; then
    EFFECTIVE_API_KEY="$(prompt_api_key "$(prov_name "$EFFECTIVE_PROVIDER")" "$(prov_key_prefix "$EFFECTIVE_PROVIDER")")"
  else
    die "非 TTY 模式且未设置 CC_API_KEY"
  fi

  # 4. custom headers
  if [[ -n "${CC_CUSTOM_HEADERS:-}" ]]; then
    EFFECTIVE_HEADERS="$CC_CUSTOM_HEADERS"
  else
    EFFECTIVE_HEADERS="$(prov_extra_header "$EFFECTIVE_PROVIDER")"
  fi
  if [[ -n "$EFFECTIVE_HEADERS" ]]; then
    step "Custom Headers:"
    while IFS= read -r line; do
      [[ -n "$line" ]] && echo "      $line"
    done <<< "$EFFECTIVE_HEADERS"
  fi

  # 5. Feishu creds
  if [[ -n "${FEISHU_APP_ID:-}" && -n "${FEISHU_APP_SECRET:-}" ]]; then
    EFFECTIVE_FAID="$FEISHU_APP_ID"
    EFFECTIVE_FASEC="$FEISHU_APP_SECRET"
    step "Feishu App ID (env): $EFFECTIVE_FAID"
  elif [[ "$INTERACTIVE" == "1" ]]; then
    prompt_feishu
  else
    die "非 TTY 模式且未设置 FEISHU_APP_ID / FEISHU_APP_SECRET"
  fi

  # 6. admin_from (可选) + allow_from (强烈建议设)
  if [[ -n "${CC_ADMIN_FROM:-}" ]]; then
    EFFECTIVE_ADMIN="$CC_ADMIN_FROM"
  elif [[ "$INTERACTIVE" == "1" ]]; then
    local a=""
    read -r -p "$(echo -e "${BLUE}${PREFIX}${NC}  飞书管理员 User ID (ou_xxx, 可留空, 之后用 /whoami 获得) [空]: ")" a
    EFFECTIVE_ADMIN="$a"
  else
    EFFECTIVE_ADMIN=""
  fi
  if [[ -n "$EFFECTIVE_ADMIN" ]]; then
    step "Feishu Admin: $EFFECTIVE_ADMIN"
  fi

  if [[ -n "${CC_ALLOW_FROM:-}" ]]; then
    EFFECTIVE_ALLOW="$CC_ALLOW_FROM"
  elif [[ "$INTERACTIVE" == "1" ]]; then
    local al=""
    read -r -p "$(echo -e "${BLUE}${PREFIX}${NC}  飞书允许的用户 open_id (逗号分隔 ou_xxx, 留空=不限制任何人都能调, 用 /whoami 获得) [空]: ")" al
    EFFECTIVE_ALLOW="$al"
  else
    EFFECTIVE_ALLOW=""
  fi
  if [[ -n "$EFFECTIVE_ALLOW" ]]; then
    step "Feishu Allow From: $EFFECTIVE_ALLOW"
  else
    warn "未设 allow_from — 任何人都能调你的机器人 (安全风险)"
  fi

  # 7. 项目元信息
  local default_name="cc-bot"
  local default_work="$REAL_HOME"
  local default_mode="default"
  if [[ -n "${CC_PROJECT_NAME:-}" ]]; then
    EFFECTIVE_NAME="$CC_PROJECT_NAME"
  elif [[ "$INTERACTIVE" == "1" ]]; then
    prompt_text "项目名" "$default_name" "EFFECTIVE_NAME"
  else
    EFFECTIVE_NAME="$default_name"
  fi
  if [[ -n "${CC_WORK_DIR:-}" ]]; then
    EFFECTIVE_WORK_DIR="$CC_WORK_DIR"
  elif [[ "$INTERACTIVE" == "1" ]]; then
    prompt_text "工作目录" "$default_work" "EFFECTIVE_WORK_DIR"
  else
    EFFECTIVE_WORK_DIR="$default_work"
  fi
  if [[ -n "${CC_MODE:-}" ]]; then
    EFFECTIVE_MODE="$CC_MODE"
  elif [[ "$INTERACTIVE" == "1" ]]; then
    prompt_text "Agent 权限模式 (default / bypassPermissions)" "$default_mode" "EFFECTIVE_MODE"
  else
    EFFECTIVE_MODE="$default_mode"
  fi

  step "Project: $EFFECTIVE_NAME  WorkDir: $EFFECTIVE_WORK_DIR  Mode: $EFFECTIVE_MODE"
}

# ============================================================================
#  6. TOML / 脱敏辅助
# ============================================================================
toml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

mask_key() {
  local k="$1"
  if [[ ${#k} -le 4 ]]; then
    printf '***'
  else
    printf '%s***' "${k:0:4}"
  fi
}

# JSON 字符串转义 (用于 ~/.claude/settings.json)
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

# ============================================================================
#  7. 目录准备 & 备份
# ============================================================================
prep_dir() {
  local dir="$REAL_HOME/.cc-connect"
  mkdir -p "$dir"
  chmod 700 "$dir"
  echo "$dir"
}

backup_config() {
  local cfg="$1"
  if [[ -f "$cfg" ]]; then
    local bak
    bak="${cfg}.bak.$(date +%s)"
    if cp -p "$cfg" "$bak" 2>/dev/null; then
      ok "已备份旧配置: $bak"
    else
      warn "备份旧配置失败 (继续)"
    fi
  fi
}

# ============================================================================
#  8. 写 config.toml
# ============================================================================
write_config() {
  local dir="$1"
  local cfg="$dir/config.toml"
  local provider_ref
  provider_ref="$(prov_ref_slug "$EFFECTIVE_PROVIDER")"

  # cc-connect 支持 ${VAR_NAME} envsubst (见 `cc-connect config example` 头部),
  # 且 `daemon install` 默认会扫描配置里的 ${VAR} 占位符, 自动把当前进程 env
  # 对应值注入到 systemd Environment= / launchd EnvironmentVariables.
  # 我们写占位符 → daemon install 捕获 → service 拉起时拿 env → cc-connect 做 envsubst.
  #
  # 注意: 占位符必须是**确定且通用**的 var 名, 不能写用户输入的临时名,
  # 因为 daemon install 时它只看到 ${X} 占位符, 需要从 env 里读 X 的值.

  local data_dir_toml work_dir_toml
  data_dir_toml="$(toml_escape "$dir")"
  work_dir_toml="$(toml_escape "$EFFECTIVE_WORK_DIR")"
  local name_toml model_toml base_url_toml
  name_toml="$(toml_escape "$EFFECTIVE_NAME")"
  model_toml="$(toml_escape "$EFFECTIVE_MODEL")"
  base_url_toml="$(toml_escape "$EFFECTIVE_BASE_URL")"
  local mode_toml
  mode_toml="$(toml_escape "$EFFECTIVE_MODE")"

  local admin_line=""
  if [[ -n "$EFFECTIVE_ADMIN" ]]; then
    # cc-connect 官方格式: 逗号分隔字符串, 不是数组
    # 例: admin_from = "ou_aaa,ou_bbb"
    admin_line="admin_from = $(toml_escape "$EFFECTIVE_ADMIN")"
  fi

  local allow_line=""
  if [[ -n "$EFFECTIVE_ALLOW" ]]; then
    # platforms.options.allow_from: 逗号分隔 open_id 字符串
    allow_line="allow_from = $(toml_escape "$EFFECTIVE_ALLOW")"
  fi

  # 生成 [[providers.models]] 列表 (供 /model 命令切换)
  local models_toml=""
  local m
  for m in $(prov_models "$EFFECTIVE_PROVIDER"); do
    models_toml="${models_toml}
  [[providers.models]]
    model = $(toml_escape "$m")"
  done

  cat > "$cfg" <<EOF
# generated by install-cc-connect-pro.sh v${SCRIPT_VERSION} on $(date -Iseconds)
# 文档: https://github.com/chenhg5/cc-connect/blob/main/INSTALL.md
# provider: $(prov_name "$EFFECTIVE_PROVIDER")  ($EFFECTIVE_PROVIDER)
#
# secrets 用 \${VAR} 占位符, daemon install 会自动捕获到 systemd Environment=
# (前提: 跑脚本的 shell 里 export 了对应 var; curl ... | bash 时用 sudo -E 保留)

language = "zh"
data_dir = $data_dir_toml
attachment_send = "on"
idle_timeout_mins = 120

[log]
level = "info"

# ---- 显示设置 (cc-connect v1.4+) ----
[display]
mode = "compact"          # full / compact / quiet
thinking_messages = false
thinking_max_len = 300
tool_max_len = 500
tool_messages = true
show_context_indicator = true
reply_footer = true

# ---- 流式预览 (飞书/ Telegram / Discord) ----
[stream_preview]
enabled = true
interval_ms = 1500

# ---- 定时任务默认会话模式: reuse 避免 cron 推送丢消息 ----
[cron]
session_mode = "reuse"

# ---- LLM Provider ----
[[providers]]
name = $(toml_escape "$provider_ref")
api_key = "\${CC_API_KEY}"
base_url = $base_url_toml
model = $model_toml
agent_types = ["claudecode"]${models_toml}

# ---- Project ----
[[projects]]
name = $name_toml
$admin_line

[projects.agent]
type = "claudecode"
provider_refs = [$(toml_escape "$provider_ref")]

[projects.agent.options]
work_dir = $work_dir_toml
mode = $mode_toml

# ---- Feishu Platform ----
[[projects.platforms]]
type = "feishu"

[projects.platforms.options]
app_id = "\${FEISHU_APP_ID}"
app_secret = "\${FEISHU_APP_SECRET}"
enable_feishu_card = true
reaction_emoji = "OnIt"
done_emoji = "none"
$allow_line
EOF

  chmod 600 "$cfg"
  ok "配置已写入: $cfg (权限 600, secrets 用 \${VAR} 占位符)"
}

# ============================================================================
#  9. 写 ~/.claude/settings.json (env 块) — 仅非 Anthropic 时
# ============================================================================
write_claude_settings() {
  if [[ "$EFFECTIVE_PROVIDER" == "anthropic" ]]; then
    step "Provider=Anthropic 官方, 跳过 ~/.claude/settings.json (用户应已 claude login)"
    return
  fi

  local sdir="$REAL_HOME/.claude"
  mkdir -p "$sdir"
  chmod 700 "$sdir"
  local sfile="$sdir/settings.json"

  if [[ -f "$sfile" ]]; then
    local bak
    bak="${sfile}.cc-bak.$(date +%s)"
    cp -p "$sfile" "$bak" 2>/dev/null && ok "已备份旧 settings.json: $bak"
  fi

  # 用 jq 写最稳, 但 jq 不是必装, 有就优雅回退
  local base_url_e model_e auth_e headers_e
  base_url_e="$(json_escape "$EFFECTIVE_BASE_URL")"
  model_e="$(json_escape "$EFFECTIVE_MODEL")"
  auth_e="$(json_escape "$EFFECTIVE_API_KEY")"
  headers_e="$(json_escape "$EFFECTIVE_HEADERS")"

  # 用 printf 拼接, 避免 heredoc 缩进问题
  local payload
  if [[ -n "$EFFECTIVE_HEADERS" ]]; then
    payload=$(printf '{\n  "env": {\n    "ANTHROPIC_BASE_URL": %s,\n    "ANTHROPIC_AUTH_TOKEN": %s,\n    "ANTHROPIC_MODEL": %s,\n    "ANTHROPIC_CUSTOM_HEADERS": %s\n  }\n}\n' \
      "$base_url_e" "$auth_e" "$model_e" "$headers_e")
  else
    payload=$(printf '{\n  "env": {\n    "ANTHROPIC_BASE_URL": %s,\n    "ANTHROPIC_AUTH_TOKEN": %s,\n    "ANTHROPIC_MODEL": %s\n  }\n}\n' \
      "$base_url_e" "$auth_e" "$model_e")
  fi

  if command -v jq &>/dev/null; then
    if ! echo "$payload" | jq . > "$sfile" 2>/dev/null; then
      warn "jq 格式化失败, 退回手写 JSON"
      printf '%s\n' "$payload" > "$sfile"
    fi
  else
    printf '%s\n' "$payload" > "$sfile"
  fi
  chmod 600 "$sfile"
  ok "Claude settings 已写入: $sfile (权限 600)"
}

# ============================================================================
#  10. Service Manager 抽象
# ============================================================================
service_manager_init() {
  # cc-connect daemon install/start/status 自己已封装 systemd/launchd 差异,
  # 脚本只关心 lingler 和 macOS LaunchAgent 安全网. SVC_DOMAIN 仅用于 dry-run 展示.
  case "$OS_FAMILY" in
    linux-deb|linux-rpm|linux-arch)
      SVC_DOMAIN="--user (systemd)"
      ;;
    macos)
      SVC_DOMAIN="user (launchd)"
      ;;
  esac
}

# ============================================================================
#  11. 装为后台服务
# ============================================================================
enable_linger_or_load() {
  # 简化模式: root 用户的 systemd 服务本来就一直在, 不需要 enable-linger.
  # 留给 macOS 的 LaunchAgent bootstrap.
  if [[ "$OS_FAMILY" == "macos" ]]; then
    step "macOS LaunchAgent 准备..."
  fi
}

# 简化模式: 直接执行 (root 已是运行用户, macOS 已是当前用户)
run_as_real_user() {
  "$@"
}

service_install_and_start() {
  local cfg="$1"
  enable_linger_or_load

  step "安装 cc-connect daemon (config: $cfg)..."
  local capture_flag=""
  if [[ "${CC_NO_CAPTURE_SECRETS:-0}" == "1" ]]; then
    capture_flag="--no-capture-secrets"
  fi
  run_as_real_user cc-connect daemon install --config "$cfg" --force $capture_flag || \
    die "cc-connect daemon install 失败"

  # macOS 安全网: 确认 LaunchAgent 已 bootstrap
  if [[ "$OS_FAMILY" == "macos" ]]; then
    local plist="$REAL_HOME/Library/LaunchAgents/cc-connect.plist"
    if [[ -f "$plist" ]]; then
      launchctl bootstrap "gui/$UID" "$plist" 2>/dev/null || true
    fi
  fi

  step "启动 daemon..."
  if ! run_as_real_user cc-connect daemon start; then
    warn "daemon start 失败, 查看日志:"
    run_as_real_user cc-connect daemon logs -n 30 || true
    die "请检查日志后重试"
  fi
  sleep 2
  verify_daemon
}

verify_daemon() {
  local tries=3 rc=1 i
  for i in $(seq 1 $tries); do
    if run_as_real_user cc-connect daemon status &>/dev/null; then
      rc=0
      break
    fi
    sleep 1
  done
  if (( rc == 0 )); then
    ok "cc-connect daemon 已运行"
  else
    warn "daemon 状态异常, 日志尾部:"
    run_as_real_user cc-connect daemon logs -n 30 || true
    return 1
  fi
}

# ============================================================================
#  12. 打印最终摘要
# ============================================================================
print_summary() {
  local dir="$1"
  cat <<EOF

${GREEN}============================================================${NC}
  ${GREEN}${BOLD}安装完成! 🎉${NC}
${GREEN}============================================================${NC}

  配置文件:  ${CYAN}${dir}/config.toml${NC}  (chmod 600)
  日志文件:  ${CYAN}${dir}/logs/cc-connect.log${NC}
  Provider:  ${CYAN}$(prov_name "$EFFECTIVE_PROVIDER")${NC}
  Base URL:  ${CYAN}${EFFECTIVE_BASE_URL}${NC}
  Model:     ${CYAN}${EFFECTIVE_MODEL}${NC}
  Project:   ${CYAN}${EFFECTIVE_NAME}${NC}
  Work Dir:  ${CYAN}${EFFECTIVE_WORK_DIR}${NC}
  Platform:  ${CYAN}feishu${NC}

  后续命令:
    cc-connect daemon status          # 查看服务状态
    cc-connect daemon logs -f         # 实时日志
    cc-connect daemon restart         # 重启
    cc-connect daemon stop            # 停止
    cc-connect config path            # 配置文件路径
    cc-connect provider list          # 列出已配置 provider
    cc-connect model list             # 列出可用模型 (聊天里用 /model switch <模型名> 切换)

${YELLOW}下一步: 打开飞书, 找到刚创建的机器人, 发送 ${BOLD}/whoami${NC}${YELLOW}${NC}
  - 第一次发消息会回给你 User ID (ou_xxx 开头)
  - 把它发给安装者, 加到 config.toml 的 admin_from 字段以解锁特权命令
  - 然后发送 /dir 即可开始使用
  - cron 任务已默认使用 session_mode = "reuse", 避免推送丢消息

  升级:  sudo npm update -g cc-connect @anthropic-ai/claude-code
  卸载:  bash $0 --uninstall
  文档:  https://inst.xlm666.top
EOF
}

# ============================================================================
#  13. 错误处理 & 卸载
# ============================================================================
on_error() {
  local rc=$? lineno=${BASH_LINENO[0]}
  err "安装失败于第 ${lineno} 行 (exit ${rc})"
  err "已写入文件可能不完整, 请检查: $REAL_HOME/.cc-connect/"
  err "查看日志: $REAL_HOME/.cc-connect/logs/cc-connect.log"
  err "重试:    bash $0"
  err "清理:    bash $0 --uninstall"
  exit "$rc"
}

uninstall() {
  section "卸载 cc-connect"
  step "停止 daemon..."
  run_as_real_user cc-connect daemon stop 2>/dev/null || true
  run_as_real_user cc-connect daemon uninstall 2>/dev/null || true

  if [[ "$OS_FAMILY" == "macos" ]]; then
    step "移除 LaunchAgent (macOS)..."
    launchctl bootout "gui/$UID" "$REAL_HOME/Library/LaunchAgents/cc-connect.plist" 2>/dev/null || true
    rm -f "$REAL_HOME/Library/LaunchAgents/cc-connect.plist" 2>/dev/null || true
  fi

  step "删除 $REAL_HOME/.cc-connect ..."
  rm -rf "$REAL_HOME/.cc-connect"
  ok "已卸载 (npm 全局包未删, 跑: npm uninstall -g cc-connect @anthropic-ai/claude-code)"
  exit 0
}

# ============================================================================
#  14. 参数解析
# ============================================================================
parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        cat <<EOF
Usage: bash $0 [options]

Options:
  --uninstall           卸载已安装的 cc-connect + 配置
  --print-config        打印将生成的 config.toml 到 stdout 然后退出
  --dry-run             打印所有将要执行的动作然后退出 (不实际安装)
  --force-npm           强制重装 cc-connect / claude-code
  --no-capture-secrets  不把 \${VAR} 占位符捕获到 systemd Environment= (默认会捕获, 推荐保持)
  -v|--version          打印脚本版本
  -h|--help             显示此帮助

环境变量 (非 TTY / curl|bash 模式):
  CC_PROVIDER           anthropic / minimax / deepseek / glm / kimi / openrouter / custom
  CC_API_KEY            LLM API Key
  CC_BASE_URL           自定义 Base URL (仅 CC_PROVIDER=custom)
  CC_MODEL              自定义 Model 名称
  CC_CUSTOM_HEADERS     格式: "Header: value\\nHeader2: value2"
  FEISHU_APP_ID         飞书 App ID
  FEISHU_APP_SECRET     飞书 App Secret
  CC_ADMIN_FROM         飞书管理员 User ID (ou_xxx, 可选, 启用 /shell /restart 等特权命令)
  CC_ALLOW_FROM         飞书允许的用户 User ID (逗号分隔 ou_xxx, 留空=任何人都能调)
  CC_PROJECT_NAME       项目名 (默认: cc-bot)
  CC_WORK_DIR           工作目录 (默认: \$REAL_HOME)
  CC_MODE               default / acceptEdits / plan / auto / bypassPermissions (默认: default)
  CC_FORCE_NPM=1        强制重装 npm 全局包
  CC_DRY_RUN=1          dry-run 模式
  CC_UNINSTALL=1        走卸载路径

示例 (curl|bash 一行复制):
  export CC_PROVIDER=kimi CC_API_KEY=sk-kimi-xxx FEISHU_APP_ID=cli_xxx FEISHU_APP_SECRET=xxx
  curl -fsSL $SCRIPT_URL_DEFAULT | sudo -E bash

来源: https://inst.xlm666.top
EOF
        exit 0
        ;;
      -v|--version)
        echo "install-cc-connect-pro.sh v${SCRIPT_VERSION}"
        exit 0
        ;;
      --uninstall)
        detect_os 2>/dev/null || true
        real_user_and_home
        uninstall
        ;;
      --print-config)
        CC_PRINT_CONFIG=1
        shift
        ;;
      --dry-run)
        CC_DRY_RUN=1
        shift
        ;;
      --force-npm)
        export CC_FORCE_NPM=1
        shift
        ;;
      --no-capture-secrets)
        # 透传给 cc-connect daemon install: 不捕获 ${VAR} 占位符到 systemd Environment=
        # (默认会捕获, 推荐保持捕获, 这样 service 拉起时 daemon 能拿到 env 做 envsubst)
        CC_NO_CAPTURE_SECRETS=1
        shift
        ;;
      *)
        die "未知参数: $1 (用 --help 查看帮助)"
        ;;
    esac
  done
}

# ============================================================================
#  15. main
# ============================================================================
main() {
  parse_args "$@"

  # 全局 trap (在 uninstall / dry-run 之后注册, 避免误触发)
  trap on_error ERR INT TERM

  load_provider_presets

  echo
  echo -e "${BOLD}${GREEN}============================================================${NC}"
  echo -e "${BOLD}${GREEN}  Claude Code + cc-connect 一键安装 (Pro v${SCRIPT_VERSION})${NC}"
  echo -e "${BOLD}${GREEN}  支持 6 家 LLM 预设 + 自定义 URL + 飞书平台 (cc-connect v1.4+)${NC}"
  echo -e "${BOLD}${GREEN}============================================================${NC}"
  echo

  if [[ "${CC_DRY_RUN:-0}" == "1" ]]; then
    ok "DRY-RUN 模式: 只打印动作, 不实际执行"
  fi

  section "环境探测"
  require_root
  detect_os
  real_user_and_home
  decide_interactive
  service_manager_init

  if [[ "$INTERACTIVE" != "1" ]]; then
    step "非 TTY 模式 (curl|bash), 走环境变量"
  else
    step "交互模式 (download-then-bash)"
  fi

  # 收集输入
  collect_inputs

  # dry-run 在此之后退出
  if [[ "${CC_DRY_RUN:-0}" == "1" ]]; then
    section "DRY-RUN 计划"
    cat <<EOF
将执行:
  - OS:           ${OS_FAMILY} (${OS_ID} ${OS_VERSION})
  - Real user:    ${REAL_USER} (home: ${REAL_HOME})
  - Provider:     $(prov_name "$EFFECTIVE_PROVIDER") ($EFFECTIVE_PROVIDER)
  - Base URL:     ${EFFECTIVE_BASE_URL}
  - Model:        ${EFFECTIVE_MODEL}
  - Project:      ${EFFECTIVE_NAME}
  - Work Dir:     ${EFFECTIVE_WORK_DIR}
  - Mode:         ${EFFECTIVE_MODE}
  - Feishu ID:    ${EFFECTIVE_FAID}
  - Admin:        ${EFFECTIVE_ADMIN:-<none>}
  - Allow:        ${EFFECTIVE_ALLOW:-<anyone>}
  - SVC domain:   ${SVC_DOMAIN}
  - API Key:      $(mask_key "$EFFECTIVE_API_KEY")

将创建/修改:
  - ${REAL_HOME}/.cc-connect/                            (700)
  - ${REAL_HOME}/.cc-connect/config.toml                 (600)
EOF
    if [[ "$EFFECTIVE_PROVIDER" != "anthropic" ]]; then
      echo "  - ${REAL_HOME}/.claude/settings.json             (600)"
    fi
    ok "DRY-RUN 完成, 实际未做任何修改"
    exit 0
  fi

  # print-config 模式
  if [[ "${CC_PRINT_CONFIG:-0}" == "1" ]]; then
    section "生成的 config.toml 预览"
    local tmpdir
    tmpdir=$(mktemp -d)
    write_config "$tmpdir" 2>&1 | sed 's/^/  /'
    cat "$tmpdir/config.toml"
    rm -rf "$tmpdir"
    exit 0
  fi

  section "工具链安装"
  need_node
  install_cc_connect
  install_claude_code

  section "准备目录 & 写配置"
  local dir
  dir="$(prep_dir)"
  backup_config "$dir/config.toml"
  write_config "$dir"
  write_claude_settings

  section "安装并启动 daemon"
  service_install_and_start "$dir/config.toml"

  print_summary "$dir"
}

main "$@"
