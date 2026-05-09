#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[OpenHouse] %s\n' "$*"
}

warn() {
  printf '[OpenHouse] WARN: %s\n' "$*" >&2
}

run_logged() {
  log "+ $*"
  "$@"
}

is_termux() {
  [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/bin" ] && [ -d "/data/data/com.termux/files" ]
}

is_current_ubuntu() {
  [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release
}

if is_termux && [ "${OPENHOUSE_REQUIRED_COMPONENTS_IN_UBUNTU:-1}" = "1" ]; then
  if command -v proot-distro >/dev/null 2>&1 && proot-distro login ubuntu -- true >/dev/null 2>&1; then
    log "正在 Ubuntu 内安装 OpenHouse 必要组件。"
    OPENHOUSE_REQUIRED_COMPONENTS_IN_UBUNTU=0 \
      proot-distro login ubuntu -- env \
        OPENHOUSE_COMPONENT_REPO_ROOT="${OPENHOUSE_COMPONENT_REPO_ROOT:-/root/openhouse-repos}" \
        OPENHOUSE_COMPONENTS_AUTO_CLONE="${OPENHOUSE_COMPONENTS_AUTO_CLONE:-1}" \
        OPENHOUSE_COMPONENTS_STRICT="${OPENHOUSE_COMPONENTS_STRICT:-1}" \
        bash -s < "$0"
    exit $?
  fi
  warn "Ubuntu 尚不可用，将在当前 Termux 环境尝试安装组件。"
fi

export PATH="$HOME/.local/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

repo_root="${OPENHOUSE_COMPONENT_REPO_ROOT:-$HOME/openhouse-repos}"
auto_clone="${OPENHOUSE_COMPONENTS_AUTO_CLONE:-1}"
strict="${OPENHOUSE_COMPONENTS_STRICT:-1}"
failures=0

default_path() {
  local dev_path="$1"
  local repo_name="$2"
  if [ -d "$dev_path" ]; then
    printf '%s\n' "$dev_path"
  else
    printf '%s/%s\n' "$repo_root" "$repo_name"
  fi
}

clone_repo_if_needed() {
  local name="$1"
  local dir="$2"
  local url="$3"

  if [ -d "$dir/.git" ] || [ -d "$dir" ]; then
    return 0
  fi

  if [ "$auto_clone" != "1" ]; then
    warn "$name: 未找到仓库 $dir，且 OPENHOUSE_COMPONENTS_AUTO_CLONE 未开启。"
    return 1
  fi

  if [ -z "$url" ]; then
    warn "$name: 未配置 git URL，无法自动拉取。"
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    warn "$name: 缺少 git，无法自动拉取 $url。"
    return 1
  fi

  mkdir -p "$(dirname "$dir")"
  log "$name: 正在拉取仓库 $url -> $dir"
  git clone --depth 1 "$url" "$dir"
}

run_repo_script() {
  local name="$1"
  local dir="$2"
  local script="$3"
  local required="$4"
  local path="$dir/$script"

  if [ ! -f "$path" ]; then
    if [ "$required" = "1" ]; then
      warn "$name: 缺少必要入口 $path"
      failures=$((failures + 1))
    else
      warn "$name: 可选入口不存在，跳过 $path"
    fi
    return 0
  fi

  chmod +x "$path"
  log "$name: 执行 $script"
  if ! (cd "$dir" && run_logged "./$script"); then
    if [ "$required" = "1" ]; then
      warn "$name: $script 执行失败"
      failures=$((failures + 1))
    else
      warn "$name: 可选入口 $script 执行失败，继续。"
    fi
  fi
}

run_component() {
  local name="$1"
  local dir="$2"
  local url="$3"
  local required="$4"

  if ! clone_repo_if_needed "$name" "$dir" "$url"; then
    if [ "$required" = "1" ]; then
      failures=$((failures + 1))
    fi
    return 0
  fi

  run_repo_script "$name" "$dir" "scripts/install.sh" "$required"
  run_repo_script "$name" "$dir" "scripts/check.sh" "$required"
  run_repo_script "$name" "$dir" "scripts/register-service.sh" "0"
}

cc_connect_dir="${OPENHOUSE_CC_CONNECT_DIR:-$(default_path /root/cc-connect-fresh openhouse-connect)}"
cc_proxy_dir="${OPENHOUSE_CC_PROXY_DIR:-$(default_path /root/projects/cc-proxy cc-proxy)}"
key_tool_dir="${OPENHOUSE_KEY_TOOL_DIR:-$(default_path /root/projects/openhouse-key-tool openhouse-key-tool)}"
smallphone_dir="${OPENHOUSE_SMALLPHONE_DIR:-$(default_path /root/projects/smallphone/smallphone-active smallphone-active)}"
service_manager_dir="${OPENHOUSE_SERVICE_MANAGER_DIR:-$(default_path /root/projects/service-manager service-manager)}"
guide_site_dir="${OPENHOUSE_GUIDE_SITE_DIR:-$(default_path /root/openhouse-app-guide-site openhouse-app-guide-site)}"
docs_dir="${OPENHOUSE_DOCS_DIR:-$(default_path /root/openhouse-docs openhouse-docs)}"

log "OpenHouse 必要组件安装入口由各子仓库维护。"
log "组件仓库根目录：$repo_root"

service_manager_required="${OPENHOUSE_SERVICE_MANAGER_REQUIRED:-1}"
if [ "$service_manager_required" != "1" ]; then
  log "service-manager 当前按可选组件处理；如需默认必装，请恢复 OPENHOUSE_SERVICE_MANAGER_REQUIRED=1。"
fi
run_component "service-manager" "$service_manager_dir" "${OPENHOUSE_SERVICE_MANAGER_GIT_URL:-https://github.com/jiwuyou/service-manager.git}" "$service_manager_required"
run_component "cc-connect" "$cc_connect_dir" "${OPENHOUSE_CC_CONNECT_GIT_URL:-https://github.com/jiwuyou/openhouse-connect.git}" "1"
run_component "cc-proxy" "$cc_proxy_dir" "${OPENHOUSE_CC_PROXY_GIT_URL:-https://github.com/jiwuyou/cc-proxy.git}" "1"
run_component "openhouse-key-tool" "$key_tool_dir" "${OPENHOUSE_KEY_TOOL_GIT_URL:-https://github.com/jiwuyou/openhouse-key-tool.git}" "1"
run_component "smallphone" "$smallphone_dir" "${OPENHOUSE_SMALLPHONE_GIT_URL:-https://github.com/jiwuyou/wuxian-smallphone.git}" "1"

if [ "${OPENHOUSE_INSTALL_DOC_COMPONENTS:-0}" = "1" ]; then
  log "OPENHOUSE_INSTALL_DOC_COMPONENTS=1，安装/检查文档和说明站组件。"
  run_component "openhouse-app-guide-site" "$guide_site_dir" "${OPENHOUSE_GUIDE_SITE_GIT_URL:-https://github.com/jiwuyou/openhouse-app-guide-site.git}" "0"
  run_component "openhouse-docs" "$docs_dir" "${OPENHOUSE_DOCS_GIT_URL:-https://github.com/jiwuyou/openhouse-docs.git}" "0"
else
  log "默认跳过 docs/guide 构建依赖；如需安装文档组件，请设置 OPENHOUSE_INSTALL_DOC_COMPONENTS=1。"
fi

if [ "$failures" -ne 0 ]; then
  if [ "$strict" = "1" ]; then
    warn "OpenHouse 必要组件安装存在 $failures 个失败项。"
    exit 1
  fi
  warn "OpenHouse 必要组件存在 $failures 个失败项；OPENHOUSE_COMPONENTS_STRICT=0，继续。"
fi

log "OpenHouse 必要组件安装阶段完成。"
