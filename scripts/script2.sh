#!/bin/bash
#Constants

REGION=us-west-2
REPOSITORY_NAME=simpleapp
CLUSTER=getting-started
FAMILY=`sed -n 's/.*"family": "\(.*\)",/\1/p' taskdef.json`
NAME=`sed -n 's/.*"name": "\(.*\)",/\1/p' taskdef.json`
SERVICE_NAME=${NAME}-service
APB_ARN='arn:aws:elasticloadbalancing:us-west-2:610632919226:loadbalancer/app/simpleALB/4e8b74f7f74c5c0e'

#Store the repositoryUri as a variable
REPOSITORY_URI=`aws ecr describe-repositories\
                --repository-names ${REPOSITORY_NAME}\
                --region ${REGION} | jq .repositories[].repositoryUri | tr -d '"'`

#Replace the build number and respository URI placeholders with the constants above
sed -e "s;%BUILD_NUMBER%;${BUILD_NUMBER};g" -e "s;%REPOSITORY_URI%;${REPOSITORY_URI};g" taskdef.json > ${NAME}-v_${BUILD_NUMBER}.json
#Register the task definition in the repository
aws ecs register-task-definition\
  --family ${FAMILY}\
  --cli-input-json file://${WORKSPACE}/${NAME}-v_${BUILD_NUMBER}.json --region ${REGION}
SERVICES=`aws ecs describe-services\
          --services ${SERVICE_NAME}\
          --cluster ${CLUSTER} --region ${REGION} | jq .failures[]`
#Get latest revision
REVISION=`aws ecs describe-task-definition --task-definition simpleapp --region us-west-2 | jq .taskDefinition.revision`

#Create or update service
if [ "$SERVICES" == "" ]; then
  echo "entered existing service"
  DESIRED_COUNT=`aws ecs describe-services\
                 --services ${SERVICE_NAME}\
                 --cluster ${CLUSTER}\
                 --region ${REGION} | jq .services[].desiredCount`
  if [ ${DESIRED_COUNT} = "0" ]; then
    DESIRED_COUNT="1"
  fi
  aws ecs update-service\
    --cluster ${CLUSTER}\
    --region ${REGION}\
    --service ${SERVICE_NAME}\
    --task-definition ${FAMILY}:${REVISION}\
    --desired-count ${DESIRED_COUNT}
else
  echo "entered new service"
  aws ecs create-service --service-name simpleapp-service --desired-count 0 --task-definition simpleapp --cluster getting-started --region us-west-2 
fi
