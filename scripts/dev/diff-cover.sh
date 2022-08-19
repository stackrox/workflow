#!/bin/bash

Help()
{
   # Display Help
   echo "Syntax: diff-cover.sh [-h|s|t]"
   echo "options:"
   echo "h     Print this Help."
   echo "s     Run on staged changes."
   echo "t     Configure go build tags."
   echo
}

TEST_TAGS=
STAGED=
while getopts ":ht:s" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      s) # Run on staged
         STAGED=--staged;;
      t) # Build tags
         TEST_TAGS=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

# check go path
[[ -n "$GOPATH" ]] || {
    echo "GOPATH not set" >&2
    exit 1
}

# check that we're in roxdir
ROXDIR=$GOPATH/src/github.com/stackrox/stackrox
[[ $PWD == $ROXDIR* ]] || {
    printf "not inside stackrox repo, please run the following:\n\r# cd $ROXDIR\n\r" >&2
    exit 1
}

# define our files
COVERAGE_OUT_FILE=$ROXDIR/cover.out
FILTERED_OUT_FILE=$ROXDIR/cover-filtered.out

# check the diff
DIFF_FILES=$(git diff $STAGED --name-only --no-relative -- '*.go' | xargs | tr ' ' '|')
[[ -n "$DIFF_FILES" ]] || {
    echo "No changes found, check git diff or try with staged flag"
    exit 1
}
DIFF_DIRS=$(git diff $STAGED --name-only --line-prefix=$ROXDIR/ --no-relative -- '*.go' | xargs dirname | sort | uniq)

# run coverage
go test -coverprofile $COVERAGE_OUT_FILE $DIFF_DIRS --tags=$TEST_TAGS

# create filtered output
echo "mode: set" > $FILTERED_OUT_FILE
egrep $DIFF_FILES $COVERAGE_OUT_FILE >> $FILTERED_OUT_FILE

# clean up
rm $COVERAGE_OUT_FILE

# open our results
go tool cover -html $FILTERED_OUT_FILE

