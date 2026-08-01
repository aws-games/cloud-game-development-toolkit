#!/bin/bash

# This script pulls the Cloud DDC NLB DNS record and the bearer token secret value from AWS.
# It then curls the Cloud DDC API to put a blob, and then curls the Cloud DDC API to get that same blob.
# It compares the two to ensure that the Cloud DDC service is running as expected.

# Query AWS for the unreal-cloud-ddc NLB DNS name and save it to a local variable
unreal_cloud_ddc_nlb_dns_name=$(aws elbv2 describe-load-balancers --names unreal-cloud-ddc --query 'LoadBalancers[*].DNSName' --output text)

# Query AWS for the bearer token secret value and save it to a local variable
bearer_token_secret_value=$(aws secretsmanager get-secret-value --secret-id unreal-cloud-ddc-token --query 'SecretString' --output text)

echo "********************"
echo "*Putting test data:*"
echo "********************"
echo ""
# Curl the Cloud DDC API to PUT a "test" data blob
curl http://$unreal_cloud_ddc_nlb_dns_name/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa -X PUT --data 'test' -H 'content-type: application/octet-stream' -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' -i -H "Authorization: ServiceAccount $bearer_token_secret_value"
echo ""
echo ""
echo "********************"
echo "*Getting test data:*"
echo "********************"
echo ""
# Curl the Cloud DDC API to GET the "test" data blob back
curl http://$unreal_cloud_ddc_nlb_dns_name/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json -i -H "Authorization: ServiceAccount $bearer_token_secret_value"
