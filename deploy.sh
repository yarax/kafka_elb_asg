aws cloudformation deploy --profile $PROFILE --region $REGION --template-file ./cloudformation/vpc_github.yaml --stack-name KafkaDemoVPC2

aws cloudformation deploy --profile $PROFILE --region $REGION --template-file ./cloudformation/asg.yaml --stack-name KafkaDemoCluster --parameter-overrides UserData=$(cat ./dynamic_ips.sh | base64)

