# AWS CLI aliases
alias a='aws'
alias as3='aws s3'
alias as3ls='aws s3 ls'
alias as3cp='aws s3 cp'
alias as3sync='aws s3 sync'
alias as3rm='aws s3 rm'
alias as3mb='aws s3 mb'
alias as3rb='aws s3 rb'

# EC2
alias aec2='aws ec2'
alias aec2ls='aws ec2 describe-instances'
alias aec2start='aws ec2 start-instances --instance-ids'
alias aec2stop='aws ec2 stop-instances --instance-ids'

# Lambda
alias alam='aws lambda'
alias alamls='aws lambda list-functions'
alias alaminv='aws lambda invoke'

# CloudFormation
alias acf='aws cloudformation'
alias acfls='aws cloudformation list-stacks'
alias acfdesc='aws cloudformation describe-stacks'

# SSM
alias assm='aws ssm'
alias assmgp='aws ssm get-parameter'
alias assmgps='aws ssm get-parameters'

# Profile management
alias awsp='export AWS_PROFILE='
alias awsr='export AWS_REGION='
alias awsl='aws configure list'
alias awsw='aws sts get-caller-identity'