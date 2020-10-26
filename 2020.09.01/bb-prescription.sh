#!/bin/bash

run() {
    #chosing API - persona variable validation, API will be set to "update" if persona is empty and will be "update/persona/developer" if non empty
    #adding attributes to workflow file -- Call this function only if the inout has "--workflow.template" file name
    box_line "Synopsys Intelligent Security Scan" "Copyright ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© 2016-2020 Synopsys, Inc. All rights reserved worldwide."
    allargs="${ARGS[@]}"

    for i in "${ARGS[@]}"; do
        # Option=$(echo $i | cut -f1 -d=)
        # input=$(echo $i | cut -f2 -d=)
        case "$i" in
        --stage=*) stage="${i#*=}" ;;
        *) ;;
        esac
    done

    box_star "Current Stage is set to ${stage}"
    
    if [[ "${stage}" == "IO" ]]; then
        getPrescription "${ARGS[@]}"
    elif [[ "${stage}" == "WORKFLOW" ]]; then
        loadWorkflow "${ARGS[@]}"
    else
        echo "Invalid Stage"
    fi
}

function loadWorkflow() {
    for i in "$@"; do
        case "$i" in
        --IO.url=*) url="${i#*=}" ;;
        --IO.token=*) authtoken="${i#*=}" ;;
        --workflow.template=*) workflow_file="${i#*=}" ;;
        --slack.channel.id=*) slack_channel_id="${i#*=}" ;;
        --slack.token=*) slack_token="${i#*=}" ;;
        --jira.url=*) jira_server_url="${i#*=}" ;;
        --jira.username=*) jira_username="${i#*=}" ;;
        --jira.token=*) jira_auth_token="${i#*=}" ;;
        --bitbucket.commit.id=*) bitbucket_commit_id="${i#*=}" ;;
        --bitbucket.username=*) bitbucket_username="${i#*=}" ;;
        --bitbucket.password=*) bitbucket_password="${i#*=}" ;;
        --github.commit.id=*) github_commit_id="${i#*=}" ;;
        --github.username=*) github_username="${i#*=}" ;;
        --github.token=*) github_access_token="${i#*=}" ;;
        --IS_SAST_ENABLED=*) is_sast_enabled="${i#*=}" ;;
        --polaris.url=*) polaris_server_url="${i#*=}" ;;
        --polaris.token=*) polaris_access_token="${i#*=}" ;;
        --IS_SCA_ENABLED=*) is_sca_enabled="${i#*=}" ;;
        --blackduck.url=*) blackduck_server_url="${i#*=}" ;;
        --blackduck.api.token=*) blackduck_access_token="${i#*=}" ;;
        *) ;;
        esac
    done

    # read the workflow.yml from a file and substitute the string
    # {{MYVARNAME}} with the value of the MYVARVALUE variable
    workflow=$(cat $workflow_file |
        sed " s~<<SLACK_CHANNEL_ID>>~$slack_channel_id~g; \
    s~<<SLACK_TOKEN>>~$slack_token~g; \
    s~<<JIRA_SERVER_URL>>~$jira_server_url~g; \
    s~<<JIRA_USERNAME>>~$jira_username~g; \
    s~<<JIRA_AUTH_TOKEN>>~$jira_auth_token~g; \
    s~<<BITBUCKET_COMMIT_ID>>~$bitbucket_commit_id~g; \
    s~<<BITBUCKET_USERNAME>>~$bitbucket_username~g; \
    s~<<BITBUCKET_PASSWORD>>~$bitbucket_password~g; \
    s~<<GITHUB_COMMIT_ID>>~$github_commit_id~g; \
    s~<<GITHUB_USERNAME>>~$github_username~g; \
    s~<<GITHUB_ACCESS_TOKEN>>~$github_access_token~g; \
    s~<<IS_SAST_ENABLED>>~$is_sast_enabled~g; \
    s~<<POLARIS_SERVER_URL>>~$polaris_server_url~g; \
    s~<<POLARIS_ACCESS_TOKEN>>~$polaris_access_token~g; \
    s~<<IS_SCA_ENABLED>>~$is_sca_enabled~g; \
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
	
    echo "updating last scan date for perfomed security activities"
    header='Authorization: Bearer '$authtoken''
    scandateresponse=$(curl -X POST -H 'Content-Type:application/json' -H 'Accept:application/json' -H "${header}" -d @scandate.json ${url}/stargazer/api/manifest/update/scandate)
    echo $scandateresponse
}

function getPrescription() {
    echo "$@"

    for i in "$@"; do
        case "$i " in
        --IO.url=*) url="${i#*=}" ;;
        --IO.token=*) authtoken="${i#*=}" ;;
        --bitbucket.username=*) bitbucket_username="${i#*=}" ;;
        --bitbucket.password=*) bitbucket_password="${i#*=}" ;;
        --scm.branch.name=*) scm_branch_name="${i#*=}" ;;
        --app.manifest.path=*) afile="${i#*=}" ;;
        --sec.manifest.path=*) sfile="${i#*=}" ;;
        --persona=*) persona="${i#*=}" ;;
        *) ;;
        esac
    done

    if [[ -z $persona ]]; then
        API="update"
    else
        API="update/persona/$persona"
    fi

    header='Authorization: Bearer '$authtoken''

    if [[ $afile == *.yml && $sfile == *.yml ]]; then
        dynamicApplicationManifest=$(cat $afile | \
        sed "s~<<BITBUCKET_USERNAME>>~$bitbucket_username~g; \
        s~<<BITBUCKET_PASSWORD>>~$bitbucket_password~g; \
        s~<<SCM_BRANCH_NAME>>~$scm_branch_name~g")
        # apply the yml with the substituted value
        echo "$dynamicApplicationManifest" > dynamicApplicationManifest.yml

        cat dynamicApplicationManifest.yml $sfile >merge.yml

        #Yaml to Json Conversion
        echo $(ruby -ryaml -rjson -e "puts JSON.pretty_generate(YAML.safe_load(File.read('merge.yml')))") >>data.json
        echo "Getting Prescription"
        prescrip=$(curl -X POST -H 'Content-Type:application/json' -H 'Accept:application/json' -H "${header}" -d @data.json ${url}/stargazer/api/manifest/${API})
        echo $prescrip
        echo $prescrip >result.json
    else
        echo "Invalid Files"
        exit 1
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

ARGS=("$@")

run