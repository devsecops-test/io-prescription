#!/bin/sh

for i in "$@"; do
    case "$i" in
    --io.url=*) io_url="${i#*=}" ;;
    --workflow.engine.url=*) workflow_url="${i#*=}" ;;
    --username=*) userName="${i#*=}" ;;
    --password=*) password="${i#*=}" ;;
    --io.asset.id=*) assetId="${i#*=}" ;;
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

if [ "$signupResponse" = "New user created with a token" ] ; then
    userToken=$(curl --location --request POST "$io_url/stargazer/user/token" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "userName": '\"$userName\"',
        "password": '\"$password\"'
    }');
    echo $userToken;
    
    onBoardingResponse=$(curl --location --request POST "$io_url/stargazer/api/applications/update" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $userToken" \
    --data-raw '{
        "assetId": '\"$assetId\"',
        "assetType": "Application",
        "applicationType": "Financial",
        "applicationName": "Test app 1",
        "applicationBuildName": "test-build",
        "soxFinancial": true,
        "ppi": true,
        "mnpi": true,
        "infoClass": "Restricted",
        "customerFacing": true,
        "externallyFacing": true,
        "assetTier": "Tier 01",
        "fairLending": true
    }');

    if [ "$onBoardingResponse" = "TPI Data created/updated successfully" ] ; then

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
        
        wget https://sigdevsecops.blob.core.windows.net/intelligence-orchestration/2020.09.01/ApplicationManifest_Sample.yml
        workflow=$(cat $workflow_file | sed " s~<<IO_ASSET_ID>>~$assetId~g")
        # apply the yml with the substituted value
        echo "$workflow" >ApplicationManifest.yml
        rm ApplicationManifest_Sample.yml
		
		echo "Save the following values for further use:"
        echo "assetId: $assetId"
        echo "IO_ACCESS_TOKEN: $userToken"
        echo "WORKFLOW_ENGINE_ACCESS_TOKEN: $workflowUserToken"
        echo "INFO: ApplicationManifest.yml is generated. Please update the source code management details in it and add the file to the root of the project."
    else
        echo $onBoardingResponse;
        exit 1;
    fi

else 
    echo $signupResponse;
    exit 1;
fi
