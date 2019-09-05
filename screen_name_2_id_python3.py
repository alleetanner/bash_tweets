#################################################################
# screen_name_2_id.py by Al Tanner, August 2018                 #
# Takes a list of Twitter screen names (without the @ symbol)   #
# and converts them into permanent Twitter id codes             #
# (screen names are not permanent and may be changed by users!) #
# USAGE: python screen_name_2_id.py [list of screen names]      #
#################################################################

from twython import Twython
import sys, os

# Request a list file, if not provided.
if len(sys.argv) < 2:
    print("Please provide a list of screen names.")
    print("Use example: python screen_name_2_id.py user_list.txt")
    exit(1)
elif len(sys.argv) > 2:
    print("Please provide a single list of screen names.")
    print("Use example: python screen_name_2_id.py user_list.txt")
    exit(1)

# Exit if list file is not present
if not os.path.isfile(sys.argv[1]):
    print("Problem:", sys.argv[1], "doesn't seem to exist here.")
    exit(1)

# Count the number of screen names in the input file
non_blank_count = 0
with open(sys.argv[1]) as count_file:
    for line in count_file:
        if line.strip():
            non_blank_count += 1

# Make a list from the input file of screen names
screen_names = [line.strip() for line in open(sys.argv[1])] # clean up any whitespace
screen_names = [_f for _f in screen_names if _f]                   # clean up any empty lines

# chunks splits the screen_name list into manageable blocks:
def chunks(l, n):
    for i in range(0, len(l), n):     # For item i in a range that is a length of l,
        yield l[i:i+n]                # Create an index range for l of n items:

#twurl authorize --consumer-key XXXXX --consumer-secret XXXXX

# Put keys and tokens into variables.
#app_key = ''
#app_secret = ''
#twitter = Twython(app_key, app_secret)
app_key = ''
app_secret = ''
twitter = Twython(app_key, app_secret)
# We are not making write requests, so we do not need the following auth codes
#oauth_token = '...-...'
#oauth_token_secret= '...'
# If we needed write access, this Twython function would need oauth codes too:
#twitter = Twython(app_key, app_secret, oauth_token, oauth_token_secret)

# Query twitter with the comma separated list
id_list=[] # empty list for id to go into
for chunk in list(chunks(screen_names, 42)): # split list into manageable chunks of 42
    comma_separated_string = ",".join(chunk) # lookup take a comma-separated list
    output = twitter.lookup_user(screen_name=comma_separated_string) #lookup
    for user in output:
        id_list.append(user["id_str"]) # get the id and put it in the id_list

# Open output file and write user codes to file.
output_filename = sys.argv[1] + '.ids' # name the output file as the input file with ".ids"
out_file = open(output_filename, 'w')  # open outfile
for id in id_list:
    out_file.write("%s\n" % id)        # write to outfile
print("OK,", len(id_list), "of", non_blank_count, "ID numbers written to -->", output_filename, "<--")

# Check that the number of IDs matches the number of screen names provided.
if not len(id_list) == non_blank_count:
    print("Warning: some screen names did not return ID codes.")
