#!/bin/bash

username=$1
password=$2 
dxEngineAddress=$3 
major=$4
minor=$5
micro=$6

curl -s -X POST -k --data @- http://${dxEngineAddress}/resources/json/delphix/session \
   -c "cookies.txt" -H "Content-Type: application/json" <<EOF
{
   "type": "APISession",
   "version": {
       "type": "APIVersion",
       "major": ${major},
       "minor": ${minor},
       "micro": ${micro}
  }
}
EOF

curl -s -X POST -k --data @- http://${dxEngineAddress}/resources/json/delphix/login \
-b "cookies.txt" -c "cookies.txt" -H "Content-Type: application/json" <<EOF
{
"type": "LoginRequest",
"username": "${username}",
"password": "${password}"
}
EOF