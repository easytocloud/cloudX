# cloudX
Setup an Amazon Linux 2023 EC2 instance as backend for VSCode.

## Introduction

A standard way of working at easytocloud is to use Cloud9 for development.
Cloud9 does have its limitations, especially in the IDE and in supporting more modern (versions of) packages and languages.
Using VSCode as a frontend to a Cloud9 backend solves a lot of issues we had with the Cloud9 IDE.
Updating Cloud9 so it uses AWS cli version 2 and python3 is one approach we have used to solve the out-dated software issues.

Cloud9 is based on Amazon Linux 2 or Ubuntu Linux.
We do however prefer to use Amazon Linux 2023 and as we don't use the Cloud9 Web IDE anymore.

cloudX combines the use of VSCode frontend with Amamzon Linux 2023 backend, using the (OS) features we love from Cloud9 without the actual Cloud9 IDE.

## Components

cloudX consists of cloudformation templates that are to be deployed in your AWS account; one for the 'infrastructure' and one for each 'backend instance'

### CloudX infrastructure

This template creates the IAM resources used with cloudX. It stores settings in the parameter store to 'document' the infrastructure.

### CloudX instance

This template (that can be added to Service Catalog for self-service purposes) installs an EC2 instance with all relevant software to function as a VSCode backend.
You can connect to this instance using SSM. The role the instance needs for that is defined in CloudX infrastructure and automatically attached to the instance.

### Optional CloudX user

To connect to the instance, the user is required to have certain permissions. These permissions see to starting, stopping and connecting to the instance using SSM.
You can either rely on these permissions from your current authentication and authorization (IAM, SSO) or you can create a new dedicated IAM user for each cloudX user.
When this 'dedicated user' is member of the group that is created with CloudX infrastructure, the user will have exactely the required permissions.

For the permissions to work, make sure you deploy the CloudX instance with the IAM username in the 'security tag' of the instance.
The name of the 'security tag' is defined as part of the CloudX infrastructure.

### EC2 UserData

The instance deployed as CloudX instance will run the install.sh in this repository to install all relevant software in the instance.

### Local ssh config file

On your local machine, you need to setup ssh to connect to the instance, before you can use VSCode Remote development.

At AWS level, you have to be able to connect and start/stop the instance. 
For that, you need a configured AWS cli on your local device
with a profile that can be used to operate on the instance.

Once the instance is running, you'll be using ssh to connect.
For that you need an ssh key-pair. 
The public key will be pushed to the instance, the private keys stays on your local device.

It all comes together in your ssh config file. 
This documentation (and the software's defaults) assume you have a dedicated ssh config file for vscode connections in the directory ~/.ssh/vscode/
This file can be included from your ~/.ssh/config as follows:

```
Include vscode/config
```

and then in vscode/config

```
Host vscode-one
    ProxyCommand cloudX-proxy.sh %h %p
    User ec2-user
    IdentityFile ~/.ssh/vscode/vscode.pub
    HostName i-<something>
```

Whenever an ssh connection is made to the host vscode-one, first the ProxyCommand will be run to connect to the host
then a login attempt is made as ec2-user using the key-pair indicated by IdentityFile.

The heavy-lifting is done by cloudX-proxy.sh, installed as part of this product:

```
$ brew tap easytocloud/tap
$ brew install easytocloud/tap/cloudx
```

cloudX-proxy.sh \<hostname\> \<portnumber\> \<environment\:standard\> <profile\:vscode> <pubkey\:~/.ssh/vscode/vscode.pub> <region\:profile-region>

hostname and portnumber are mandatory parameters.

All parameters are positional, that is the 4th parameter has to be a profile name.
When ommitted, the values are as indicated after the ':'.

The proxy uses the indicated AWS profile to connect to the instance, start it if necessary, and use SSM to setup an ssh tunnel.
When no other parameters that hostname and portnumber are given, the profile it uses is the profile 'vscode' in your ~/.aws/credentials file.
When your use easytocloud's AWS profile organizer, you can have multiple 'environments' each with their own config and credentials file.
Parameter 3 refers to the AWS profile organizer environment, user 'standard' if the standard files should be used.

Should you want to use different keys per cloudX instance, provide the key as parameter 5.

The region to look for the instance should be part of the profile, but if so desired can be overruled in parameter 6

A more advanced example:

```
Host vscode-one
    ProxyCommand cloudX-proxy.sh %h %p standard labs_profile ~/.ssh/easytocloud/dev.pub
    User ec2-user
    IdentityFile ~/.ssh/easytocloud/dev.pub
    HostName i-<something>

```

or with use of AWS Profile Organizer:

```
Host vscode-one
    ProxyCommand cloudX-proxy.sh %h %p easytocloud labs
    User ec2-user
    IdentityFile ~/.ssh/vscode/vscode.pub
    HostName i-<something>

```

