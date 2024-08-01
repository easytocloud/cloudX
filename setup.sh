aws cloudformation update-stack \
  --region eu-central-1 \
  --stack-name cloudX-deployment \
  --template-url https://easytocloudx.s3.amazonaws.com/cloudX.yaml \
  --parameters \
    ParameterKey=Subnet,ParameterValue=subnet-8cfa4fe5 \
    ParameterKey=AbacTag,ParameterValue=cloudx:security:vscodeuser \
    ParameterKey=GroupName,ParameterValue=cloudXtracentral \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND

# ParameterKey=Subnet,ParameterValue=subnet-04966d5c \