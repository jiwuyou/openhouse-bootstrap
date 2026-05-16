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

detect_openhouse_runtime() {
  if is_current_ubuntu; then
    printf 'ubuntu'
    return 0
  fi

  if [ -x "${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouse-env-probe" ]; then
    "${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouse-env-probe" 2>/dev/null \
      | awk -F= '$1=="OPENHOUSE_RUNTIME"{print $2; found=1} END{if(!found) exit 1}' \
      && return 0
  fi

  if is_termux; then
    printf 'termux'
    return 0
  fi

  printf 'unknown'
}

run_environment_probe() {
  local probe="${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouse-env-probe"
  if [ -x "$probe" ]; then
    log "正在执行环境探测命令：$probe"
    run_logged "$probe" || true
  else
    log "环境探测命令不存在，使用内置探测逻辑。"
  fi
  log "当前运行环境：$(detect_openhouse_runtime)"
}

run_environment_probe

if is_termux && [ "${OPENHOUSE_REQUIRED_COMPONENTS_IN_UBUNTU:-1}" = "1" ]; then
  if command -v proot-distro >/dev/null 2>&1 && proot-distro login ubuntu -- true >/dev/null 2>&1; then
    log "正在 Ubuntu 内安装 OpenHouse 必要组件。"
    OPENHOUSE_REQUIRED_COMPONENTS_IN_UBUNTU=0 \
      proot-distro login ubuntu -- env \
        OPENHOUSE_COMPONENT_REPO_ROOT="${OPENHOUSE_COMPONENT_REPO_ROOT:-/root/openhouse-repos}" \
        OPENHOUSE_COMPONENTS_AUTO_CLONE="${OPENHOUSE_COMPONENTS_AUTO_CLONE:-1}" \
        OPENHOUSE_COMPONENTS_STRICT="${OPENHOUSE_COMPONENTS_STRICT:-1}" \
        OPENHOUSE_REQUIRED_COMPONENT_TARGETS="${OPENHOUSE_REQUIRED_COMPONENT_TARGETS:-}" \
        OPENHOUSE_INSTALL_DOC_COMPONENTS="${OPENHOUSE_INSTALL_DOC_COMPONENTS:-0}" \
        bash -s < "$0"
    exit $?
  fi
  warn "Ubuntu 尚不可用，将在当前 Termux 环境尝试安装组件。"
fi

export PATH="$HOME/.local/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

repo_root="${OPENHOUSE_COMPONENT_REPO_ROOT:-$HOME/openhouse-repos}"
auto_clone="${OPENHOUSE_COMPONENTS_AUTO_CLONE:-1}"
strict="${OPENHOUSE_COMPONENTS_STRICT:-1}"
component_targets="${OPENHOUSE_REQUIRED_COMPONENT_TARGETS:-}"
failures=0

should_run_component() {
  local target="$1"
  if [ -z "$component_targets" ]; then
    return 0
  fi

  case ",$component_targets," in
    *,"$target",*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_component_targets() {
  local target rest
  rest="$component_targets"
  [ -n "$rest" ] || return 0

  while [ -n "$rest" ]; do
    case "$rest" in
      *,*)
        target="${rest%%,*}"
        rest="${rest#*,}"
        ;;
      *)
        target="$rest"
        rest=""
        ;;
    esac

    [ -n "$target" ] || continue
    case "$target" in
      service-manager|cc-connect|cc-proxy|openhouse-key-tool|smallphone|openhouse-app-guide-site|openhouse-docs)
        ;;
      *)
        warn "未知组件目标：$target"
        failures=$((failures + 1))
        ;;
    esac
  done
}

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
if [ -n "$component_targets" ]; then
  log "本次仅安装指定组件：$component_targets"
else
  log "本次安装默认必要组件集合。"
fi

validate_component_targets

service_manager_required="${OPENHOUSE_SERVICE_MANAGER_REQUIRED:-1}"
if [ "$service_manager_required" != "1" ]; then
  log "service-manager 当前按可选组件处理；如需默认必装，请恢复 OPENHOUSE_SERVICE_MANAGER_REQUIRED=1。"
fi
if should_run_component "service-manager"; then
  run_component "service-manager" "$service_manager_dir" "${OPENHOUSE_SERVICE_MANAGER_GIT_URL:-https://github.com/jiwuyou/service-manager.git}" "$service_manager_required"
fi
if should_run_component "cc-connect"; then
  run_component "cc-connect" "$cc_connect_dir" "${OPENHOUSE_CC_CONNECT_GIT_URL:-https://github.com/jiwuyou/openhouse-connect.git}" "1"
fi
if should_run_component "cc-proxy"; then
  run_component "cc-proxy" "$cc_proxy_dir" "${OPENHOUSE_CC_PROXY_GIT_URL:-https://github.com/jiwuyou/cc-proxy.git}" "1"
fi
if should_run_component "openhouse-key-tool"; then
  run_component "openhouse-key-tool" "$key_tool_dir" "${OPENHOUSE_KEY_TOOL_GIT_URL:-https://github.com/jiwuyou/openhouse-key-tool.git}" "1"
fi
if should_run_component "smallphone"; then
  run_component "smallphone" "$smallphone_dir" "${OPENHOUSE_SMALLPHONE_GIT_URL:-https://github.com/jiwuyou/wuxian-smallphone.git}" "1"
fi

if [ -n "$component_targets" ]; then
  if should_run_component "openhouse-app-guide-site"; then
    run_component "openhouse-app-guide-site" "$guide_site_dir" "${OPENHOUSE_GUIDE_SITE_GIT_URL:-https://github.com/jiwuyou/openhouse-app-guide-site.git}" "0"
  fi
  if should_run_component "openhouse-docs"; then
    run_component "openhouse-docs" "$docs_dir" "${OPENHOUSE_DOCS_GIT_URL:-https://github.com/jiwuyou/openhouse-docs.git}" "0"
  fi
elif [ "${OPENHOUSE_INSTALL_DOC_COMPONENTS:-0}" = "1" ]; then
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
