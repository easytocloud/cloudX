#!/bin/bash
#
# Install cloudX on Amazon Linux 2023
#
# This script is meant to be run from EC2 user data
#
# This script will 
#
# - create cloud9-like directories
# - configure automatic shutdown
# - install additional software
#

# check os version

if [ ! -f /etc/os-release ]; then
  echo "This script only supports Amazon Linux"
  exit 1
fi

# signal that install is running

touch /home/ec2-user/.install-running

# create cloud9-like directories

mkdir ~ec2-user/environment
mkdir ~ec2-user/.cloudX 



cd ~ec2-user/.cloudX

# Check tags for extra software to install
# get instance metadata from IDMSv2

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
instanceId=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

export install_brew=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`brew`].Value' --output text )
export install_direnv=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`direnv`].Value' --output text )
export install_sso=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`sso`].Value' --output text )
export install_zsh=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`zsh`].Value' --output text )
export install_pip=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`pip`].Value' --output text )
export install_docker=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`docker`].Value' --output text )
export install_anaconda=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`anaconda`].Value' --output text )
export install_nvm=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`nvm`].Value' --output text )
export install_privpage=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`privpage`].Value' --output text )

export SSODomain=$(aws ec2 describe-tags --filter Name=resource-id,Values=$instanceId --query 'Tags[?Key==`SSODomain`].Value' --output text )


# for packages installed with brew, make sure to install brew regardless users choice

${install_direnv}   && install_brew=true
${install_sso}      && install_brew=true
${install_zsh}      && install_brew=true
${install_privpage} && install_brew=true

# ### AUTO SHUTDOWN ###

echo 'SHUTDOWN_TIMEOUT=10' > autoshutdown-configuration

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

chown -R ec2-user:ec2-user ~ec2-user/.cloudX ~ec2-user/environment

# create automatic shutdown service

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

# create automatic shutdown timer

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

# allow ssh login even when shutdown is scheduled
sed -i '/pam_nologin.so/s/^/# /' /etc/pam.d/sshd 

# ## ADDITIONAL SOFTWARE - MANDATORY - SYSTEM LEVEL ##

yum update -y
yum install -y git jq util-linux-user
sleep 5
yum groupinstall -y 'Development Tools'
sleep 5
yum groupinstall -y 'Development Tools' # run twice to avoid error

# ## ADDITOINAL SOFTWARE - OPTIONALLY BASED ON TAGS ##
env | grep install_ > /home/ec2-user/.env
env | grep SSODomain >> /home/ec2-user/.env

sudo -u ec2-user -i <<'EOF'
# configure git for codecommit
source /home/ec2-user/.env
rm -f /home/ec2-user/.env

git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# install homebrew
${install_brew} && NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
${install_brew} && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# install zsh
if ${install_zsh}
then
    brew install zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    # change default theme to easytocloud
    wget https://raw.githubusercontent.com/easytocloud/oh-my-easytocloud/main/themes/easytocloud.zsh-theme -O ~/.oh-my-zsh/custom/themes/easytocloud.zsh-theme
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="easytocloud"/' /home/ec2-user/.zshrc
    echo  '/home/linuxbrew/.linuxbrew/bin/zsh' | sudo tee -a /etc/shells
fi

# install direnv
${install_direnv} && brew install direnv

if ${install_sso}
then
    # install sso-tools
    brew tap easytocloud/tap
    brew install easytocloud/tap/sso-tools
    mkdir -p /home/ec2-user/.aws
    
    echo "===> env"
    env
    echo "===> SSODomain="${SSODomain}
    
    echo "[sso-session sso]" > /home/ec2-user/.aws/config
    echo "sso_start_url = https://"${SSODomain}"/start#/" >> /home/ec2-user/.aws/config
    echo "sso_region = eu-west-1" >> /home/ec2-user/.aws/config
    echo "sso_registration_scopes = sso:account:access" >> /home/ec2-user/.aws/config
    cat ~/.aws/config
    touch /home/ec2-user/.aws/config.needed
fi

# install pip
if ${install_pip}
then
    curl -O https://bootstrap.pypa.io/get-pip.py
    python3 get-pip.py --user
    rm get-pip.py
fi

# install anaconda
if ${install_anaconda}
then
    curl -O https://repo.anaconda.com/archive/Anaconda3-2023.03-Linux-x86_64.sh
    bash Anaconda3-2023.03-Linux-x86_64.sh -b -p /home/ec2-user/anaconda3
    rm Anaconda3-2023.03-Linux-x86_64.sh
fi

# install nvm
if ${install_nvm}
then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
fi

${install_privpage} && brew install easytocloud/tap/privpage

# update .bashrc
${install_brew} && echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" ' >> /home/ec2-user/.bashrc
${install_direnv} && echo 'eval "$(direnv hook bash)" ' >> /home/ec2-user/.bashrc
${install_sso} && echo 'test -f /home/ec2-user/.aws/config.needed || printf "\n\n** Please run generate-sso-config to configure AWS CLI **\n"' >> /home/ec2-user/.bashrc
${install_anaconda} && echo 'export PATH=/home/ec2-user/anaconda3/bin:$PATH' >> /home/ec2-user/.bashrc
${install_privpage} && echo 'export AWS_PAGER=privpage' >> /home/ec2-user/.bashrc

# update .zshrc
if [ -f /home/ec2-user/.zshrc ]; then
  ${install_brew} && echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" ' >> /home/ec2-user/.zshrc
  ${install_direnv} && echo 'eval "$(direnv hook zsh)" ' >> /home/ec2-user/.zshrc
  ${install_sso} && echo 'test -f /home/ec2-user/.aws/config.needed || printf "\n\n** Please run generate-sso-config to configure AWS CLI **\n"' >> /home/ec2-user/.zshrc
  ${install_anaconda} && echo 'export PATH=/home/ec2-user/anaconda3/bin:$PATH' >> /home/ec2-user/.zshrc
  ${install_privpage} && echo 'export AWS_PAGER=privpage' >> /home/ec2-user/.zshrc
fi

EOF

${install_zsh} && chsh -s /home/linuxbrew/.linuxbrew/bin/zsh ec2-user

# install docker
if ${install_docker}
then
    yum install -y docker
    usermod -a -G docker ec2-user
    systemctl enable docker
    systemctl start docker
fi
# start idle monitor - this should really be the last thing you do ....

systemctl enable cloudX-automatic-shutdown
systemctl start cloudX-automatic-shutdown

# ... before Cleanup

# signal that install is done
touch /home/ec2-user/.install-done
rm /home/ec2-user/.install-running

