#! /bin/bash

DIR_NAME="$(dirname $0)"
JAR_FILE="$DIR_NAME/swamp-cli-jar-with-dependencies.jar"

[[ ! -f  "$JAR_FILE" ]] && echo "File not found: $JAR_FILE" && exit 1

java -jar "$JAR_FILE" "$@"

