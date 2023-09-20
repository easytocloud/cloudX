#!/bin/bash
# Install cloudX on Amazon Linux 2
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

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

yum groupinstall 'Development Tools'

brew install gcc
brew tap easytocloud/tap

# create cloud9-like directories

mkdir ~ec2-user/.cloudX && mkdir ~ec2-user/environment

cd ~ec2-user/.cloudX

echo 'SHUTDOWN_TIMEOUT=8' > autoshutdown-configuration
