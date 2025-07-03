#!/usr/bin/env bash

echo "#!/usr/bin/env bash"
echo "source /root/.env 2>/dev/null || true"
sed '/cat.*test\.js$/,/The workshop failed.*$/d'