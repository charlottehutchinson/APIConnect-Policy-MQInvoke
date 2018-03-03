#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

function fail_build {
    echo  $1, ${RED}BUILD FAILED.${NC}
    exit 11
}

SOURCE_DIR=$1/$2-source
START_DIR=$(pwd) # Store the initial directory
OUTPUT_DIR=$2
OUTPUT_DIRPATH=tmp/${OUTPUT_DIR}
rm -rf $OUTPUT_DIRPATH
echo "Creating directory: $OUTPUT_PATHDIR/implementation..." || fail_build "Output directory structure could not be created"
mkdir -p $START_DIR/$OUTPUT_DIRPATH/implementation

cp $START_DIR/$SOURCE_DIR/${OUTPUT_DIR}.yaml $START_DIR/$OUTPUT_DIRPATH/

## Build the implementation zip and transfer into output directory
echo "Creating the implementation zip \"$OUTPUT_DIR-main.zip\"..."
cd $START_DIR/$SOURCE_DIR/implementation && pwd && echo $OUTPUT_DIRPATH-main.zip && zip -r $START_DIR/$OUTPUT_DIRPATH/implementation/$OUTPUT_DIR-main.zip * || fail_build "Hit an unexpected problem creating the implementation zip file"

echo "Checking the structure of the output directory..."
if [[ ! -d "$START_DIR/$OUTPUT_DIRPATH" ]]; then
  fail_build "The folder: $OUTPUT_DIRPATH could not be found"
fi
if [[ ! -d "$START_DIR/$OUTPUT_DIRPATH/implementation" ]]; then
      fail_build "The folder: $OUTPUT_DIRPATH must contain a subdirectory called \"Implementation\""
fi
if [[ ! -e "$START_DIR/$OUTPUT_DIRPATH/implementation/$OUTPUT_DIR-main.zip" ]]; then
    fail_build "The implementation subdirectory must contain a zip called \"$OUTPUT_DIR-main.zip\""
fi
if [[ ! -e "$START_DIR/$OUTPUT_DIRPATH/$OUTPUT_DIR.yaml" ]]; then
    fail_build "The folder: $OUTPUT_DIRPATH must contain a definitions file called \"$OUTPUT_DIR.yaml\""
fi

## Create the import zip in the output directory
echo "Compressing the output directory..."
cd $START_DIR/$OUTPUT_DIRPATH/ && zip -r "$OUTPUT_DIR.zip" * && echo "Successfully created $OUTPUT_DIR.zip" || fail_build "An error occured during compression"
cd $START_DIR
cp $START_DIR/$OUTPUT_DIRPATH/"$OUTPUT_DIR.zip" out/
echo "${GREEN}BUILD SUCCESS${NC}, output: $STARTDIR/$OUTPUT_DIR.zip"
