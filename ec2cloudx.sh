#!/bin/bash
#
# Install cloudX on Amazon Linux 2023
#
# This script can be run on:
# - Fresh EC2 instances (via user data)
# - Existing EC2 instances (via direct execution)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/easytocloud/cloudX/HEAD/ec2cloudx.sh | sh
#   
# Or with options:
#   curl -fsSL https://raw.githubusercontent.com/easytocloud/cloudX/HEAD/ec2cloudx.sh | sh -s -- [OPTIONS]
#
# Options:
#   --sso               Install SSO tools
#   --zsh               Install zsh and oh-my-zsh
#   --pip               Install pip and python tools
#   --docker            Install Docker
#   --anaconda          Install Anaconda
#   --nvm               Install Node Version Manager
#   --privpage          Install privpage
#   --fortools          Install for-tools
#   --sso-domain DOMAIN Set SSO domain (used with --sso)
#   --shutdown TIMEOUT  Set automatic shutdown timeout in minutes (default: 10)
#   --no-shutdown       Disable automatic shutdown
#   --help              Show this help message
#
# Notes:
# - Homebrew, uv, and direnv are always installed via Homebrew for every run.
# - Additional software can be driven via CLI options or EC2 instance tags.

set -euo pipefail

EC2_USER_HOME="/home/ec2-user"
CLOUDX_HOME="$EC2_USER_HOME/.cloudX"
ENV_FILE="$EC2_USER_HOME/.env"

install_sso=false
install_zsh=false
install_pip=false
install_docker=false
install_anaconda=false
install_nvm=false
install_privpage=false
install_fortools=false
SSODomain=""
SHUTDOWN_TIMEOUT=10
enable_shutdown=true
is_ec2=false
cli_options_provided=false

show_help() {
    grep '^#' "$0" | grep -E '(Usage:|Options:|--.*Install|--.*Set|--.*Show|--.*Disable|Notes:|- Homebrew)' | sed 's/^# \?//'
    exit 0
}

parse_cli() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --sso)
                install_sso=true
                cli_options_provided=true
                shift
                ;;
            --zsh)
                install_zsh=true
                cli_options_provided=true
                shift
                ;;
            --pip)
                install_pip=true
                cli_options_provided=true
                shift
                ;;
            --docker)
                install_docker=true
                cli_options_provided=true
                shift
                ;;
            --anaconda)
                install_anaconda=true
                cli_options_provided=true
                shift
                ;;
            --nvm)
                install_nvm=true
                cli_options_provided=true
                shift
                ;;
            --privpage)
                install_privpage=true
                cli_options_provided=true
                shift
                ;;
            --fortools)
                install_fortools=true
                cli_options_provided=true
                shift
                ;;
            --sso-domain)
                SSODomain="$2"
                shift 2
                ;;
            --shutdown)
                SHUTDOWN_TIMEOUT="$2"
                shift 2
                ;;
            --no-shutdown)
                enable_shutdown=false
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

require_amazon_linux() {
    if [ ! -f /etc/os-release ]; then
        echo "This script only supports Amazon Linux"
        exit 1
    fi
}

detect_ec2_instance() {
    if curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
        is_ec2=true
        echo "Running on EC2 instance"
    else
        is_ec2=false
        echo "Not running on EC2 or IMDS not accessible"
    fi
}

prepare_workspace() {
    touch "$EC2_USER_HOME/.install-running"
    mkdir -p "$EC2_USER_HOME/environment" "$CLOUDX_HOME"
    cd "$CLOUDX_HOME"
}

apply_tag_preferences() {
    if ! $is_ec2; then
        return
    fi

    if $cli_options_provided; then
        echo "Using CLI options for software installation"
        return
    fi

    echo "Reading software preferences from EC2 instance tags"
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    instanceId=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)

    tag_sso=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`sso`].Value' --output text 2>/dev/null)
    tag_zsh=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`zsh`].Value' --output text 2>/dev/null)
    tag_pip=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`pip`].Value' --output text 2>/dev/null)
    tag_docker=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`docker`].Value' --output text 2>/dev/null)
    tag_anaconda=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`anaconda`].Value' --output text 2>/dev/null)
    tag_nvm=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`nvm`].Value' --output text 2>/dev/null)
    tag_privpage=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`privpage`].Value' --output text 2>/dev/null)
    tag_fortools=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`fortools`].Value' --output text 2>/dev/null)

    [[ "$tag_sso" == "true" ]] && install_sso=true
    [[ "$tag_zsh" == "true" ]] && install_zsh=true
    [[ "$tag_pip" == "true" ]] && install_pip=true
    [[ "$tag_docker" == "true" ]] && install_docker=true
    [[ "$tag_anaconda" == "true" ]] && install_anaconda=true
    [[ "$tag_nvm" == "true" ]] && install_nvm=true
    [[ "$tag_privpage" == "true" ]] && install_privpage=true
    [[ "$tag_fortools" == "true" ]] && install_fortools=true

    if [ -z "$SSODomain" ]; then
        SSODomain=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`SSODomain`].Value' --output text 2>/dev/null)
    fi
}

print_configuration() {
    echo "Installation configuration:"
    echo "  Mandatory dev tools: Homebrew + uv + direnv"
    echo "  SSO tools: $install_sso"
    echo "  zsh: $install_zsh"
    echo "  pip: $install_pip"
    echo "  Docker: $install_docker"
    echo "  Anaconda: $install_anaconda"
    echo "  nvm: $install_nvm"
    echo "  privpage: $install_privpage"
    echo "  for-tools: $install_fortools"
    echo "  SSO Domain: ${SSODomain:-not set}"
    echo "  Auto-shutdown: $enable_shutdown (timeout: ${SHUTDOWN_TIMEOUT} minutes)"
}

configure_autoshutdown() {
    if ! $enable_shutdown; then
        echo "Automatic shutdown disabled"
        return
    fi

    echo "Configuring automatic shutdown..."
    echo "SHUTDOWN_TIMEOUT=${SHUTDOWN_TIMEOUT}" > "$CLOUDX_HOME/autoshutdown-configuration"

    cat > "$CLOUDX_HOME/stop-if-inactive.sh" << 'EOF'
#!/bin/bash
#
# Based on AWS default cloud9 script, this is an improved version for use with C9 and VSCODE
#
# How it works:
#
# systemd - by means of /etc/system.d/system/cloudX-automatic-shutdown - runs this script every minute
# the script schedules a shutdown in 'SHUTDOWN_TIMEOUT' minutes when instance is idle
# if whithin the shutdown timeout period activity is detected (e.g. reconnect), the shutdown is canceled

# idle detection is
# - no vfs connected
# - no vscode-server running

# shutdown creates a file /run/systemd/shutdown/scheduled.
# shutdown -c doesn't remove the file, the cancel_shutdown function does.
# the existence of the file is checked by is_shutting_down as a reliable indicator
# of a shutdown being scheduled. if not - just to be sure - pgrep is used to check
# if a shutdown process is running

# active ssh/ssm sessions are not taken into account for idle detection !!

# -- functions --

exec 3> /home/ec2-user/.cloudX/autoshutdown-log

is_ec2user_connected()
{
    printf "\n$(date): output is_ec2user_connected():\n" >&3

    # check if server has established connection

    established=$(/usr/bin/lsof -i -a -u ec2-user | grep 'ESTABLISHED' )
    if [[ -z "$established" ]]; then
        echo "no established connection found" >&3
        return 1
    fi
    printf "established connections:\n $established" >&3

    return 0
}

is_active()
{
    is_ec2user_connected
}

is_shutting_down() {
    local FILE
    FILE=/run/systemd/shutdown/scheduled
    if [[ -f "$FILE" ]]; then
        return 0
    else
        pgrep -f /sbin/shutdown >/dev/null
    fi
}

cancel_shutdown()
{
    sudo shutdown -c
    sudo rm -f /run/systemd/shutdown/scheduled
}

# -- main --

set -euo pipefail
CONFIG=$(cat /home/ec2-user/.cloudX/autoshutdown-configuration)
SHUTDOWN_TIMEOUT=${CONFIG#*=}
if ! [[ $SHUTDOWN_TIMEOUT =~ ^[0-9]*$ ]]; then
    printf "\n*** shutdown timeout is invalid in /home/ec2-user/.cloudX/autoshutdown-configuration\n*** AUTOSHUTDOWN deactivated" >&3
    exit 1
fi

touch "/home/ec2-user/.cloudX/autoshutdown-timestamp"

echo "$(date): starting evaluation" >&3

if is_active; then
    printf "\n$(date): activity detected, " >&3
    if is_shutting_down; then
        cancel_shutdown
        echo "canceled shutdown " >&3
    else
        echo "not shutting down" >&3
    fi
else
    printf "\n$(date): NO activity detected, " >&3
    if ! is_shutting_down ; then
        sudo shutdown -h $SHUTDOWN_TIMEOUT 
        echo "initiated shutdown with waiting time of ${SHUTDOWN_TIMEOUT} minutes" >&3
    else
        echo "shutdown still scheduled ${SHUTDOWN_TIMEOUT} minutes after $(stat -c '%z' /run/systemd/shutdown/scheduled | cut -f2 -d' ' | cut -f-2 -d: )" >&3
    fi
fi

EOF
    chmod 755 "$CLOUDX_HOME/stop-if-inactive.sh"

    cat > /etc/systemd/system/cloudX-automatic-shutdown.service << EOF
[Unit]
Description=Stop system when idle
Wants=cloudX-automatic-shutdown.timer

[Service]
ExecStart=$CLOUDX_HOME/stop-if-inactive.sh
Type=oneshot

[Install]
WantedBy=multi-user.target

EOF

    cat > /etc/systemd/system/cloudX-automatic-shutdown.timer << EOF
[Unit]
Description=Stop system when idle
Requires=cloudX-automatic-shutdown.service

[Timer]
Unit=cloudX-automatic-shutdown.service
OnCalendar=*-*-* *:*:00

[Install]
WantedBy=timers.target
EOF

    sed -i '/pam_nologin.so/s/^/# /' /etc/pam.d/sshd 
}

chown_workspace() {
    chown -R ec2-user:ec2-user "$CLOUDX_HOME" "$EC2_USER_HOME/environment"
}

install_system_dependencies() {
    echo "Installing mandatory system packages..."

    if ! command -v git &> /dev/null || ! command -v jq &> /dev/null; then
        yum update -y
        yum install -y git jq util-linux-user ruby gem ruby-devel
        sleep 5

        if ! yum grouplist installed | grep -q "Development Tools"; then
            yum groupinstall -y 'Development Tools'
            sleep 5
            yum groupinstall -y 'Development Tools'
        fi
    else
        echo "Core system packages already installed"
    fi
}

write_user_env() {
    cat > "$ENV_FILE" << EOF
install_sso=$install_sso
install_zsh=$install_zsh
install_pip=$install_pip
install_anaconda=$install_anaconda
install_nvm=$install_nvm
install_privpage=$install_privpage
install_fortools=$install_fortools
SSODomain=$SSODomain
EOF
}

run_user_bootstrap() {
    sudo -u ec2-user -i <<'EOF'
set -euo pipefail

EC2_USER_HOME="/home/ec2-user"

source "$EC2_USER_HOME/.env"
rm -f "$EC2_USER_HOME/.env"

configure_git() {
    git config --global credential.helper '!aws codecommit credential-helper $@'
    git config --global credential.UseHttpPath true
}

ensure_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew already installed"
    fi

    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    brew tap easytocloud/tap >/dev/null 2>&1 || true
}

ensure_direnv() {
    if ! command -v direnv &> /dev/null; then
        echo "Installing direnv (mandatory)..."
        brew install direnv
    else
        echo "direnv already installed"
    fi
}

ensure_uv() {
    if ! command -v uv &> /dev/null; then
        echo "Installing uv (mandatory)..."
        brew install uv
    else
        echo "uv already installed"
    fi
}

install_zsh_stack() {
    if ! $install_zsh; then
        return
    fi

    if ! command -v zsh &> /dev/null || [ ! -d ~/.oh-my-zsh ]; then
        echo "Installing zsh and oh-my-zsh..."
        brew install zsh
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        wget https://raw.githubusercontent.com/easytocloud/oh-my-easytocloud/main/themes/easytocloud.zsh-theme -O ~/.oh-my-zsh/custom/themes/easytocloud.zsh-theme
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="easytocloud"/' /home/ec2-user/.zshrc
        echo '/home/linuxbrew/.linuxbrew/bin/zsh' | sudo tee -a /etc/shells >/dev/null
    else
        echo "zsh already installed"
    fi
}

install_sso_tools() {
    if ! $install_sso; then
        return
    fi

    if ! command -v generate-sso-config &> /dev/null; then
        echo "Installing SSO tools..."
        brew install easytocloud/tap/sso-tools
        mkdir -p /home/ec2-user/.aws

        echo "[sso-session sso]" > /home/ec2-user/.aws/config
        echo "sso_start_url = https://${SSODomain}/start#/" >> /home/ec2-user/.aws/config
        echo "sso_region = eu-west-1" >> /home/ec2-user/.aws/config
        echo "sso_registration_scopes = sso:account:access" >> /home/ec2-user/.aws/config
        echo "" >> /home/ec2-user/.aws/config
        echo "[profile sso-browser]" >> /home/ec2-user/.aws/config
        echo "sso_session = sso" >> /home/ec2-user/.aws/config
        echo "region = eu-west-1" >> /home/ec2-user/.aws/config
        echo "output = json" >> /home/ec2-user/.aws/config
        cat ~/.aws/config
        touch /home/ec2-user/.aws/config.needed
    else
        echo "SSO tools already installed"
    fi
}

install_fortools() {
    if ! $install_fortools; then
        return
    fi

    if ! command -v for-account &> /dev/null; then
        echo "Installing for-tools..."
        brew install easytocloud/tap/for-tools
    else
        echo "for-tools already installed"
    fi
}

install_pip_stack() {
    if ! $install_pip; then
        return
    fi

    if ! command -v pip &> /dev/null; then
        echo "Installing pip..."
        curl -O https://bootstrap.pypa.io/get-pip.py
        python3 get-pip.py --user
        rm get-pip.py
        pip install pyfiglet
    else
        echo "pip already installed"
    fi
}

install_anaconda_stack() {
    if ! $install_anaconda; then
        return
    fi

    if [ ! -d /home/ec2-user/anaconda3 ]; then
        echo "Installing Anaconda..."
        curl -O https://repo.anaconda.com/archive/Anaconda3-2023.03-Linux-x86_64.sh
        bash Anaconda3-2023.03-Linux-x86_64.sh -b -p /home/ec2-user/anaconda3
        rm Anaconda3-2023.03-Linux-x86_64.sh
    else
        echo "Anaconda already installed"
    fi
}

install_nvm_stack() {
    if ! $install_nvm; then
        return
    fi

    if [ ! -d ~/.nvm ]; then
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
    else
        echo "nvm already installed"
    fi
}

install_privpage_stack() {
    if ! $install_privpage; then
        return
    fi

    if ! command -v privpage &> /dev/null; then
        echo "Installing privpage..."
        brew install easytocloud/tap/privpage
    else
        echo "privpage already installed"
    fi
}

append_unique_line() {
    local file="$1"
    local line="$2"
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

update_bashrc() {
    local bashrc="/home/ec2-user/.bashrc"
    touch "$bashrc"
    append_unique_line "$bashrc" 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    append_unique_line "$bashrc" 'eval "$(direnv hook bash)"'

    if $install_sso; then
        append_unique_line "$bashrc" 'test -f /home/ec2-user/.aws/config.needed && printf "\n\n** Please run uvx sso-config-generator to configure AWS CLI **\n\n"'
    fi

    if $install_anaconda; then
        append_unique_line "$bashrc" 'export PATH=/home/ec2-user/anaconda3/bin:$PATH'
    fi

    if $install_privpage; then
        append_unique_line "$bashrc" 'export AWS_PAGER=privpage'
    fi

    append_unique_line "$bashrc" "complete -C '/usr/bin/aws_completer' aws"
}

update_zshrc() {
    local zshrc="/home/ec2-user/.zshrc"
    if [ ! -f "$zshrc" ]; then
        return
    fi

    append_unique_line "$zshrc" 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    append_unique_line "$zshrc" 'eval "$(direnv hook zsh)"'

    if $install_sso; then
        append_unique_line "$zshrc" 'test -f /home/ec2-user/.aws/config.needed && printf "\n\n** Please run uvx sso-config-generator to configure AWS CLI **\n\n"'
    fi

    if $install_anaconda; then
        append_unique_line "$zshrc" 'export PATH=/home/ec2-user/anaconda3/bin:$PATH'
    fi

    if $install_privpage; then
        append_unique_line "$zshrc" 'export AWS_PAGER=privpage'
    fi

    if ! grep -q "bashcompinit" "$zshrc" 2>/dev/null; then
        {
            echo 'autoload bashcompinit && bashcompinit'
            echo 'autoload -Uz compinit && compinit'
            echo "complete -C '/usr/bin/aws_completer' aws"
        } >> "$zshrc"
    fi
}

main_user_setup() {
    configure_git
    ensure_homebrew
    ensure_direnv
    ensure_uv
    install_zsh_stack
    install_sso_tools
    install_fortools
    install_pip_stack
    install_anaconda_stack
    install_nvm_stack
    install_privpage_stack
    update_bashrc
    update_zshrc
}

main_user_setup
EOF
}

set_default_shell_if_needed() {
    if $install_zsh && [ -f /home/linuxbrew/.linuxbrew/bin/zsh ]; then
        current_shell=$(getent passwd ec2-user | cut -d: -f7)
        if [ "$current_shell" != "/home/linuxbrew/.linuxbrew/bin/zsh" ]; then
            chsh -s /home/linuxbrew/.linuxbrew/bin/zsh ec2-user
        fi
    fi
}

configure_docker_if_requested() {
    if ! $install_docker; then
        return
    fi

    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        yum install -y docker
        usermod -a -G docker ec2-user
        systemctl enable docker
        systemctl start docker
    else
        echo "Docker already installed"
        systemctl enable docker
        systemctl start docker
    fi
}

create_banner_script_if_needed() {
    if ! $install_pip; then
        return
    fi

    cat > /usr/local/bin/banner << 'EOF'
#!/bin/bash
# wrapper to use banner via pyfiglet (AL2023)
# pyfiglet will be installed if not yet available

if [[ "$@" == "" ]]
then
    echo "Usage: banner string" >&2
    exit 2
fi
(command -v pyfiglet > /dev/null || pip install -q pyfiglet) && pyfiglet "$@" 

EOF
    chmod 755 /usr/local/bin/banner
}

enable_idle_monitor_if_needed() {
    if $enable_shutdown; then
        systemctl enable cloudX-automatic-shutdown
        systemctl start cloudX-automatic-shutdown
        echo "Automatic shutdown service enabled and started"
    fi
}

finalize_installation() {
    touch "$EC2_USER_HOME/.install-done"
    rm -f "$EC2_USER_HOME/.install-running"

    echo ""
    echo "=========================================="
    echo "cloudX installation completed successfully!"
    echo "=========================================="
    echo ""
    echo "Installed components:"
    echo "  ✓ Homebrew (mandatory)"
    echo "  ✓ uv (mandatory)"
    echo "  ✓ direnv (mandatory)"
    $install_sso && echo "  ✓ SSO tools"
    $install_zsh && echo "  ✓ zsh + oh-my-zsh"
    $install_pip && echo "  ✓ pip"
    $install_docker && echo "  ✓ Docker"
    $install_anaconda && echo "  ✓ Anaconda"
    $install_nvm && echo "  ✓ nvm"
    $install_privpage && echo "  ✓ privpage"
    $install_fortools && echo "  ✓ for-tools"
    echo ""
    if $enable_shutdown; then
        echo "Auto-shutdown is enabled (${SHUTDOWN_TIMEOUT} minute timeout)"
    else
        echo "Auto-shutdown is disabled"
    fi
    echo ""
    echo "Please log out and log back in for all changes to take effect."
    echo ""
}

main() {
    parse_cli "$@"
    require_amazon_linux
    detect_ec2_instance
    prepare_workspace
    apply_tag_preferences
    print_configuration
    configure_autoshutdown
    chown_workspace
    install_system_dependencies
    write_user_env
    run_user_bootstrap
    set_default_shell_if_needed
    configure_docker_if_requested
    create_banner_script_if_needed
    enable_idle_monitor_if_needed
    finalize_installation
}

main "$@"
