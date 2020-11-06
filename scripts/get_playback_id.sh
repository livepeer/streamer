#!/usr/bin/env bash

api_key=0af5b048-1e54-4100-996b-44508a01c1e1
stream_id=c07f-h02p-lm1f-9g08

curl \
  -H "authorization: Bearer $api_key" \
  -v \
  "https://livepeer.monster/api/stream/$streamId"

rtmp://mdw-rtmp.livepeer.monster/live/74e2-qimo-7aaf-r7kn
https://mdw-cdn.livepeer.monster/hls/74e26vtieb165mn0/index.m3u8
