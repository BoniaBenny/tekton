#!/bin/bash

# the purpose of this script is to install the AWS CLI

AWS_ACCESS_KEY_ID=''
AWS_SECRET_ACCESS_KEY=''
ARCH=$(uname -m)

showHelp () {
        cat << EOF
        Usage: ./installAWSCLI.sh [-h|--help -i|--aws_access_key_id=<IAM KEY ID> -s|--aws_secret_access_key=<IAM_SECRET_KEY]
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

# Choose appropriate AWS CLI installation based on the architecture
if [ "$ARCH" = "x86_64" ]; then
    AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
elif [ "$ARCH" = "aarch64" ]; then
    AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi


# install aws cli 
apt update
apt install -y curl unzip groff
curl "$AWS_CLI_URL" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

