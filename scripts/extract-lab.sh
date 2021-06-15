#!/usr/bin/env bash -le
sed -n "/## Lab $1/,/## Lab $(($1+1))/p"