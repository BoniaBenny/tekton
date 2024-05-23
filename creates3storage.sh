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


apt-get install jq -y
apt-get install openssh-client -y

# create a key pair
# aws ec2 create-key-pair --key-name My_Pair6 --query 'KeyMaterial' --output text > My_KeyPair.pem
chmod 400 My_KeyPair1.pem

# create s3 storage
aws s3 ls --profile default
aws s3api create-bucket --bucket test-tekton-aws-cli --region us-east-1 
# create a folder
aws s3api put-object --bucket test-tekton-aws-cli --key folder-1/

echo "****"
echo "Listing contents"
ls
echo "****"

echo "aws_access_key_id: ${AWS_ACCESS_KEY_ID}" >> s3_credentials.yaml
echo "aws_secret_access_key: ${AWS_SECRET_ACCESS_KEY}" >> s3_credentials.yaml
echo "region: us-east-1" >> s3_credentials.yaml


INSTANCE_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=tektontest2 Name=instance-state-name,Values=running | jq -e -r ".Reservations[].Instances[].InstanceId")

# get PublicDNS & ssh into the VM
PUBLIC_DNS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[].Instances[].PublicDnsName' | jq -e -r ".[]")

scp  -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i s3_credentials.yaml -r ./testscript.sh admin@${PUBLIC_DNS}:~/

ssh -o "StrictHostKeyChecking no" \
    -o "UserKnownHostsFile /dev/null" \
    -i My_KeyPair1.pem \
    admin@${PUBLIC_DNS} \
    'wget https://github.com/mikefarah/yq/releases/download/v4.13.4/yq_linux_amd64 -O yq && \
    chmod +x yq && \
    sudo mv yq /usr/local/bin && \
    chmod 755 ~/testscript.sh && \
    bash ~/testscript.sh && \
    echo "****" && \
    echo "Listing contents inside VM:" && \
    ls && \
    echo "Current working directory:" && \
    pwd && \
    echo "****" && \
    key_id=$(yq e '.aws_access_key_id' s3_credentials.yaml) && \
    secret_id=$(yq e '.aws_secret_access_key' s3_credentials.yaml) && \
    region=$(yq e '.region' s3_credentials.yaml) && \
    aws configure set aws_access_key_id $key_id && \
    aws configure set aws_secret_access_key $secret_id && \
    aws configure set region $region && \
    aws s3 cp $PWD/hostname_output.txt s3://test-tekton-aws-cli/'

