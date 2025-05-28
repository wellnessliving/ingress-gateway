#!/bin/bash
#
find . -maxdepth 1 -type f | xargs -I F sed -i -r 's/[[:space:]]*$//g' F
