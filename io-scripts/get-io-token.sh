#!/bin/sh

for i in "$@"; do
    case "$i" in
    --io.url=*) io_url="${i#*=}" ;;
    --workflow.engine.url=*) workflow_url="${i#*=}" ;;
    --username=*) userName="${i#*=}" ;;
    --password=*) password="${i#*=}" ;;
    *) ;;
    esac
done

signupResponse=$(curl --location --request POST "$io_url/stargazer/user/signup" \
--header 'Content-Type: application/json' \
--data-raw '{
    "userName": '\"$userName\"',
    "password": '\"$password\"',
    "confirmPassword": '\"$password\"'
}');

userToken=$(curl --location --request POST "$io_url/stargazer/user/token" \
--header 'Content-Type: application/json' \
--data-raw '{
	"userName": '\"$userName\"',
	"password": '\"$password\"'
}');

workflowSignupResponse=$(curl --location --request POST "$workflow_url/sct/user/signup" \
--header 'Content-Type: application/json' \
--data-raw '{
	"userName": '\"$userName\"',
	"password": '\"$password\"',
	"confirmPassword": '\"$password\"'
}');

workflowUserToken=$(curl --location --request POST "$workflow_url/sct/user/token" \
--header 'Content-Type: application/json' \
--data-raw '{
	"userName": '\"$userName\"',
	"password": '\"$password\"'
}');

echo "IO_ACCESS_TOKEN: $userToken"
echo "WORKFLOW_ENGINE_ACCESS_TOKEN: $workflowUserToken"

