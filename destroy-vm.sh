#!/bin/bash


# the purpose of this script is to destroy AWS VM

AWS_ACCESS_KEY_ID=''
AWS_SECRET_ACCESS_KEY=''
# region is hardcoded for now
AWS_REGION="eu-north-1"

showHelp () {
        cat << EOF
        Usage: ./destroy-vm.sh [-h|--help -i|--aws_access_key_id=<IAM KEY ID> -s|--aws_secret_access_key=<IAM_SECRET_KEY> -v|--vm=<VM to be deleted>] 
Helper script to deploy the AWS CLI
-h, --help                                      Display help
-i, --aws_access_key_id                         IAM access key ID
-s, --aws_secret_access_key                     IAM secret access key
-v, --vm                                        Name of the VM to be deleted
EOF
}

options=$(getopt -l "help,aws_secret_access_key:,aws_secret_access_key:,vm:" -o "h,i:,s:,v:" -a -- "$@")
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
        -v|--vm)
                shift
                VM_NAME="${1}"
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

# install aws cli
apt update
apt install -y curl unzip groff
./aws/install

# get instance ID for the given VM
INSTANCE_ID=$(aws ec2 describe-instances --region $AWS_REGION --filters "Name=tag:Name,Values=$VM_NAME" --query "Reservations[*].Instances[*].InstanceId" --output text)

if [ -z "$INSTANCE_ID" ]; then
  echo "No instance found with the name $VM_NAME in region $AWS_REGION"
  exit 1
else
  echo "Instance ID for the VM $VM_NAME: $INSTANCE_ID"
fi

# terminate the vm
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

sleep 10

# describe the status of the vm
aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" --output table
