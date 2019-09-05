#!/bin/bash

# CHANGE FROM PREVIOUS, 18TH OCT: DOCKER IS CALLED "DOCKER CURRENT" OR SOMETHING,
# AND THE CHECK IS LOOKING FOR AN EXACT MATCH. EXACT REMOVED
# Check that a database location and follow list has been provided
if [ $# -lt 2 ]; then 
    printf "Please provide the location of your database, and your list of users to gather from.\n";
    printf "eg: bash twurl_docker_starter.sh ~/Desktop/test_db follow_list.txt.\n";
    exit 1;
fi
if [ ! -d $1 ]; then
    printf "The location \"$1\" does not seem to exist.\n";
    exit 1;
fi
if [ ! -f $2 ]; then
    printf "The list file \"$2\" does not seem to exist here.\n";
    exit 1;
fi


# If mongod is running or docker isn't running locally, stop.
if pgrep -x "mongod" > /dev/null; then
    printf "\nIt looks like MongoDB is currently running here on the host machine.\n";
    printf "Please close the MongoDB process and retry.\n";
    exit 1;
else
    printf "\nNo conflicting MongoDB instances running...\n";
fi
if ! pgrep "docker" > /dev/null; then # match on CentOS: dockerd, MacOS: docker
    printf "\nDocker doesn't appear to be running here on the host machine.\n";
    printf "Please start Docker and retry.\n";
    exit 1;
else
    printf "\nDocker running as expected...\n";
fi

# put things into docker interface folders # PATHS CHANGED!!!!!
cp $2 /Users/at9362/Desktop/docker_interface/follow_lists/users_to_follow;

# run the docker image
date=$(date);
printf "\nStarting the twurl docker container at $date.\n";
docker run -v /Users/at9362/Desktop/docker_interface:/root/host_interface 97b3539762de /bin/bash -c "bash /root/host_interface/run_files_mac/twurl_21nov.sh /root/host_interface/follow_lists/users_to_follow;";

# print the finish time
date=$(date);
printf "\n\nDocker container process finished at $date.\n";

# clean up closed docker container
docker rm $(docker ps -a -q);
