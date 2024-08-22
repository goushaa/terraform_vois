#!/bin/bash

# Define the AWS account ID as a variable
id="851725310572"
region="us-east-1"

# Get the caller identity
aws sts get-caller-identity

# Login to AWS ECR
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $id.dkr.ecr.$region.amazonaws.com

# Pull Docker images
docker pull jenkins/jenkins:lts-jdk17
docker pull goushaa/kady-nodejs:latest
docker pull mysql:8.0

# Tag Docker images
docker tag jenkins/jenkins:lts-jdk17 $id.dkr.ecr.$region.amazonaws.com/kady-jenkins:latest
docker tag goushaa/kady-nodejs:latest $id.dkr.ecr.$region.amazonaws.com/kady-nodejs:latest
docker tag mysql:8.0 $id.dkr.ecr.$region.amazonaws.com/kady-mysql:latest

# Push Docker images
docker push $id.dkr.ecr.$region.amazonaws.com/kady-jenkins:latest
docker push $id.dkr.ecr.$region.amazonaws.com/kady-nodejs:latest
docker push $id.dkr.ecr.$region.amazonaws.com/kady-mysql:latest