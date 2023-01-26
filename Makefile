# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Deploy to s3 bucket
# make deploy CFN_ARTEFACT_S3_BUCKET=<your s3 bucket name>
#
# Deploy to local directory
# make package LOCAL_ARTEFACT_DIR=<my_directory>

#SHELL := /bin/sh
PY_VERSION := 3.8

export PYTHONUNBUFFERED := 1

FUNCTION_DIR := functions

# CloudFormation deployment variables
USER = elxsj
CFN_ARTEFACT_S3_BUCKET ?=
# CFN_ARTEFACT_S3_BUCKET := sagemaker-studio-856830038219-elxsj
LOCAL_ARTEFACT_DIR := cfn
CFN_TEMPLATE_DIR := cfn_templates
BUILD_DIR := build
PROJECT_NAME ?= sagemaker-studio-infra
SM_DOMAIN_NAME ?= sagemaker-$(USER)-domain
SM_USER_PROFILE_NAME ?= $(USER)-user-profile
VPC_CIDR ?= 10.2.0.0/16
FIREWALL_SN_CIDR ?= 10.2.1.0/24
NAT_GW_SN_CIDR ?= 10.2.2.0/24
SAGEMAKER_SN_CIDR ?= 10.2.3.0/24

# Stack name used when deploying or deleting the stack
APP_STACK_NAME ?= sagemaker-studio-infra

PYTHON := $(shell /usr/bin/which python$(PY_VERSION))

.DEFAULT_GOAL := package

delete:
	aws cloudformation delete-stack \
		--stack-name $(APP_STACK_NAME)

build:
	rm -fr ${BUILD_DIR}
	mkdir -p ${BUILD_DIR}

package: build
	aws cloudformation package \
		--template-file $(CFN_TEMPLATE_DIR)/sagemaker-studio-vpc.yaml \
		--s3-bucket $(CFN_ARTEFACT_S3_BUCKET) \
		--s3-prefix $(PROJECT_NAME) \
		--output-template-file $(BUILD_DIR)/packaged.yaml

deploy: package
	aws cloudformation deploy \
		--template-file $(BUILD_DIR)/packaged.yaml \
		--stack-name $(APP_STACK_NAME) \
		--parameter-overrides \
		ProjectName=$(PROJECT_NAME) \
		DomainName=$(SM_DOMAIN_NAME) \
		UserProfileName=$(SM_USER_PROFILE_NAME) \
		VPCCIDR=$(VPC_CIDR) \
		FirewallSubnetCIDR=$(FIREWALL_SN_CIDR) \
		NATGatewaySubnetCIDR=$(NAT_GW_SN_CIDR) \
		SageMakerStudioSubnetCIDR=$(SAGEMAKER_SN_CIDR) \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
