#!/bin/bash

#      !!TWURL.SH!!      #
# Autumn 2018 Al Tanner  #

red='\033[0;31m';
colour2='\033[0;35m';
white='\033[0m';
date=$(date)
printf "\nStarting harvester at $date...\n\n";

# authenticate twurl
twurl authorize --consumer-key XXXX --consumer-secret XXXX;

# take the input list and turn it into ID numbers through Twython
printf "${colour2}Converting usernames in follow list to persistent ID numbers...\n${white}";
python3 /root/host_interface/run_files_mac/screen_name_2_id_python3.py /root/host_interface/follow_lists/users_to_follow;

# count number of users given, number of ids returned, and difference
users_in_input_file=`cat /root/host_interface/follow_lists/users_to_follow | sed '/^\s*$/d' | wc -l | awk '{print $1}'`;
users_with_returned_ids=`wc -l /root/host_interface/follow_lists/users_to_follow.ids | awk '{print $1}'`;
missing_users=$((users_in_input_file-users_with_returned_ids));

# Start mongod, increase open files to 2048 so mongod has headroom, place log files, set db path
printf "${colour2}\nStarting the MongoDB daemon...\n${white}";
ulimit -n 2048; mongod --fork --logpath /root/host_interface/log_files/mongod.log --dbpath /root/host_interface/db;

# set up some variables
users_processed=0;
times_rate_limited=0;
users_with_private_accounts=0;
users_with_no_new_tweets=0;

# loop, take each user and acquire timeline for each
printf "${colour2}\nTalking to Twitter through twurl...\n${white}";
while read id_number; do
    rate_limited=0;
    while [[ $rate_limited -eq 0 ]]; do
        printf "Getting timeline for user $id_number...\n";
        /usr/local/bin/twurl GET -H api.twitter.com "/1.1/statuses/user_timeline.json?id=$id_number&count=200&exclude_replies=true&include_rts=false&tweet_mode=extended" | /usr/bin/jq . > /root/host_interface/jsons/$id_number.json;
        rate_limited=1;
        # if rate limited, wait 15 minutes for cooldown to expire and try again
        if grep -q "\"message\": \"Rate limit exceeded\"" /root/host_interface/jsons/$id_number.json; then
            rate_limited=0;
            rm /root/host_interface/jsons/$id_number.json;
            let "times_rate_limited++";
            echo -e "${red}Twitter has rate-limited these requests...${white}";
            echo -e "${red}Waiting 15 minutes for rate-limit cooldown...${white}";
            sleep 901;
        fi
    done
    # if account is private, report it and move on
    if grep -q "\"error\": \"Not authorized.\"" /root/host_interface/jsons/$id_number.json; then
        echo -e "${red}User $id_number has a private account; no records recovered.${white}";
        let "users_with_private_accounts++";
        rm /root/host_interface/jsons/$id_number.json;
        continue;
    fi
    # if user has no tweets, report it and move on
    if [ $(wc -l < /root/host_interface/jsons/$id_number.json) = 1 ]; then
        echo -e "${red}User $id_number has no tweets on their timeline; no records recovered.${white}";
        let "users_with_no_new_tweets++";
        rm /root/host_interface/jsons/$id_number.json;
        continue;
    fi
    let "users_processed++";
done < /root/host_interface/follow_lists/users_to_follow.ids

# index the current MongoDB database to accelerate upsert
printf "${colour2}\nIndexing up MongoDB ready for upserts...\n${white}";
/usr/bin/mongo < /root/host_interface/mongo_scripts/createindex.js;

# import all the json files into MongoDB
printf "${colour2}\nImporting tweets...${white}";
for json in /root/host_interface/jsons/*.json; do 
    printf "\nImporting $json into MongoDB\n";
    /usr/bin/mongoimport --db dock_db --collection dock_collection --file $json --upsert --upsertFields id_str --jsonArray;
    # inserting like this will create duplicates:
#    /usr/bin/mongoimport --db dock_db --collection dock_collection --file $json --jsonArray;
    done;

# closing remarks
printf "\n=====\n";
printf "OK, Twitter posts from $users_processed of $users_in_input_file users now stored in MongoDB.\n"
printf "$users_with_private_accounts users have private accounts.\n"; 
printf "$users_with_no_new_tweets users have not tweeted recently.\n";
printf "$missing_users users were not returned as having accounts by Twitter.\n";
printf "This search was rate limited by Twitter $times_rate_limited times.\n";
today=`date '+%d_%m_%Y_%H-%M'`;
#put the number of times limited into a twurl log file
echo $times_rate_limited > /root/host_interface/twurl_logs/$today

# write csv file, mongodump backup, and json backup
mongoexport --host localhost --db dock_db --collection dock_collection --type=csv --out /root/host_interface/BACKUPS/csv/$today.csv --fields user.id_str,id_str,created_at,full_text && printf "Comma Separated Value file written... ok.\n";
mongodump -o /root/host_interface/BACKUPS/mongodump/ && printf "Making a mongodump backup... ok.\n";
zip -q /root/host_interface/BACKUPS/json/jsons_$today /root/jsons/*.json && printf "Making a json backup... ok.\n";
date=$(date);
printf "Harvest and backup finished at $date.\n=====\n\n"

# close the container-side MongoDB daemon
printf "${colour2}Closing the MongoDB daemon...\n${white}";
mongod --dbpath /root/host_interface/db --shutdown && printf "MongoDB exited cleanly.\n";
printf "All done!\n\n";
