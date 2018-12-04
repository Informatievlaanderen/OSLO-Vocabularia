#!/bin/bash

PUBCONFIG=$2
ROOTDIR=$1

# some test calls
#jq -r '.[] | @sh "echo \(.urlref)"' publication.config | bash -e
#jq -r '.[] | @sh "./checkout-one.sh \(.)"' publication.config | bash -e

# 
# create the directory layout which allows the ea-to-rdf & the
# specgenerator to do there work:
# * src/DIR: the git repository which contains the source
# * target/DIR: the generated artificats that will be committed for publication
# * report/DIR: a directory with all intermediate and log reports to
#               understand the execution trace.  Will also be
#               committed to github, but on a separate directory so
#               that it will not be served by the proxy * the
#               implementation of the see-also rules

# use of json config files is supported by the jq tool, which is per
# default available in the circleci dockers.

# the data that is used to create the directory setup should be
# integrated with the data in the cloned repository the reason for
# this is that some data such as the navigation trail is part of the
# publication section and not of the local repository

# performance consideration: the checkout & build times might increase
# rapidely as there are many publication points to handle we coudl
# consider to create a docker with the to-be-generated situation in a
# previous state and start form that one.  The build of a new docker
# should than be done on regular time (not on every commit) e.g. 1 /
# month. And then the publication would only chekcout additonal
# publicationpoints for that month. That would reduce the runtime
# drastically.

# Cleanup root (just in case)
rm -rf $ROOTDIR/*.txt

if [ ! -f "${PUBCONFIG}" ] ; then
    echo  "file doesn't exist - ${PUBCONFIG}"
    exit -1
fi

# Process the publications.config file
if cat ${PUBCONFIG} | jq -e . > /dev/null 2>&1
then
    # only iterate over those that have a repository
    for row in $(jq -r '.[] | select(.repository)  | @base64 ' ${PUBCONFIG}) ; do
	_jq() {
	    echo ${row} | base64 --decode | jq -r ${1}
	}
	
	echo "start processing (repository): $(_jq '.repository') $(_jq '.urlref')"

	DIR=$(_jq '.urlref')
	NAME=$(_jq '.name')
	
	RDIR=${DIR#'/'}
	mkdir -p $ROOTDIR/src/$RDIR
	mkdir -p $ROOTDIR/target/$RDIR
	git clone --depth=1 $(_jq '.repository') $ROOTDIR/src/$RDIR

	pushd $ROOTDIR/src/$RDIR
    	   git checkout $(_jq '.branchtag')

	   # Save the Name points to be processed
	   if [ ! -z "$NAME" -and "$NAME" != "null" ]
	   then
	       echo "check name $NAME is present"
               echo "$NAME" >> .names.txt
	   fi
        popd
	echo "$ROOTDIR/src/$RDIR" >> $ROOTDIR/checkouts.txt
    done

    for row in $(jq -r '.[] | select(.seealso)  | @base64 ' ${PUBCONFIG}) ;
    do
	echo "link $(_jq '.urlref') $(_jq '.seealso')" >> $ROOTDIR/links.txt
    done
else
    echo "problem in processing ${PUBCONFIG}"
fi
