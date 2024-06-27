#!/usr/bin/env bash

echo "#!/usr/bin/env bash"
echo "source /root/.env 2>/dev/null || true"
sed -n '/```bash/,/```/p; /<!--bash/,/-->/p' | egrep -v '```|<!--bash|-->' | sed '/#IGNORE_ME/d'
