#!/bin/sh

while [[ $# -gt 0 ]]; do
  case $1 in
      --to|-t)    TO="$2"; shift 2 ;;
      --from|-f)  FROM="$2"; shift 2 ;;
      --text|-q)  TEXT="$2"; shift 2 ;;
      --key|-k)   KEY="$2"; shift 2 ;;
      --appid|-i) APPID="$2"; shift 2 ;;
      *)           ; exit 1 ;;
  esac
done

curl -s -X POST "https://fanyi-api.baidu.com/ait/api/aiTextTranslate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d "{\"appid\":\"$APPID\",\"from\":\"$FROM\",\"to\":\"$TO\",\"q\":\"$TEXT\"}"
