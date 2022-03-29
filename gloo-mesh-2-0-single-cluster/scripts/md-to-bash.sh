#!/usr/bin/env bash
echo "source /root/.env || true"
sed -n '/```bash/,/```/p; /<!--bash/,/-->/p' | egrep -v '```|<!--bash|-->' | sed '/#IGNORE_ME/d'
