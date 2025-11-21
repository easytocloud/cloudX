# Derived from Easytocloud: https://github.com/easytocloud/cloudX
# Example to test in DOS commmand prompt:
# 	powershell.exe  -ExecutionPolicy Unrestricted "%USERPROFILE%\vscode\cloudx-proxy.ps1 i-xxxxxxxxxxxxx 22 standard cloudx-profile $HOME\vscode\cloudx-key.pub"
#
# Andries Krijtenburg, 2023

$MAX_ITERATION = 30
$SLEEP_DURATION = 3

$EC2_HOST = $args[0]
$EC2_PORT = $args[1]
$AWS_ENV = if ($args[2]) { $args[2] } else { "standard" }
$env:AWS_PROFILE = if ($args[3]) { $args[3] } else { "cloudx-profile" }
$PUBLIC_KEY_PATH = if ($args[4]) { $args[4] } else { "$HOME\vscode\cloudx-key.pub" }
$env:AWS_REGION = if ($args[5]) { $args[5] } else { "eu-west-1" }

Write-Host "Host: $EC2_HOST"
Write-Host "Port: $EC2_PORT"
Write-Host "Profile: $env:AWS_PROFILE" 
Write-Host "Region: $env:AWS_REGION"

Function Get-EC2-Status($EC2, $Profile, $Region){
	$STATUS = aws ssm describe-instance-information `
		--filters Key=InstanceIds,Values=$EC2 `
		--output text `
		--query InstanceInformationList[0].PingStatus `
		--profile $Profile `
		--region $Region
		
	return $STATUS
}

$STATUS = Get-EC2-Status $EC2_HOST $env:AWS_PROFILE $env:AWS_REGION

Write-Host "EC2 Status: $STATUS" 


if ($STATUS -ne "Online") {
	aws ec2 start-instances --instance-ids $EC2_HOST --profile $env:AWS_PROFILE --region $env:AWS_REGION
    Start-Sleep -Seconds $SLEEP_DURATION

    $COUNT = 1

    while ($COUNT -le $MAX_ITERATION) {
        $STATUS = Get-EC2-Status $EC2_HOST $env:AWS_PROFILE $env:AWS_REGION

        if ($STATUS -eq "Online") {
            break
        }
        Write-Host "RETRY $COUNT"
        $COUNT++
        Start-Sleep -Seconds $SLEEP_DURATION
    }

    if ($COUNT -gt $MAX_ITERATION) {
        Write-Host "Instance did not come online within the expected time."
        exit 1
    }
}

if($STATUS -eq "Online"){
	# Instance is online
	# Connect by first pushing a public key to the instance
	aws ec2-instance-connect send-ssh-public-key `
		--instance-id $EC2_HOST `
		--instance-os-user "ec2-user" `
		--ssh-public-key "file://$PUBLIC_KEY_PATH"

	# .. and then start the session
	aws ssm start-session `
		--target $EC2_HOST `
		--document-name AWS-StartSSHSession `
		--parameters portNumber=${EC2_PORT} 
}

#SSH Config example (assuming you created the folder vscode somewhere):
#Host cloudx
#  ProxyCommand powershell.exe  -ExecutionPolicy Unrestricted "C:\Users\Me\vscode\cloudx-proxy.ps1 i-xxxxxxxxxxxxxxxxx 22 standard cloudx-profile C:\Users\Me\vscode\cloudx-key.pub"
#  ServerAliveInterval 60
#  User ec2-user
#  IdentityFile C:\Users\Me\vscode\cloudx-key
#  HostKeyAlgorithms -ssh-rsa
#  HostName i-xxxxxxxxxxxxxxxxx # EC2 instance ID