#!/bin/bash
docker run -v "$PWD:/script" -v "$1:/data"  -v "$PWD/../src:/brats_repo" -u $UID:$UID -it --rm "darchr/3dunet" /bin/bash /script/script.sh
