#!/bin/bash

# A sample script for calls to the API. This one creates a Jet Stream container.

##### Constants

# Describes a Delphix software revision.
# Please change version are per your Delphix Engine CLI, if different
VERSION="1.11.14"


##### Default Values. These can be overwriten with optional arguments.
engine="10.44.1.160"
username="admin"
password="fwdview01!"

##examples##
# Create container from latest point in time
#./createContainer.sh -n "testsource" testcont ORACLE_DB_CONTAINER-269 JS_DATA_TEMPLATE-13
# Create container from specific bookmark
#./createContainer.sh -n "testsource" -b JS_BOOKMARK-77 testcont ORACLE_DB_CONTAINER-269 JS_DATA_TEMPLATE-13
# Create container from specific point in time
#./createContainer.sh -n "testsource" -t "2016-08-08T10:00:00.000Z" -B JS_BRANCH-50 testcont ORACLE_DB_CONTAINER-269 JS_DATA_TEMPLATE-13

#NOTE: this script will add one container and assign one owner for the container.

##### Functions

# Help Menu
function usage {
	echo "Usage: createContainer.sh [[-h] | options...] <containername> <vdb> <template>"
	echo "Create a Jet Stream Bookmark on the given branch."
	echo ""
	echo "Positional arguments"
	echo "  <name>"
	echo "  <container> format JS_DATA_CONTAINER-<n>"
	echo ""
	echo "Optional Arguments:"
	echo "  -h                Show this message and exit"
	echo "  -d                Delphix engine IP address or host name, otherwise revert to default"
	echo "  -u USER:PASSWORD  Server user and password, otherwise revert to default"
    echo "  -n                SourceName need to display for container.(Mandatory)"
	echo "  -b                Bookmark name from which need to create container. If no bookmark is included, the branch will be created at the latest point in time. Type: string. Format JS_BOOKMARK-<n> (Optional)"
	echo "  -t                The time at which the branch should be created. This must be accompanied with branch name from which need to pick up time. Type: date, must be in ISO 8601 extended format [yyyy]-[MM]-[dd]T[HH]:[mm]:[ss].[SSS]Z"
    echo "  -B                Branch name from which need to create new container, at specific time. Type: string. Format JS_BRANCH-<n> (Optional)"
    echo "  -N                Optional container notes, if need to add any. Type: String"
    echo "  -o                Optional owner, to whom we need to assign this container. Type: String. Format USER-<n>"
}

# Create Our Session, including establishing the API version.
function create_session
{
	# Pulling the version into parts. The {} are necessary for string manipulation.
	# Strip out longest match following "."  This leaves only the major version.
	major=${VERSION%%.*}
	# Strip out the shortest match preceding "." This leaves minor.micro.
	minorMicro=${VERSION#*.}
	# Strip out the shortest match followint "." This leaves the minor version.
	minor=${minorMicro%.*}
	# Strip out the longest match preceding "." This leaves the micro version.
	micro=${VERSION##*.}

	# Quick note about the <<-. If the redirection operator << is followed by a - (dash), all leading TAB from the document data will be 
	# ignored. This is useful to have optical nice code also when using here-documents. Otherwise you must have the EOF be on a line by itself, 
	# no parens, no tabs or anything.

	echo "creating session..."
	result=$(curl -s -S -X POST -k --data @- http://${engine}/resources/json/delphix/session \
		-c ~/cookies.txt -H "Content-Type: application/json" <<-EOF
	{
		"type": "APISession",
		"version": {
			"type": "APIVersion",
			"major": $major,
			"minor": $minor,
			"micro": $micro
		}
	}
	EOF)

	check_result
}

# Authenticate the DE for the provided user.
function authenticate_de
{
	echo "authenticating delphix engine..."
	result=$(curl -s -S -X POST -k --data @- http://${engine}/resources/json/delphix/login \
		-b ~/cookies.txt -c ~/cookies.txt -H "Content-Type: application/json" <<-EOF
	{
		"type": "LoginRequest",
		"username": "${username}",
		"password": "${password}"
	}
	EOF)	

	check_result
}

function create_container
{

	# If there is not timeInput and no bookmark name, we need to use JSTimelinePointLatestTimeInput.
	if [[ -z $inputTime  &&  -z $bookmark ]]
	then
		pointParams="\"timelinePointParameters\":{
			\"sourceDataLayout\": \"${template}\",
			\"type\":\"JSTimelinePointLatestTimeInput\"}"

   # If there is a timeInput and no bookmark name, we need to use Input Time.

	elif [[ -n $inputTime  && -n $branchRef && -z $bookmark ]]
	 then
		pointParams="\"timelinePointParameters\":{
			\"time\":\"${inputTime}\",
			\"branch\":\"${branchRef}\",
			\"type\":\"JSTimelinePointTimeInput\"}"

   # If there is a bookmark name and no time input, we need to use bookmark

   elif [[ -z $inputTime  &&  -n $bookmark ]]
   then
        pointParams="\"timelinePointParameters\":{
        \"bookmark\":\"${bookmark}\",
        \"type\":\"JSTimelinePointBookmarkInput\"}"

	fi
	
	# These are the required parameters.
	
	paramString="\"type\": \"JSDataContainerCreateWithRefreshParameters\",
                 \"name\": \"${containerName}\",
                 \"template\": \"${template}\","

	
	paramString="$paramString \"dataSources\": [{\"type\": \"JSDataSourceCreateParameters\",
                \"container\": \"${VDB}\",
                \"source\": {
                \"type\": \"JSDataSource\",
                \"priority\": 1,
                \"name\": \"${sourceName}\""
    
    if [[ -n $sourcedesc ]]
    then
       paramString="$paramString ,\"description\": \"${sourcedesc}\"}}],"  
    else 
       paramString="$paramString }}],"
   fi
   
    if [[ -n $containerNotes ]]
    then
       paramString="$paramString \"notes\": \"${containerNotes}\","
   fi
   
   if [[ -n $owners ]]
   then
      paramString="$paramString \"owners\": [\"${owners}\"],"
   fi
    
    paramString="$paramString ${pointParams}"
	    

	result=$(curl -s -X POST -k --data @- http://${engine}/resources/json/delphix/jetstream/container \
	    -b ~/cookies.txt -H "Content-Type: application/json" <<-EOF
	{
	    $paramString
	}
	EOF)


	check_result

	
	echo "confirming job completed successfully..."
	# Get everything in the result that comes after job.
    temp=${result#*\"job\":\"}
    # Get rid of everything after
    jobRef=${temp%%\"*}


    result=$(curl -s -X GET -k http://${engine}/resources/json/delphix/job/${jobRef} \
    -b ~/cookies.txt -H "Content-Type: application/json")

    # Get everything in the result that comes after job.
    temp=${result#*\"jobState\":\"}
    # Get rid of everything after
    jobState=${temp%%\"*}


    check_result

    while [ $jobState = "RUNNING" ]
    do
    	sleep 1
    	result=$(curl -s -X GET -k http://${engine}/resources/json/delphix/job/${jobRef} \
	    -b ~/cookies.txt -H "Content-Type: application/json")

	    # Get everything in the result that comes after job.
	    temp=${result#*\"jobState\":\"}
	    # Get rid of everything after
	    jobState=${temp%%\"*}

	    check_result

    done

    if [ $jobState = "COMPLETED" ]
	then
		echo "successfully created container $containerName"
	else
		echo "unable to create container"
		echo result
	fi

}

# Check the result of the curl. If there are problems, inform the user then exit.
function check_result
{
	exitStatus=$?
	if [ $exitStatus -ne 0 ]
	then
	    echo "command failed with exit status $exitStatus"
	    exit 1
	elif [[ $result != *"OKResult"* ]]
	then
		echo ""
		echo $result
		exit 1
	fi
}

##### Main

while getopts "u:d:b:t:B:D:n:N:o:h" flag; do
	case "$flag" in
    	u )             username=${OPTARG%:*}
						password=${OPTARG##*:}
						;;
		d )             engine=$OPTARG
						;;
		b )             bookmark=$OPTARG
						;;
		t )             inputTime=$OPTARG
						;;
        B )             branchRef=$OPTARG
                        ;;
        D )             sourcedesc=$OPTARG
                        ;; 
        n )             sourceName=$OPTARG
                        ;;  
        N )             containerNotes=$OPTARG
                        ;;                 
        o )             owners=$OPTARG
                        ;;                              
		h )             usage
						exit
						;;
		* )             usage
						exit 1
	esac

done


# Shift the parameters so we only have the positional arguments left
shift $((OPTIND-1))

# Check that there are 3 positional arguments
if [ $# != 3 ]
then
	usage
	exit 1
fi

# Get the three positional arguments
containerName=$1
shift
VDB=$1
shift
template=$1

create_session
authenticate_de
create_container
