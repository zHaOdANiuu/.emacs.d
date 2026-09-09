#!/bin/sh

exec args.sh

curl -s -X POST "https://fanyi-api.baidu.com/ait/api/aiTextTranslate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d "{\"appid\":\"$APPID\",\"from\":\"$FROM\",\"to\":\"$TO\",\"q\":\"$TEXT\"}"
