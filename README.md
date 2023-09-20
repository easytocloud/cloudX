# cloudX
Tools to convert an Amazon Linux instance to a vscode backend

# Introduction

A standard way of working in easytocloud is to use cloud9 for development.
Cloud9 does have its limitations, especially in the IDE and in supporting more modern (versions of) packages and languages.
Using vscode as a frontend to a cloud9 backend solves a lot of issues we had with the IDE
Updating cloud9 so it uses aws cli version 2 and python3 is one approach we have used to solve the out-dated software.

We do however prefer to use Amazon Linux 2023 and don't use the Cloud9 Web IDE anymore.

cloudX combines the use of VSCode frontend with Amamzon Linux 2023 backend, using the (OS) features we love from Cloud9 without the actual Cloud9 IDE.

# Components

cloudX consists of cloudformation templates that are to be deployed in your AWS account; one for the 'infrastructure' and one for each 'backend instance'

# CloudX infrastructure

This template creates the IAM resources used with cloudX. It uses parameter store to 'document' the infrastructure.

# CloudX instance

This template (that can be added to Service Catalog for self-service purposes) installs an EC2 instance with all relevant software to function as a vscode Backend.
You can connect to this instance using SSM. The role the instance needs for that is defined in CloudX infrastructure.
