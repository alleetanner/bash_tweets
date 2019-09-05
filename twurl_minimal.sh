#!/bin/bash

#      !!TWURL.SH!!   MINIMAL VERSION   #
# Autumn 2018 Al Tanner  #

date=$(date)
printf "\nStarting harvester at $date...\n\n";

# authenticate twurl
twurl authorize --consumer-key XXXX --consumer-secret XXXX;

# take the input list and turn it into ID numbers through Twython
python3 /root/host_interface/run_files_mac/screen_name_2_id_python3.py /root/host_interface/follow_lists/users_to_follow;

# Start mongod, increase open files to 2048 so mongod has headroom, place log files, set db path
ulimit -n 2048; mongod --fork --logpath /root/host_interface/log_files/mongod.log --dbpath /root/host_interface/db;

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
            sleep 901;
        fi
    done
    # if account is private, report it and move on
    if grep -q "\"error\": \"Not authorized.\"" /root/host_interface/jsons/$id_number.json; then
        let "users_with_private_accounts++";
        rm /root/host_interface/jsons/$id_number.json;
        continue;
    fi
    # if user has no tweets, report it and move on
    if [ $(wc -l < /root/host_interface/jsons/$id_number.json) = 1 ]; then
        let "users_with_no_new_tweets++";
        rm /root/host_interface/jsons/$id_number.json;
        continue;
    fi
    let "users_processed++";
done < /root/host_interface/follow_lists/users_to_follow.ids

# index the current MongoDB database to accelerate upsert
/usr/bin/mongo < /root/host_interface/mongo_scripts/createindex.js;

# import all the json files into MongoDB
for json in /root/host_interface/jsons/*.json; do 
    /usr/bin/mongoimport --db dock_db --collection dock_collection --file $json --upsert --upsertFields id_str --jsonArray;
    done;

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
mongod --dbpath /root/host_interface/db --shutdown && printf "MongoDB exited cleanly.\n";
printf "All done!\n\n";