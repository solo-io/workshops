rm first second
while true; do
  mv second first
  test=$?
  curl http://localhost:9091/snapshots/output | node translator.js > second
  if [ $test -eq 0 ] 
  then
    node compare.js first second
  fi
  sleep 2
done
