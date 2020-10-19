#!/bin/bash

run() {
    box_line "Synopsys Intelligent Security Scan" "Copyright Ã‚Â© 2016-2020 Synopsys, Inc. All rights reserved worldwide."
    allargs="${ARGS[@]}"

    for i in "${ARGS[@]}"; do
        case "$i" in
        --stage=*) stage="${i#*=}" ;;
        --workflow.version=*) workflow_version="${i#*=}" ;;
        *) ;;
        esac
    done
	
    #validate stage
    validate_values "STAGE" "$stage"
	
    echo ""
    box_star "Current Stage is set to ${stage}"
    
    if [[ "${stage}" == "IO" ]]; then
        getPrescription "${ARGS[@]}"
    elif [[ "${stage}" == "WORKFLOW" ]]; then
        loadWorkflow "${ARGS[@]}"
    else
        exit_program "Invalid Stage"
    fi
}

function loadWorkflow() {
    for i in "$@"; do
        case "$i" in
        --IO.url=*) url="${i#*=}" ;;
        --IO.token=*) authtoken="${i#*=}" ;;
        --workflow.url=*) workflow_url="${i#*=}" ;;
        --workflow.token=*) workflow_token="${i#*=}" ;;
        --workflow.template=*) workflow_file="${i#*=}" ;;
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
        --github.owner.name=*) github_owner_name="${i#*=}" ;;    #github
        --github.repository.name=*) github_repo_name="${i#*=}" ;;
        --github.ref=*) github_ref="${i#*=}" ;;
        --github.commit.id=*) github_commit_id="${i#*=}" ;;
        --github.username=*) github_username="${i#*=}" ;;
        --github.token=*) github_access_token="${i#*=}" ;;
        --IS_SAST_ENABLED=*) is_sast_enabled="${i#*=}" ;;    #polaris
        --polaris.project.name=*) polaris_project_name="${i#*=}" ;;
		--polaris.url=*) polaris_server_url="${i#*=}" ;;
        --polaris.token=*) polaris_access_token="${i#*=}" ;;
        --IS_SCA_ENABLED=*) is_sca_enabled="${i#*=}" ;;     #blackduck
        --blackduck.project.name=*) blackduck_project_name="${i#*=}" ;;
        --blackduck.url=*) blackduck_server_url="${i#*=}" ;;
        --blackduck.api.token=*) blackduck_access_token="${i#*=}" ;;
        *) ;;
        esac
    done
    
    #checks if the manifest files are present
    is_workflow_manifest_present
	
    #validates mandatory arguments for IO
    validate_values "IO_SERVER_URL" "$url"
    validate_values "IO_SERVER_TOKEN" "$authtoken"
    validate_values "WORKFLOW_SERVER_URL" "$workflow_url"
    validate_values "WORKFLOW_SERVER_TOKEN" "$workflow_token"
	
    echo "Editing Workflow Template"
    # read the workflow.yml from a file and substitute the string
    # {{MYVARNAME}} with the value of the MYVARVALUE variable
    workflow=$(cat $workflow_file |
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
    s~<<IS_SAST_ENABLED>>~$is_sast_enabled~g; \
    s~<<POLARIS_PROJECT_NAME>>~$polaris_project_name~g; \
    s~<<POLARIS_SERVER_URL>>~$polaris_server_url~g; \
    s~<<POLARIS_ACCESS_TOKEN>>~$polaris_access_token~g; \
    s~<<IS_SCA_ENABLED>>~$is_sca_enabled~g; \
    s~<<BLACKDUCK_PROJECT_NAME>>~$blackduck_project_name~g; \
    s~<<BLACKDUCK_SERVER_URL>>~$blackduck_server_url~g; \
    s~<<BLACKDUCK_ACCESS_TOKEN>>~$blackduck_access_token~g")
    # apply the yml with the substituted value
    echo "$workflow" >synopsys-io-workflow.yml
	
    io_assetId=$(ruby -r yaml -e 'puts YAML.load_file(ARGV[0])["application"]["assetId"]' ApplicationManifest.yml)
    curr_date=$(date +'%Y-%m-%d')
   
    scandate_json="{\"assetId\": \"${io_assetId}\",\"activities\":{"
    if [ "$is_sast_enabled" = true ] ; then
       scandate_json="$scandate_json\"sast\": {\"lastScanDate\": \"${curr_date}\"}"
    fi
    if [ "$is_sca_enabled" = true ] && [ "$is_sast_enabled" = true ] ; then
       scandate_json="$scandate_json,"
    fi
    if [ "$is_sca_enabled" = true ] ; then
       scandate_json="$scandate_json\"sca\": {\"lastScanDate\": \"${curr_date}\"}"
    fi
    scandate_json="$scandate_json}}"
    echo "$scandate_json" >scandate.json
    echo "$scandate_json"
	
    header='Authorization: Bearer '$authtoken''
    scandateresponse=$(curl -X POST -H 'Content-Type:application/json' -H 'Accept:application/json' -H "${header}" -d @scandate.json ${url}/stargazer/api/manifest/update/scandate)
    echo $scandateresponse
}

function getPrescription() {

    echo "Inside Prescription"
    echo "$@"

    for i in "$@"; do
        case "$i " in
        --IO.url=*) url="${i#*=}" ;;
        --IO.token=*) authtoken="${i#*=}" ;;
        --app.manifest.path=*) afile="${i#*=}" ;;
        --sec.manifest.path=*) sfile="${i#*=}" ;;
        --persona=*) persona="${i#*=}" ;;
        *) ;;
        esac
    done
    
    #checks if the manifest files are present
    is_io_manifest_present
	
    #validates mandatory arguments for IO
    validate_values "IO_SERVER_URL" "$url"
    validate_values "IO_SERVER_TOKEN" "$authtoken"
	
    #chosing API - if persona is set to "developer" then "/api/manifest/update/persona/developer" will be called
    #chosing API - if persona is empty then "/api/manifest/update" will be called
    if [[ -z $persona ]]; then
        API="update"
    else
        API="update/persona/developer"
    fi

    echo $afile
    echo $sfile

    header='Authorization: Bearer '$authtoken''

    if [[ $afile == *.yml && $sfile == *.yml ]]; then
        cat $afile $sfile >>merge.yml
        #Yaml to Json Conversion
        echo $(ruby -ryaml -rjson -e "puts JSON.pretty_generate(YAML.safe_load(File.read('merge.yml')))") >>data.json
        echo "Getting Prescription"
        prescrip=$(curl -X POST -H 'Content-Type:application/json' -H 'Accept:application/json' -H "${header}" -d @data.json ${url}/stargazer/api/manifest/${API})
        echo $prescrip
        echo $prescrip >>result.json
    else
        exit_program "Invalid Files"
    fi

    echo "::set-output name=sastScan::$(ruby -rjson -e 'j = JSON.parse(File.read("result.json")); puts j["security"]["activities"]["sast"]["enabled"]')"
    echo "::set-output name=scaScan::$(ruby -rjson -e 'j = JSON.parse(File.read("result.json")); puts j["security"]["activities"]["sca"]["enabled"]')"
    echo "::set-output name=dastScan::$(ruby -rjson -e 'j = JSON.parse(File.read("result.json")); puts j["security"]["activities"]["dast"]["enabled"]')"

    echo "Cleaning Up"
    rm -r data.json
    rm -r merge.yml
    rm -r result.json

}

function validate_values () {
    key=$1
    value=$2
    if [ -z "$value" ]; then
        exit_program "$key value is null"
    fi
}

function is_io_manifest_present () {
    if [ ! -f "ApplicationManifest.yml" ]; then
        exit_program "ApplicationManifest.yml file does not exist"
		
    fi
    if [ ! -f "SecurityManifest.yml" ]; then
        printf "SecurityManifest.yml file does not exist\n"
        printf "Downloading default SecurityManifest.yml\n"
        wget https://sigdevsecops.blob.core.windows.net/intelligence-orchestration/${workflow_version}/SecurityManifest.yml
    fi
}

function is_workflow_manifest_present () {
    if [ ! -f "ApplicationManifest.yml" ]; then
        exit_program "ApplicationManifest.yml file does not exist"
    fi
    if [ ! -f "WorkflowTemplate.yml" ]; then
        printf "WorkflowTemplate.yml file does not exist\n"
        printf "Downloading default WorkflowTemplate.yml\n"
        wget https://sigdevsecops.blob.core.windows.net/intelligence-orchestration/${workflow_version}/WorkflowTemplate.yml
    fi
    if [ ! -f "WorkflowClient.jar" ]; then
        printf "WorkflowClient.jar file does not exist\n"
        printf "Downloading default WorkflowClient.jar\n"
        wget https://sigdevsecops.blob.core.windows.net/intelligence-orchestration/${workflow_version}/WorkflowClient.jar
    fi
}

function box_line () {
    arg1=$1
    arg2=$2
    len=$((${#arg2}+5))
    box_str="\n+"
    for i in $(seq $len); do box_str="$box_str-"; done;
    box_str="$box_str+\n| "$arg1" "$(printf '%*s' 35)" |\n"
    box_str="$box_str| "$arg2" "$(printf '%*s' 2)" |\n+"
    for i in $(seq $len); do box_str="$box_str-"; done;
    box_str="$box_str+\n\n"
    printf "$box_str"
}

function box_star () {
    str="$@"
    len=$((${#str}+4))
    box_str="\n"
    for i in $(seq $len); do box_str="$box_str*"; done;
    box_str="$box_str\n* "$str" *\n"
    for i in $(seq $len); do box_str="$box_str*"; done;
    box_str="$box_str\n\n"
    printf "$box_str"
}

function exit_program () {
    message=$1
    printf '\e[31m%s\e[0m\n' "$message"
    printf '\e[31m%s\e[0m\n' "Exited with error code 1"
    exit 1
}

ARGS=("$@")

run
