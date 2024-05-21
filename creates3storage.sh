#!/bin/bash

# the purpose of this script is to create s3 storage in AWS

AWS_ACCESS_KEY_ID=''
AWS_SECRET_ACCESS_KEY=''

showHelp () {
        cat << EOF
        Usage: ./creates3storage.sh [-h|--help -i|--aws_access_key_id=<IAM KEY ID> -s|--aws_secret_access_key=<IAM_SECRET_KEY]
Helper script to deploy the AWS CLI
-h, --help                                      Display help
-i, --aws_access_key_id                         IAM access key ID
-s, --aws_secret_access_key                     IAM secret access key
EOF
}

options=$(getopt -l "help,aws_secret_access_key:,aws_secret_access_key:" -o "h,i:,s:" -a -- "$@")
eval set -- "${options}"
while true; do
        case ${1} in
        -h|--help)
                showHelp
                exit 0
                ;;
        -i|--aws_access_key_id)
                shift
                AWS_ACCESS_KEY_ID="${1}"
                ;;
        -s|--aws_secret_access_key)
                shift
                AWS_SECRET_ACCESS_KEY="${1}"
                ;;
        --)
                shift
                break
                ;;
        esac
shift
done

if [ -e ~/.aws ]; then
  rm -rf ~/.aws
  mkdir ~/.aws
else
  mkdir ~/.aws
fi

echo "[default]" >> ~/.aws/credentials
echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials

echo "[default]" >> ~/.aws/config
echo "region = eu-north-1" >> ~/.aws/config

# install aws cli for ARM64 architecture
apt update
apt install -y curl unzip groff
./aws/install

# install jq
apt-get install jq -y

# create a key pair
aws ec2 create-key-pair --key-name My_Pair --query 'KeyMaterial' --output text > My_KeyPair.pem
chmod 400 My_KeyPair.pem

# create s3 storage
aws s3 ls --profile default
aws s3api create-bucket --bucket test-tekton-aws-cli --region us-east-1 
# create a folder
aws s3api put-object --bucket test-tekton-aws-cli --key folder-1/

echo "****"
echo "Listing contents"
ls
echo "****"


INSTANCE_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=tektontest1 Name=instance-state-name,Values=running | jq -e -r ".Reservations[].Instances[].InstanceId")

# get PublicDNS & ssh into the VM
PUBLIC_DNS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[].Instances[].PublicDnsName' | jq -e -r ".[]")

ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i My_KeyPair.pem admin@${PUBLIC_DNS} './testscript.sh'

# copy file from VM to S3 bucket
aws s3 cp hostname_output.txt s3://test-tekton-aws-cli/


