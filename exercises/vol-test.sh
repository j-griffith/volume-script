#!/usr/bin/env bash

# **volumes.sh**

# Test nova volumes with the nova command from python-novaclient

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration
source $TOP_DIR/openrc

# Import exercise configuration
source $TOP_DIR/exerciserc

# If cinder or n-vol are not enabled we exit with exitcode 55 which mean
# exercise is skipped.
is_service_enabled cinder n-vol || exit 55

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Boot this image, use first AMi image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Security group name
SECGROUP=${SECGROUP:-vol_secgroup}


# Volumes
# -------

VOL_NAME="myvol-$(openssl rand -hex 4)"

# Verify it doesn't exist
if [[ -n "`nova volume-list | grep $VOL_NAME | head -1 | get_field 2`" ]]; then
    echo "Volume $VOL_NAME already exists"
    exit 1
fi

# Create a new volume
nova volume-create --display_name $VOL_NAME --display_description "test volume: $VOL_NAME" 2
if [[ $? != 0 ]]; then
    echo "Failure creating volume $VOL_NAME"
    exit 1
fi

start_time=`date +%s`
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not created"
    exit 1
fi
end_time=`date +%s`
echo "Completed volume-create in $((end_time - start_time)) seconds"

# Get volume ID
VOL_ID=`nova volume-list | grep $VOL_NAME | head -1 | get_field 1`
die_if_not_set VOL_ID "Failure retrieving volume ID for $VOL_NAME"

# Create a snapshot
SNAP_NAME="snap"
nova volume-snapshot-create --display_name $SNAP_NAME --display_description "test snapshot: $SNAP_NAME" $VOL_ID
if [[ $? != 0 ]]; then
    echo "Failure creating snapshot $SNAP_NAME"
    exit 1
fi

start_time=`date +%s`
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-snapshot-list | grep $SNAP_NAME | grep available; do sleep 1; done"; then
    echo "Snapshot $SNAP_NAME not created"
    exit 1
fi
end_time=`date +%s`
echo "Completed snapshot-create in $((end_time - start_time)) seconds"

# Get snapshot ID
SNAP_ID=`nova volume-snapshot-list | grep $SNAP_NAME | head -1 | get_field 1`
die_if_not_set SNAP_ID "Failure retrieving Snapshot ID for $SNAP_NAME"

# Delete snapshot
start_time=`date +%s`
nova volume-snapshot-delete $SNAP_ID || die "Failure deleting snapshot $SNAP_NAME"
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-snapshot-list | grep $SNAP_NAME; do sleep 1; done"; then
    echo "Snapshot $SNAP_NAME not deleted"
    exit 1
fi
end_time=`date +%s`
echo "Issued snapshot-delete in $((end_time - start_time)) seconds"

start_time=`date +%s`
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-snapshot-list | grep $SNAP_NAME; do sleep 1; done"; then
    echo "Snapshot $SNAP_NAME not deleted"
    exit 1
fi
end_time=`date +%s`
echo "Completed snapshot-create in $((end_time - start_time)) seconds"

# Delete volume
start_time=`date +%s`
nova volume-delete $VOL_ID || die "Failure deleting volume $VOL_NAME"
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME; do sleep 1; done"; then
    echo "Volume $VOL_NAME not deleted"
    exit 1
fi
end_time=`date +%s`
echo "Completed volume-delete in $((end_time - start_time)) seconds"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End volume test: $0"
echo "*********************************************************************"
