#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color
FAIL=0;

function show_usage {
    echo
    echo "Usage bash build.sh [-s publish_target -u:o:c:n:p:f:] -d policy-source"
    echo
    echo "  -d : MUST BE SET - specifies the source directory to pacakge"
    echo "  -s : Designates an APIC instance to publish the policy to"
    echo "  -u : Sets the username for the APIC publish target"
    echo "  -o : Sets the organisation for the APIC publish target"
    echo "  -c : Sets the catalog for the APIC publish target"
    echo "  -p : Sets the password for the APIC publish target"
    echo "  -n : Specify the name of the policy to delete"
    echo "         Ensure this is set as follows: logtomq:1.0.0 with the correct name and version number."
    echo "  -f : Allows you to override flags with a config file"
    echo "         Ensure this config file is in the pwd or the full path of the config file is given."
    echo "  -h : Shows this text"
    echo
    exit 1
}

function fail_build {
    echo
    echo -e $1, ${RED}BUILD FAILED.${NC}
    echo
    echo "  - Ensure that the working directory is clean before restarting the build"
    echo "    as it is possible that artifacts from the previous build may persist."
    echo
    exit 1
}

function fail_publish {
    FAIL=1;
    echo "FAIL NOW SET TO $FAIL"
    echo
    echo -e $1, ${RED}PUBLISH FAILED.${NC}
    echo
    echo "  - Cleaning up the directory"
    echo
    exit 1
}

while getopts "hs:u:o:c:n:p:f:d:" option
do
    case "${option}" in
        h) HELP=1;;
        s) TARGET=${OPTARG};;
        u) USERNAME=${OPTARG};;
        o) ORG=${OPTARG};;
        c) CAT=${OPTARG};;
        n) POLICYNAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
        f) FILE=${OPTARG};;
        d) SOURCE_DIR=${OPTARG};;
	esac
done

if [[ $HELP -eq 1 ]]; then
    show_usage
fi

if [[ -z $SOURCE_DIR ]]; then
    echo
    echo -e "    ${RED}This script MUST be run with the -d SOURCE_DIRECTORY flag set${NC}"
    echo
fi

START_DIR=$(pwd) # Store the initial directory
OUTPUT_DIR=$(echo $SOURCE_DIR | cut -d "-" -f1) # Cut off the source substring

if [[ -z "$CAT" ]]; then
    CAT="sb"
fi

if [[ -n "$FILE" ]]; then
    echo "Trying to retrieve config from: $FILE..."
    source $FILE $OUTPUT_DIR || fail_build "Failed to retrieve config from: $FILE. Please ensure the path is correct before trying again"
fi

if [[ -z "$TARGET" ]]; then
    echo "  - No publish step specified. If you wish to publish the policy as part of the build please try again,"
    echo "    ensuring that the -s {Server} flag is set."
elif [[ -z "$ORG" ]] || [[ -z "$CAT" ]] || [[ -z "$USERNAME" ]] || [[ -z "$POLICYNAME" ]] || [[ -z $PASSWORD ]]; then
    echo "  - One or more of the key variables for publish is not set. Please try again, ensuring that the following"
    echo "    are set: -o {ORG} -c {CAT} -u {USER} -p {PASSWORD} -n {POLICY_NAME}"
else
    echo "  - PUBLISH set to true"
    PUBLISH=1;
fi

## Trim the trailing slash if necessary
if [[ $SOURCE_DIR == *"/" ]]; then
    STRLEN=${#SOURCE_DIR}
    STRLEN=$((STRLEN-1))
    SOURCE_DIR=$(echo $SOURCE_DIR | cut -c 1-$STRLEN)
fi

if ! [[ $SOURCE_DIR == *"-source" ]]; then
    fail_build "The target directory must end with the substring \"-source\""
fi

## Create the output structure
mkdir $OUTPUT_DIR && cd $OUTPUT_DIR && mkdir implementation && echo "Creating directory: $OUTPUT_DIR..." && \
echo "Creating directory: $OUTPUT_DIR/implementation..." || fail_build "Output directory structure could not be created"

## Copy non directory files into output directory
cd $START_DIR/$SOURCE_DIR/ && \
for i in *; do
    if [[ ! -d $i ]]; then
        echo "Copying file: $i into $START_DIR/$OUTPUT_DIR"
        cp $i $START_DIR/$OUTPUT_DIR
    fi
done || fail_build "Couldn't copy root level files to the output directory"

## Build the implementation zip and transfer into output directory
echo "Creating the implementation zip \"$OUTPUT_DIR-main.zip\"..."
cd $START_DIR/$SOURCE_DIR/implementation && zip -r $OUTPUT_DIR-main.zip * || fail_build "Hit an unexpected problem creating the implementation zip file"
echo "Moving the implementation zip into the output directory"
mv $OUTPUT_DIR-main.zip $START_DIR/$OUTPUT_DIR/implementation || fail_build "An error occured while moving the implementation zip into the output directory"

## Establish that the structure of the directory is correct
cd $START_DIR
echo "Checking the structure of the output directory..."
if [[ -d "$OUTPUT_DIR" ]]; then
    if [[ -d "$OUTPUT_DIR/implementation" ]]; then
        if [[ -e "$OUTPUT_DIR/implementation/$OUTPUT_DIR-main.zip" ]]; then
            if [[ -e "$OUTPUT_DIR/$OUTPUT_DIR.yaml" ]]; then
                echo "Structure is correct"
            else
                fail_build "The folder: $OUTPUT_DIR must contain a definitions file called \"$OUTPUT_DIR.yaml\""
            fi
        else
            fail_build "The implementation subdirectory must contain a zip called \"$OUTPUT_DIR-main.zip\""
        fi
    else
        fail_build "The folder: $OUTPUT_DIR must contain a subdirectory called \"Implementation\""
    fi
else
    fail_build "The folder: $OUTPUT_DIR could not be found"
fi

## Create the import zip in the output directory
echo "Compressing the output directory..."
cd $OUTPUT_DIR && zip -r "$OUTPUT_DIR.zip" * && echo "Successfully created $OUTPUT_DIR.zip" || fail_build "An error occured during compression"
cd $START_DIR
cp $OUTPUT_DIR/"$OUTPUT_DIR.zip" .

if [[ $PUBLISH -eq 1 ]]; then
    echo "Starting publish steps..."
    ## Optionally - publish the policy. MUST set -opusnc for this to work.
    apic login --server $TARGET -u $USERNAME -p $PASSWORD || (fail_publish "Failed to log into Server: $TARGET as User: $USERNAME" && rm $OUTPUT_DIR && rm $OUTPUT_DIR.zip)
    apic policies:delete -c $CAT -o $ORG --server $TARGET $POLICYNAME || echo "Failed to delete the policy $POLICYNAME from Server: $TARGET, Org: $ORG, Catalog: $CAT"
    apic policies:publish -c $CAT -o $ORG --server $TARGET --directory $OUTPUT_DIR || (fail_publish "Failed to publish to Server: $TARGET, Org: $ORG, Catalog: $CAT" && rm -r $OUTPUT_DIR && rm $OUTPUT_DIR.zip)
fi

if [[ $FAIL -eq 0 ]]; then
    echo "Tidying up..."
    rm -r $OUTPUT_DIR
    echo -e "${GREEN}BUILD SUCCESS${NC}, output: $STARTDIR/$OUTPUT_DIR.zip"
else
    echo "Failure."
fi

## Example file content:
# TARGET="192.168.225.100";
# USERNAME="jackdunleavy@uk.ibm.com";
# ORG="jackorg";
# CAT="sb"
# POLICYNAME="logtomq:1.0.0";
# PASSWORD="!n0r1t5@C";
#
# Call this as follows: bash build.sh -f path/to/this.sh policy-source
