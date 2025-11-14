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
#   --brew              Install Homebrew
#   --direnv            Install direnv (implies --brew)
#   --sso               Install SSO tools (implies --brew)
#   --zsh               Install zsh and oh-my-zsh (implies --brew)
#   --pip               Install pip and python tools
#   --docker            Install Docker
#   --anaconda          Install Anaconda
#   --nvm               Install Node Version Manager
#   --privpage          Install privpage (implies --brew)
#   --fortools          Install for-tools (implies --brew)
#   --sso-domain DOMAIN Set SSO domain (used with --sso)
#   --shutdown TIMEOUT  Set automatic shutdown timeout in minutes (default: 10)
#   --no-shutdown       Disable automatic shutdown
#   --help              Show this help message
#
# This script will:
# - Create cloud9-like directories
# - Configure automatic shutdown (unless --no-shutdown is specified)
# - Install additional software based on CLI options or EC2 instance tags
#

# Parse command line arguments
install_brew=false
install_direnv=false
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

show_help() {
    grep '^#' "$0" | grep -E '(Usage:|Options:|--.*Install|--.*Set|--.*Show|--.*Disable)' | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --brew)
            install_brew=true
            shift
            ;;
        --direnv)
            install_direnv=true
            shift
            ;;
        --sso)
            install_sso=true
            shift
            ;;
        --zsh)
            install_zsh=true
            shift
            ;;
        --pip)
            install_pip=true
            shift
            ;;
        --docker)
            install_docker=true
            shift
            ;;
        --anaconda)
            install_anaconda=true
            shift
            ;;
        --nvm)
            install_nvm=true
            shift
            ;;
        --privpage)
            install_privpage=true
            shift
            ;;
        --fortools)
            install_fortools=true
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

# Check OS version
if [ ! -f /etc/os-release ]; then
    echo "This script only supports Amazon Linux"
    exit 1
fi

# Detect if running on EC2
is_ec2=false
if curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
    is_ec2=true
    echo "Running on EC2 instance"
else
    echo "Not running on EC2 or IMDS not accessible"
fi

# Signal that install is running
touch /home/ec2-user/.install-running

# Create cloud9-like directories if they don't exist
mkdir -p ~ec2-user/environment
mkdir -p ~ec2-user/.cloudX

cd ~ec2-user/.cloudX

# If running on EC2, check tags for extra software to install (unless CLI options were provided)
if $is_ec2; then
    # Get instance metadata from IDMSv2
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    instanceId=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)

    # Only read from tags if no CLI options were provided
    cli_options_provided=false
    if $install_brew || $install_direnv || $install_sso || $install_zsh || $install_pip || $install_docker || $install_anaconda || $install_nvm || $install_privpage || $install_fortools; then
        cli_options_provided=true
        echo "Using CLI options for software installation"
    fi

    if ! $cli_options_provided; then
        echo "Reading software preferences from EC2 instance tags"
        tag_brew=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`brew`].Value' --output text 2>/dev/null)
        tag_direnv=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`direnv`].Value' --output text 2>/dev/null)
        tag_sso=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`sso`].Value' --output text 2>/dev/null)
        tag_zsh=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`zsh`].Value' --output text 2>/dev/null)
        tag_pip=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`pip`].Value' --output text 2>/dev/null)
        tag_docker=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`docker`].Value' --output text 2>/dev/null)
        tag_anaconda=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`anaconda`].Value' --output text 2>/dev/null)
        tag_nvm=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`nvm`].Value' --output text 2>/dev/null)
        tag_privpage=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`privpage`].Value' --output text 2>/dev/null)
        tag_fortools=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`fortools`].Value' --output text 2>/dev/null)
        
        [[ "$tag_brew" == "true" ]] && install_brew=true
        [[ "$tag_direnv" == "true" ]] && install_direnv=true
        [[ "$tag_sso" == "true" ]] && install_sso=true
        [[ "$tag_zsh" == "true" ]] && install_zsh=true
        [[ "$tag_pip" == "true" ]] && install_pip=true
        [[ "$tag_docker" == "true" ]] && install_docker=true
        [[ "$tag_anaconda" == "true" ]] && install_anaconda=true
        [[ "$tag_nvm" == "true" ]] && install_nvm=true
        [[ "$tag_privpage" == "true" ]] && install_privpage=true
        [[ "$tag_fortools" == "true" ]] && install_fortools=true

        # Get SSO domain from tags if not provided via CLI
        if [ -z "$SSODomain" ]; then
            SSODomain=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`SSODomain`].Value' --output text 2>/dev/null)
        fi
    fi
fi

# For packages installed with brew, make sure to install brew regardless of user's choice
$install_direnv && install_brew=true
$install_sso && install_brew=true
$install_zsh && install_brew=true
$install_privpage && install_brew=true
$install_fortools && install_brew=true

echo "Installation configuration:"
echo "  Homebrew: $install_brew"
echo "  direnv: $install_direnv"
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

# ### AUTO SHUTDOWN ###

if $enable_shutdown; then
    echo "Configuring automatic shutdown..."
    
    echo "SHUTDOWN_TIMEOUT=${SHUTDOWN_TIMEOUT}" > autoshutdown-configuration

    cat > stop-if-inactive.sh << 'EOF'
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
    chmod 755 stop-if-inactive.sh

    # Create automatic shutdown service
    cat > /etc/systemd/system/cloudX-automatic-shutdown.service << EOF
[Unit]
Description=Stop system when idle
Wants=cloudX-automatic-shutdown.timer

[Service]
ExecStart=/home/ec2-user/.cloudX/stop-if-inactive.sh
Type=oneshot

[Install]
WantedBy=multi-user.target

EOF

    # Create automatic shutdown timer
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

    # Allow ssh login even when shutdown is scheduled
    sed -i '/pam_nologin.so/s/^/# /' /etc/pam.d/sshd 
else
    echo "Automatic shutdown disabled"
fi

chown -R ec2-user:ec2-user ~ec2-user/.cloudX ~ec2-user/environment

# ## ADDITIONAL SOFTWARE - MANDATORY - SYSTEM LEVEL ##

echo "Installing mandatory system packages..."

# Check if packages are already installed to avoid unnecessary updates
if ! command -v git &> /dev/null || ! command -v jq &> /dev/null; then
    yum update -y
    yum install -y git jq util-linux-user ruby gem ruby-devel
    sleep 5
    
    # Check if Development Tools are already installed
    if ! yum grouplist installed | grep -q "Development Tools"; then
        yum groupinstall -y 'Development Tools'
        sleep 5
        yum groupinstall -y 'Development Tools' # run twice to avoid error
    fi
else
    echo "Core system packages already installed"
fi

# ## ADDITIONAL SOFTWARE - OPTIONALLY BASED ON TAGS OR CLI OPTIONS ##

# Create env file for use with sudo -u ec2-user -i
cat > /home/ec2-user/.env << EOF
install_brew=$install_brew
install_direnv=$install_direnv
install_sso=$install_sso
install_zsh=$install_zsh
install_pip=$install_pip
install_docker=$install_docker
install_anaconda=$install_anaconda
install_nvm=$install_nvm
install_privpage=$install_privpage
install_fortools=$install_fortools
SSODomain=$SSODomain
EOF

sudo -u ec2-user -i <<'EOF'
# Load env file
source /home/ec2-user/.env
rm -f /home/ec2-user/.env

# Configure git for codecommit
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Install homebrew
if $install_brew; then
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        brew tap easytocloud/tap
    else
        echo "Homebrew already installed"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# Install zsh
if $install_zsh; then
    if ! command -v zsh &> /dev/null || [ ! -d ~/.oh-my-zsh ]; then
        echo "Installing zsh and oh-my-zsh..."
        brew install zsh
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        # Change default theme to easytocloud
        wget https://raw.githubusercontent.com/easytocloud/oh-my-easytocloud/main/themes/easytocloud.zsh-theme -O ~/.oh-my-zsh/custom/themes/easytocloud.zsh-theme
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="easytocloud"/' /home/ec2-user/.zshrc
        echo '/home/linuxbrew/.linuxbrew/bin/zsh' | sudo tee -a /etc/shells
    else
        echo "zsh already installed"
    fi
fi

# Install direnv
if $install_direnv; then
    if ! command -v direnv &> /dev/null; then
        echo "Installing direnv..."
        brew install direnv
    else
        echo "direnv already installed"
    fi
fi

# Install sso-tools
if $install_sso; then
    if ! command -v generate-sso-config &> /dev/null; then
        echo "Installing SSO tools..."
        brew install easytocloud/tap/sso-tools
        mkdir -p /home/ec2-user/.aws

        echo "[sso-session sso]" > /home/ec2-user/.aws/config
        echo "sso_start_url = https://${SSODomain}/start#/" >> /home/ec2-user/.aws/config
        echo "sso_region = eu-west-1" >> /home/ec2-user/.aws/config
        echo "sso_registration_scopes = sso:account:access" >> /home/ec2-user/.aws/config
        cat ~/.aws/config
        touch /home/ec2-user/.aws/config.needed
    else
        echo "SSO tools already installed"
    fi
fi

# Install fortools
if $install_fortools; then
    if ! command -v for-account &> /dev/null; then
        echo "Installing for-tools..."
        brew install easytocloud/tap/for-tools
    else
        echo "for-tools already installed"
    fi
fi

# Install pip
if $install_pip; then
    if ! command -v pip &> /dev/null; then
        echo "Installing pip..."
        curl -O https://bootstrap.pypa.io/get-pip.py
        python3 get-pip.py --user
        rm get-pip.py
        pip install pyfiglet
    else
        echo "pip already installed"
    fi
fi

# Install anaconda
if $install_anaconda; then
    if [ ! -d /home/ec2-user/anaconda3 ]; then
        echo "Installing Anaconda..."
        curl -O https://repo.anaconda.com/archive/Anaconda3-2023.03-Linux-x86_64.sh
        bash Anaconda3-2023.03-Linux-x86_64.sh -b -p /home/ec2-user/anaconda3
        rm Anaconda3-2023.03-Linux-x86_64.sh
    else
        echo "Anaconda already installed"
    fi
fi

# Install nvm
if $install_nvm; then
    if [ ! -d ~/.nvm ]; then
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
    else
        echo "nvm already installed"
    fi
fi

# Install privpage
if $install_privpage; then
    if ! command -v privpage &> /dev/null; then
        echo "Installing privpage..."
        brew install easytocloud/tap/privpage
    else
        echo "privpage already installed"
    fi
fi

# Update .bashrc (only add lines if they don't exist)
if $install_brew && ! grep -q "brew shellenv" /home/ec2-user/.bashrc; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" ' >> /home/ec2-user/.bashrc
fi

if $install_direnv && ! grep -q "direnv hook bash" /home/ec2-user/.bashrc; then
    echo 'eval "$(direnv hook bash)" ' >> /home/ec2-user/.bashrc
fi

if $install_sso && ! grep -q "generate-sso-config" /home/ec2-user/.bashrc; then
    echo 'test -f /home/ec2-user/.aws/config.needed && printf "\n\n** Please run generate-sso-config to configure AWS CLI **\n\n"' >> /home/ec2-user/.bashrc
fi

if $install_anaconda && ! grep -q "anaconda3/bin" /home/ec2-user/.bashrc; then
    echo 'export PATH=/home/ec2-user/anaconda3/bin:$PATH' >> /home/ec2-user/.bashrc
fi

if $install_privpage && ! grep -q "AWS_PAGER=privpage" /home/ec2-user/.bashrc; then
    echo 'export AWS_PAGER=privpage' >> /home/ec2-user/.bashrc
fi

if ! grep -q "aws_completer" /home/ec2-user/.bashrc; then
    echo "complete -C '/usr/bin/aws_completer' aws" >> /home/ec2-user/.bashrc
fi

# Update .zshrc (only add lines if they don't exist)
if [ -f /home/ec2-user/.zshrc ]; then
    if $install_brew && ! grep -q "brew shellenv" /home/ec2-user/.zshrc; then
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" ' >> /home/ec2-user/.zshrc
    fi
    
    if $install_direnv && ! grep -q "direnv hook zsh" /home/ec2-user/.zshrc; then
        echo 'eval "$(direnv hook zsh)" ' >> /home/ec2-user/.zshrc
    fi
    
    if $install_sso && ! grep -q "generate-sso-config" /home/ec2-user/.zshrc; then
        echo 'test -f /home/ec2-user/.aws/config.needed && printf "\n\n** Please run generate-sso-config to configure AWS CLI **\n\n"' >> /home/ec2-user/.zshrc
    fi
    
    if $install_anaconda && ! grep -q "anaconda3/bin" /home/ec2-user/.zshrc; then
        echo 'export PATH=/home/ec2-user/anaconda3/bin:$PATH' >> /home/ec2-user/.zshrc
    fi
    
    if $install_privpage && ! grep -q "AWS_PAGER=privpage" /home/ec2-user/.zshrc; then
        echo 'export AWS_PAGER=privpage' >> /home/ec2-user/.zshrc
    fi
    
    if ! grep -q "bashcompinit" /home/ec2-user/.zshrc; then
        echo 'autoload bashcompinit && bashcompinit' >> /home/ec2-user/.zshrc
        echo 'autoload -Uz compinit && compinit' >> /home/ec2-user/.zshrc
        echo "complete -C '/usr/bin/aws_completer' aws" >> /home/ec2-user/.zshrc
    fi
fi

EOF

# Change default shell to zsh if installed
if $install_zsh && [ -f /home/linuxbrew/.linuxbrew/bin/zsh ]; then
    current_shell=$(getent passwd ec2-user | cut -d: -f7)
    if [ "$current_shell" != "/home/linuxbrew/.linuxbrew/bin/zsh" ]; then
        chsh -s /home/linuxbrew/.linuxbrew/bin/zsh ec2-user
    fi
fi

# Install docker
if $install_docker; then
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        yum install -y docker
        usermod -a -G docker ec2-user
        systemctl enable docker
        systemctl start docker
    else
        echo "Docker already installed"
        # Ensure docker service is enabled and running
        systemctl enable docker
        systemctl start docker
    fi
fi

# Create banner script
if $install_pip; then
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
fi

# Start idle monitor - this should really be the last thing you do ....
if $enable_shutdown; then
    systemctl enable cloudX-automatic-shutdown
    systemctl start cloudX-automatic-shutdown
    echo "Automatic shutdown service enabled and started"
fi

# Signal that install is done
touch /home/ec2-user/.install-done
rm /home/ec2-user/.install-running

echo ""
echo "=========================================="
echo "cloudX installation completed successfully!"
echo "=========================================="
echo ""
echo "Installed components:"
$install_brew && echo "  ✓ Homebrew"
$install_direnv && echo "  ✓ direnv"
$install_sso && echo "  ✓ SSO tools"
$install_zsh && echo "  ✓ zsh + oh-my-zsh"
$install_pip && echo "  ✓ pip"
$install_docker && echo "  ✓ Docker"
$install_anaconda && echo "  ✓ Anaconda"
$install_nvm && echo "  ✓ nvm"
$install_privpage && echo "  ✓ privpage"
$install_fortools && echo "  ✓ for-tools"
echo ""
$enable_shutdown && echo "Auto-shutdown is enabled (${SHUTDOWN_TIMEOUT} minute timeout)"
!$enable_shutdown && echo "Auto-shutdown is disabled"
echo ""
echo "Please log out and log back in for all changes to take effect."
echo ""
