This shell script takes a directory path as input and renames all files inside that directory (including subdirectories) by replacing each filename with the SHA256 hash of its file content.

If two files have the same content (i.e., same hash), the script deletes the existing one and renames the current file to that hash.

usage : ./file_name_to_hash.sh <path>