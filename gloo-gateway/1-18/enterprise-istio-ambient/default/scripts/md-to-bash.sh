#!/usr/bin/env bash

echo "#!/usr/bin/env bash"
echo "source /root/.env 2>/dev/null || true"
# First, filter out code blocks with norun-workshop
sed '/```bash.*norun-workshop/,/```/d' |
# Then extract the remaining bash code blocks and HTML comments
sed -n '/```bash/,/```/p; /<!--bash/,/-->/p' |
# Remove the markdown and HTML markers
egrep -v '```|<!--bash|-->' |
# Remove any lines with the IGNORE_ME comment
sed '/#IGNORE_ME/d'