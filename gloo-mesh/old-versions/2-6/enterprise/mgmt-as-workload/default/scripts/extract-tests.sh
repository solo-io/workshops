#!/usr/bin/env bash

sed -n '/cat.*test\.js$/,/executing test.*$/p' | grep -v "EOF" | grep -v "executing test"| awk '!/require/ || NR==1'
