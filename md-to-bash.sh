sed -n '/```bash/,/```/p; /<!--bash/,/-->/p' | egrep -v '```|<!--bash|-->'
