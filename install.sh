#!/bin/bash
# Install cloudX on Amazon Linux 2023
#
# This script is meant to be run as root
#
# This script will install the following:
# - git
# - Homebrew
# - cloudX
#

# check os version
if [ ! -f /etc/os-release ]; then
  echo "This script only supports Amazon Linux"
  exit 1
fi

yum update -y
yum install -y amazon-linux-extras
amazon-linux-extras install -y epel
yum install -y git

# install homebrew

su ec2-user -c 'NONINTERACTIVE=1 /bin/bash -xc "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /tmp/brewinstall.log 2>&1'
su ec2-user -c "echo 'eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" ' >> /home/ec2-user/.bash_profile"

yum groupinstall 'Development Tools'

su - ec2-user -c "brew tap easytocloud/tap"

# create cloud9-like directories

mkdir ~ec2-user/environment

mkdir ~ec2-user/.cloudX 

cd ~ec2-user/.cloudX

echo 'SHUTDOWN_TIMEOUT=8' > autoshutdown-configuration

cat > stop-if-inactive.sh << 'EOF'
#!/bin/bash

# Based on AWS default cloud9 script, this is an improved version for use with C9 and VSCODE
#
# How it works:
#
# cron - by means of /etc/crond.d/c9-automatic-shutdown - runs this script every minute
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

exec 3> /home/ec2-user/.c9/autoshutdown-log

is_web_active()
{
    printf "\n$(date): output is_web_active():\n" >&3
    pgrep -f vfs-worker >&3
}

is_codeserver_active()
{
    printf "\n$(date): output is_codeserver_active():\n" >&3

    # server is started as sh .... server-main, so we need to filter out the sh process

    server=$(pgrep -f server-main -a | grep -v 'sh ' | awk '{print $1}')
    if [[ -z "$server" ]]; then
        echo "no server found" >&3
        return 1
    fi
    echo "server pid: $server" >&3

    # check if server has established connection

    established=$(/usr/sbin/lsof -i | grep ESTABLISHED | grep $server )
    if [[ -z "$established" ]]; then
        echo "no established connection found" >&3
        return 1
    fi
    echo "established connection: $established" >&3

    return 0
}

is_active()
{
    is_web_active || is_codeserver_active
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
CONFIG=$(cat /home/ec2-user/.c9/autoshutdown-configuration)
SHUTDOWN_TIMEOUT=${CONFIG#*=}
if ! [[ $SHUTDOWN_TIMEOUT =~ ^[0-9]*$ ]]; then
    printf "\n*** shutdown timeout is invalid in /home/ec2-user/.c9/autoshutdown-configuration\n*** AUTOSHUTDOWN deactivated" >&3
    exit 1
fi

touch "/home/ec2-user/.c9/autoshutdown-timestamp"

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

chown -R ec2-user:ec2-user ~ec2-user/.cloudX ~ec2-user/environment

# execute stop-if-inactive.sh every minute

cat > /etc/cron.d/cloudX-automatic-shutdown << EOF
* * * * * root /home/ec2-user/.cloudX/stop-if-inactive.sh
EOF
