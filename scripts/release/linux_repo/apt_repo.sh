#!/bin/bash

# this is just a helper script; rather than running each script separately just use this
#
# prereq - need aptly, wget and s3cmd installed
#        - also need s3cmd --configure run for the user that is running this script

edition=$1
upload=$2

function help() {
    cat <<HELP_STRING
    Usage:
        ./apt_repo.sh <edition> <upload>

        <edition> - 'enterprise' or 'community'
        <upload>  - 'yes' or 'no' as whether to upload to S3

HELP_STRING
}

if ! hash aptly 2>/dev/null; then
    echo "aptly is not installed"
    exit 1
fi

if ! hash wget 2>/dev/null; then
    echo "wget is not installed"
    exit 1
fi

if ! hash s3cmd 2>/dev/null; then
    echo "s3cmd is not installed"
    exit 1
fi

if [ ! -e ~/.s3cfg ]; then
    echo "s3cmd is not configured. Please run s3cmd --configure first"
    exit 1
fi

if [ "$edition" != "enterprise" -a "$edition" != "community" ]; then
    echo "unknown edition"
    help
    exit 1
fi

gpgkeys='79CF7903 CD406E62 D9223EDA'
for key in $gpgkeys; do
    gpg --list-secret-key $key > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Key $key not installed"
        exit 1
    fi
done

./prep_deb.sh
./seed_deb.sh $edition
for release in `grep $edition versions.txt`
do
    if [[ "$release" != "$edition" ]]
    then
        echo "@@@@@@ PROCESSING $release @@@@@@"
        ./import_deb.sh $release $edition
    fi
done
./publish_deb.sh $edition
if [ "$upload" == "yes" ]; then
    ./upload_deb.sh $edition --init
    ./upload_meta.sh --init
else
    ./upload_deb.sh $edition --update
    ./upload_meta.sh --update
fi
