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

# History:
#
# 2023-11-12: version 0.3.0 
#             fundamental rewrite of idle detection vscode-server
#             - use lsof to check for established connection
#             more comprehensive logging
#             improved error handling
#             semantic versioning
# 
# earlier history/versions not recorded in this file
#

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

# ## ADDITIONAL SOFTWARE - SYSTEM LEVEL ##

yum update -y
yum install -y git jq
sleep 5
yum groupinstall -y 'Development Tools'
sleep 5
yum groupinstall -y 'Development Tools' # run twice to avoid error

bash -c "$(curl -sfLS https://direnv.net/install.sh)"

# ## ADDITIONAL SOFTWARE - EC2-USER LEVEL ##

sudo -u ec2-user -i <<'EOF'
# install homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# setup git
git config --global credential.helper '!aws codecommit credential-helper \$@'
git config --global credential.UseHttpPath true

# update .bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" ' >> /home/ec2-user/.bashrc
echo 'eval "$(direnv hook bash)" ' >> /home/ec2-user/.bashrc

# install sso-tools
brew tap easytocloud/tap
brew install easytocloud/tap/sso-tools
echo 'test -d /home/ec2-user/.aws || printf "\n\n** Please run generate-config to configure AWS CLI **\n"' >> /home/ec2-user/.bashrc

EOF

# start idle monitor - this should really be the last thing you do ....

systemctl enable cloudX-automatic-shutdown
systemctl start cloudX-automatic-shutdown

# ... before Cleanup

# signal that install is done
touch /home/ec2-user/.install-done
rm /home/ec2-user/.install-running

