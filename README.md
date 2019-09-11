# Introduction 
This repository contains code i used during my session at NGINX Conf 2019 about "Automating Deployment of NGINX as an API Gateway for External APIs Using Azure DevOps"

# Getting Started
Logic behing is :
1.	Create Azure Resource groups,
2.	Create DNS resources in a dedicated dns-rg resource group,
3.	Create Base resources which are KeyVault and Log Analytics Workspace
4.  Here you should add secret by your own and update Deploy-Nginx.ps1 accordingly
4.	Deploy NGINX resources in your subscription

# Requirements
1. Have an Azure DevOps free account or more
2. Have a trial Azure Subscription
3. Setup an Azure DevOps project with a repository, build and release
4. Have an Nginx Plus license or remove the steps in the ans-proxy.yml

# Contribute
Do not hesitate to contribute, ask questions if any ...
We can update templates with a better NGINX architecture etc ...

# Session purpose
https://www.nginx.com/nginxconf/2019/session/automating-deployment-of-nginx-api-gateway-azure-devops/

