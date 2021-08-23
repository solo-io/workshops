#!/usr/bin/env bash

sed -n '/```bash/,/```/p; /<!--bash/,/-->/p' | egrep -v '```|<!--bash|-->' | sed '/#IGNORE_ME/d'
