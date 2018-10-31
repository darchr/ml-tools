#!/bin/bash

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback

USER_ID=${LOCAL_USER_ID:-9001}

echo "Starting with UID : $USER_ID"
useradd --shell /bin/bash -u $USER_ID -o -c "" -m user
export HOME=/home/user

# If we have to map a volume (such as a dataset) into the "user" home directory, it will
# be owned by root. Doing this ensures that even if we do that, the directory /home/user
# will be owned, and thus accessible, by the "user".
chown -R user /home/user

exec /usr/local/bin/gosu user "$@"
