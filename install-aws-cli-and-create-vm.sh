#!/bin/bash


# the purpose of this script is to create AWS VM


AWS_ACCESS_KEY_ID=''
AWS_SECRET_ACCESS_KEY=''
ARCH=$(uname -m)

showHelp () {
        cat << EOF
        Usage: ./create-vm.sh [-h|--help -i|--aws_access_key_id=<IAM KEY ID> -s|--aws_secret_access_key=<IAM_SECRET_KEY]
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

echo "****"
echo "Listing contents"
ls
echo "****"

# install jq
apt-get install jq -y

# create a key pair
aws ec2 create-key-pair --key-name My_Pair9 --query 'KeyMaterial' --output text > My_KeyPair1.pem

echo "****"
cat My_KeyPair1.pem
echo "****"

# get vpcid
VPC_ID=$(aws ec2 describe-vpcs | jq -e -r ".Vpcs[0].VpcId")

# get first subnet associated with VPC_ID
SUBNET_ID=$(aws ec2 describe-subnets --filter="Name=vpc-id,Values=${VPC_ID}" |  jq -e -r ".Subnets[0].SubnetId")

# hardcode the AMI id for now
AMI_ID=ami-0506d6d51f1916a96

# Create a security group
# aws ec2 create-security-group \
#     --group-name my-sg2 \
#     --description "AWS ec2 CLI MY SG" \
#     --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=my-sg2}]' \
#     --vpc-id "${VPC_ID}"

# get the security group id
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filter="Name=group-name,Values=my-sg2" | jq -e -r ".SecurityGroups[0].GroupId")

# create an ingress rule for ssh access
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# launch the instance
aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t3.micro \
  --key-name My_Pair9 \
  --security-group-ids ${SECURITY_GROUP_ID} \
  --subnet-id ${SUBNET_ID} \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=tektontest2}]'

  # test the copying of a script to new instance
  echo "#!/bin/bash" >> testscript.sh
  echo "echo \$(hostname) > hostname_output.txt" >> testscript.sh\
  chmod 755 testscript.sh

  # install scp
  apt-get install openssh-client -y

  # get the instanceID
  INSTANCE_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=tektontest2 Name=instance-state-name,Values=running | jq -e -r ".Reservations[].Instances[].InstanceId")

  # get the instance PublicDNS
  PUBLIC_DNS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[].Instances[].PublicDnsName' | jq -e -r ".[]")

  #sleep for 20 secs, looks like it takes a while for the security group rule to activate
  echo "sleeping for 20 secs"
  sleep 20

  # reduce permissions on .pem file
  chmod 400 My_KeyPair1.pem

  # scp file over to new instance and execute it 
  scp  -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i My_KeyPair1.pem -r ./testscript.sh admin@${PUBLIC_DNS}:~/

  ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i My_KeyPair1.pem admin@${PUBLIC_DNS} 'chmod 755 ~/testscript.sh && bash ~/testscript.sh'
