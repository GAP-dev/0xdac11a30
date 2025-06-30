#!/bin/bash

# 사용법: ./hash_rename.sh /path/to/directory

# 인자 확인
if [ -z "$1" ]; then
  echo "사용법: $0 <디렉토리 경로>"
  exit 1
fi

TARGET_DIR="$1"

# 디렉토리 존재 확인
if [ ! -d "$TARGET_DIR" ]; then
  echo "오류: 디렉토리가 존재하지 않습니다: $TARGET_DIR"
  exit 1
fi

# 모든 일반 파일 처리
find "$TARGET_DIR" -type f | while read -r FILE; do
  # 파일 해시 계산
  HASH=$(sha256sum "$FILE" | awk '{print $1}')
  DIRNAME=$(dirname "$FILE")
  NEW_PATH="$DIRNAME/$HASH"

  # 현재 경로와 새 경로가 다를 때만 처리
  if [ "$FILE" != "$NEW_PATH" ]; then
    # 충돌 파일이 있다면 삭제
    if [ -e "$NEW_PATH" ]; then
      echo "기존 파일 삭제: $NEW_PATH"
      rm -f "$NEW_PATH"
    fi
    mv "$FILE" "$NEW_PATH"
    echo "변경됨: $FILE -> $NEW_PATH"
  fi
done