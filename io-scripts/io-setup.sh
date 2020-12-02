#!/bin/bash

run()
{  
    github_file=.github/workflows/
    bitbucket_file=bitbucket-pipelines.yml
	
    if [ -a "$github_file" ]; then
        echo "$github_file exists."
        github_pipeline
    elif [ -f "$bitbucket_file" ]; then
        echo "$bitbucket_file exists."
        bitbucket_pipeline
    fi
	
    #method to generate YAML file
    generate_yaml "${ARGS[@]}"
}

function github_pipeline () {
    echo "Getting values from Github Actions"
	
    github_owner_name=$(echo $GITHUB_ACTOR)
    github_repo=$(echo $GITHUB_REPOSITORY)
    github_repo_name=$(echo $github_repo | cut -d'/' -f 2)
    github_ref=$(echo $GITHUB_REF)
	
    #variables needed to generate the YAML file
    asset_id=$github_repo
    scm_type=github
    repo_owner_name=$github_owner_name
    repo_name=$github_repo_name
    
    if [[ "$GITHUB_EVENT_NAME" == "push" ]]; then
        branch_name=$(echo $github_ref | cut -d'/' -f 3)
    elif [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
        branch_name=$GITHUB_HEAD_REF
    fi
}

function bitbucket_pipeline () {
    echo "Getting values from Bitbucket Pipelines"
	
    #variables needed to generate the YAML file
    #asset_id=
    scm_type=bitbucket
    #repo_owner_name=
    #repo_name=
    #branch_name=
}

function generate_yaml () {
    echo "Generating synopsys-io.yml"
    wget https://sigdevsecops.blob.core.windows.net/intelligence-orchestration/2020.11/synopsys-io.yml
	
    for i in "$@"; do
        case "$i" in
        --IO.url=*) url="${i#*=}" ;;
        --IO.token=*) authtoken="${i#*=}" ;;
        --slack.channel.id=*) slack_channel_id="${i#*=}" ;;    #slack
        --slack.token=*) slack_token="${i#*=}" ;;
        --jira.project.key=*) jira_project_key="${i#*=}" ;;    #jira
        --jira.assignee=*) jira_assignee="${i#*=}" ;;
        --jira.url=*) jira_server_url="${i#*=}" ;;
        --jira.username=*) jira_username="${i#*=}" ;;
        --jira.token=*) jira_auth_token="${i#*=}" ;;
        --bitbucket.workspace.name=*) bitbucket_workspace_name="${i#*=}" ;;    #bitbucket
        --bitbucket.repository.name=*) bitbucket_repo_name="${i#*=}" ;;
        --bitbucket.commit.id=*) bitbucket_commit_id="${i#*=}" ;;
        --bitbucket.username=*) bitbucket_username="${i#*=}" ;;
        --bitbucket.password=*) bitbucket_password="${i#*=}" ;;
        --github.commit.id=*) github_commit_id="${i#*=}" ;;
        --github.username=*) github_username="${i#*=}" ;;		#github
        --github.token=*) github_access_token="${i#*=}" ;;
        --polaris.project.name=*) polaris_project_name="${i#*=}" ;;		#polaris
        --polaris.url=*) polaris_server_url="${i#*=}" ;;
        --polaris.token=*) polaris_access_token="${i#*=}" ;;
        --blackduck.project.name=*) blackduck_project_name="${i#*=}" ;;		#blackduck
        --blackduck.url=*) blackduck_server_url="${i#*=}" ;;
        --blackduck.api.token=*) blackduck_access_token="${i#*=}" ;;
        *) ;;
        esac
    done
	
    io_manifest=$(cat synopsys-io.yml |
        sed " s~<<SLACK_CHANNEL_ID>>~$slack_channel_id~g; \
	    s~<<SLACK_TOKEN>>~$slack_token~g; \
	    s~<<JIRA_PROJECT_KEY>>~$jira_project_key~g; \
	    s~<<JIRA_ASSIGNEE>>~$jira_assignee~g; \
	    s~<<JIRA_SERVER_URL>>~$jira_server_url~g; \
	    s~<<JIRA_USERNAME>>~$jira_username~g; \
	    s~<<JIRA_AUTH_TOKEN>>~$jira_auth_token~g; \
	    s~<<BITBUCKET_WORKSPACE_NAME>>~$bitbucket_workspace_name~g; \
	    s~<<BITBUCKET_REPO_NAME>>~$bitbucket_repo_name~g; \
	    s~<<BITBUCKET_COMMIT_ID>>~$bitbucket_commit_id~g; \
	    s~<<BITBUCKET_USERNAME>>~$bitbucket_username~g; \
	    s~<<BITBUCKET_PASSWORD>>~$bitbucket_password~g; \
	    s~<<GITHUB_OWNER_NAME>>~$github_owner_name~g; \
	    s~<<GITHUB_REPO_NAME>>~$github_repo_name~g; \
	    s~<<GITHUB_REF>>~$github_ref~g; \
	    s~<<GITHUB_COMMIT_ID>>~$github_commit_id~g; \
	    s~<<GITHUB_USERNAME>>~$github_username~g; \
	    s~<<GITHUB_ACCESS_TOKEN>>~$github_access_token~g; \
	    s~<<POLARIS_PROJECT_NAME>>~$polaris_project_name~g; \
	    s~<<POLARIS_SERVER_URL>>~$polaris_server_url~g; \
	    s~<<POLARIS_ACCESS_TOKEN>>~$polaris_access_token~g; \
	    s~<<BLACKDUCK_PROJECT_NAME>>~$blackduck_project_name~g; \
	    s~<<BLACKDUCK_SERVER_URL>>~$blackduck_server_url~g; \
	    s~<<BLACKDUCK_ACCESS_TOKEN>>~$blackduck_access_token~g; \
	    s~<<APP_ID>>~$asset_id~g; \
	    s~<<ASSET_ID>>~$asset_id~g; \
	    s~<<SCM_TYPE>>~$scm_type~g; \
	    s~<<REPO_OWNER_NAME>>~$repo_owner_name~g; \
	    s~<<REPO_NAME>>~$repo_name~g; \
	    s~<<BRANCH_REF>>~$branch_name~g")
    
    # apply the yml with the substituted value
    echo "$io_manifest" >synopsys-io.yml
	
    validate_values "IO_SERVER_URL" "$url"
    validate_values "IO_SERVER_TOKEN" "$authtoken"
	
    create_asset "$url" "$authtoken" "$asset_id"
    echo "synopsys-io.yml generated"
}

function create_asset () {
    io_url=$1
    userToken=$2
    assetId=$3
	
    onBoardingResponse=$(curl --location --request POST "$io_url/stargazer/api/applications/update" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $userToken" \
    --data-raw '{
        "assetId": '\"$assetId\"',
        "assetType": "Github",
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

    echo $onBoardingResponse
}

function validate_values () {
    key=$1
    value=$2
    if [ -z "$value" ]; then
        exit_program "$key value is null"
    fi
}

function exit_program () {
    message=$1
    printf '\e[31m%s\e[0m\n' "$message"
    printf '\e[31m%s\e[0m\n' "Exited with error code 1"
    exit 1
}

ARGS=("$@")

run
