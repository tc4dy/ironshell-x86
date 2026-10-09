# for auto setup make, qemu setup, git clone etc only run

set -Eeuo pipefail
IFS=$'\n\t'

readonly REPO_URL="https://github.com/tc4dy/ironshell-x86.git"
readonly SUBDIR="ironshell-x86"
readonly QEMU_BIN="qemu-system-i386"
readonly NASM_BIN="nasm"
readonly GIT_BIN="git"

readonly C_RESET="\033[0m"
readonly C_RED="\033[1;31m"
readonly C_GREEN="\033[1;32m"
readonly C_YELLOW="\033[1;33m"
readonly C_BLUE="\033[1;34m"
readonly C_CYAN="\033[1;36m"

WORKDIR=""
TMP_ROOT=""
KEEP_ARTIFACTS=0

log_info()  { printf "${C_BLUE}[*]${C_RESET} %s\n" "$*" >&2; }
log_ok()    { printf "${C_GREEN}[+]${C_RESET} %s\n" "$*" >&2; }
log_warn()  { printf "${C_YELLOW}[!]${C_RESET} %s\n" "$*" >&2; }
log_err()   { printf "${C_RED}[x]${C_RESET} %s\n" "$*" >&2; }
log_step()  { printf "${C_CYAN}[>]${C_RESET} %s\n" "$*" >&2; }

cleanup() {
    local code=$?
    if [[ -n "${TMP_ROOT}" && -d "${TMP_ROOT}" && ${KEEP_ARTIFACTS} -eq 0 ]]; then
        rm -rf -- "${TMP_ROOT}" 2>/dev/null || true
    fi
    if [[ ${code} -ne 0 ]]; then
        log_err "aborted with exit code ${code}"
        if [[ -n "${TMP_ROOT}" && -d "${TMP_ROOT}" ]]; then
            log_warn "artifacts preserved at: ${TMP_ROOT}"
        fi
    fi
    exit ${code}
}
trap cleanup EXIT INT TERM

die() {
    log_err "$*"
    exit 1
}

have_cmd() {
    command -v -- "$1" >/dev/null 2>&1
}

detect_platform() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        die "this script targets Linux hosts only (detected: $(uname -s))"
    fi
    if [[ ! -r /etc/os-release ]]; then
        die "cannot read /etc/os-release; unsupported distribution"
    fi
    . /etc/os-release
    if [[ -z "${ID:-}" ]]; then
        die "cannot determine distribution id from /etc/os-release"
    fi
    printf '%s' "${ID}"
}

pkg_manager_for() {
    case "$1" in
        debian|ubuntu|linuxmint|pop|raspbian|kali|neon|zorin|elementary|mx|deepin)
            printf '%s' "apt"
            ;;
        arch|manjaro|endeavouros|garuda|artix|cachyos|arcolinux)
            printf '%s' "pacman"
            ;;
        fedora|rhel|centos|rocky|almalinux|nobara)
            printf '%s' "dnf"
            ;;
        opensuse|opensuse-leap|opensuse-tumbleweed|sles|sled)
            printf '%s' "zypper"
            ;;
        void)
            printf '%s' "xbps"
            ;;
        alpine)
            printf '%s' "apk"
            ;;
        gentoo)
            printf '%s' "emerge"
            ;;
        *)
            printf '%s' "unknown"
            ;;
    esac
}

sudo_prefix() {
    if [[ ${EUID} -eq 0 ]]; then
        printf ''
    elif have_cmd sudo; then
        printf 'sudo'
    elif have_cmd doas; then
        printf 'doas'
    else
        die "no sudo or doas available and not running as root"
    fi
}

install_packages() {
    local pkgmgr="$1"
    shift
    local pkgs=("$@")
    local sudo_cmd
    sudo_cmd="$(sudo_prefix)"

    case "${pkgmgr}" in
        apt)
            ${sudo_cmd} apt-get update -y
            ${sudo_cmd} DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
            ;;
        pacman)
            ${sudo_cmd} pacman -Sy --noconfirm --needed "${pkgs[@]}"
            ;;
        dnf)
            ${sudo_cmd} dnf install -y "${pkgs[@]}"
            ;;
        zypper)
            ${sudo_cmd} zypper --non-interactive install -y "${pkgs[@]}"
            ;;
        xbps)
            ${sudo_cmd} xbps-install -Sy "${pkgs[@]}"
            ;;
        apk)
            ${sudo_cmd} apk add --no-cache "${pkgs[@]}"
            ;;
        emerge)
            ${sudo_cmd} emerge --ask=n --quiet "${pkgs[@]}"
            ;;
        *)
            die "unsupported package manager: ${pkgmgr}"
            ;;
    esac
}

map_package_names() {
    local pkgmgr="$1"
    case "${pkgmgr}" in
        apt)
            printf '%s\n' "git" "nasm" "qemu-system-x86" "make" "ca-certificates"
            ;;
        pacman)
            printf '%s\n' "git" "nasm" "qemu-system-x86" "make" "ca-certificates"
            ;;
        dnf)
            printf '%s\n' "git" "nasm" "qemu-system-x86" "make" "ca-certificates"
            ;;
        zypper)
            printf '%s\n' "git" "nasm" "qemu-x86" "make" "ca-certificates"
            ;;
        xbps)
            printf '%s\n' "git" "nasm" "qemu-system-i386" "make" "ca-certificates"
            ;;
        apk)
            printf '%s\n' "git" "nasm" "qemu-system-i386" "make" "ca-certificates"
            ;;
        emerge)
            printf '%s\n' "dev-vcs/git" "dev-lang/nasm" "app-emulation/qemu" "sys-devel/make" "app-misc/ca-certificates"
            ;;
        *)
            die "unsupported package manager: ${pkgmgr}"
            ;;
    esac
}

ensure_dependencies() {
    local pkgmgr="$1"
    log_step "checking required tools"

    local missing=()
    for tool in "${GIT_BIN}" "${NASM_BIN}" "${QEMU_BIN}" "make"; do
        if have_cmd "${tool}"; then
            log_ok "${tool} present"
        else
            log_warn "${tool} missing"
            missing+=("${tool}")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    log_step "installing missing dependencies via ${pkgmgr}"
    local pkgs=()
    while IFS= read -r p; do pkgs+=("${p}"); done < <(map_package_names "${pkgmgr}")
    install_packages "${pkgmgr}" "${pkgs[@]}"

    for tool in "${GIT_BIN}" "${NASM_BIN}" "${QEMU_BIN}" "make"; do
        have_cmd "${tool}" || die "installation finished but '${tool}' is still missing"
    done
    log_ok "all dependencies satisfied"
}

make_workspace() {
    TMP_ROOT="$(mktemp -d -t ironshell-XXXXXX)"
    WORKDIR="${TMP_ROOT}/ironshell-x86"
    log_info "workspace: ${TMP_ROOT}"
}

clone_repo() {
    log_step "cloning repository"
    if ! ${GIT_BIN} clone --depth 1 --recurse-submodules "${REPO_URL}" "${WORKDIR}" 2>&1 | sed 's/^/    /' >&2; then
        die "git clone failed"
    fi
    log_ok "repository cloned"
}

enter_subdir() {
    local target="${WORKDIR}/${SUBDIR}"
    if [[ ! -d "${target}" ]]; then
        log_warn "expected subdirectory '${SUBDIR}' not found; scanning"
        local found
        found="$(find "${WORKDIR}" -maxdepth 3 -type f -name 'Makefile' -print -quit || true)"
        if [[ -z "${found}" ]]; then
            die "no Makefile found in cloned repository"
        fi
        target="$(dirname "${found}")"
    fi
    cd "${target}" || die "cannot enter ${target}"
    log_ok "entered build directory: ${target}"
}

build_project() {
    log_step "building project"
    if ! make 2>&1 | sed 's/^/    /' >&2; then
        die "make failed"
    fi
    log_ok "build finished"
}

check_image() {
    local img
    img="$(find . -maxdepth 2 -type f -name '*.img' -print -quit || true)"
    if [[ -z "${img}" ]]; then
        die "no .img file produced by build"
    fi
    log_ok "disk image: ${img}"
    printf '%s' "${img}"
}

launch_qemu() {
    log_step "launching QEMU"
    log_info "exit with Ctrl+A then X (curses mode)"
    local tty_ok=1
    if [[ ! -t 0 || ! -t 1 ]]; then
        tty_ok=0
        log_warn "stdin/stdout are not a tty; curses mode may not render"
    fi

    local qemu_args=(
        -drive "format=raw,file=$(check_image)"
        -m 4M
        -cpu pentium
        -no-reboot
        -no-shutdown
    )

    if [[ ${tty_ok} -eq 1 ]]; then
        qemu_args+=(-display curses)
    else
        qemu_args+=(-display none -serial stdio)
    fi

    if ! ${QEMU_BIN} "${qemu_args[@]}"; then
        local rc=$?
        if [[ ${rc} -eq 130 || ${rc} -eq 0 ]]; then
            log_info "QEMU terminated by user"
        else
            die "QEMU exited with code ${rc}"
        fi
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -k|--keep)
                KEEP_ARTIFACTS=1
                shift
                ;;
            -h|--help)
                cat >&2 <<'EOF'
usage: run.sh [-k|--keep] [-h|--help]

  clones tc4dy/ironshell-x86, installs dependencies, builds the disk
  image and boots it under qemu-system-i386.

options:
  -k, --keep   keep the temporary workspace on exit
  -h, --help   show this message
EOF
                exit 0
                ;;
            *)
                die "unknown argument: $1"
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    log_step "ironshell-x86 bootstrap"
    local distro pkgmgr
    distro="$(detect_platform)"
    pkgmgr="$(pkg_manager_for "${distro}")"
    log_info "distribution: ${distro} (pkg manager: ${pkgmgr})"

    ensure_dependencies "${pkgmgr}"
    make_workspace
    clone_repo
    enter_subdir
    build_project
    launch_qemu

    log_ok "session finished"
}

main "$@"
