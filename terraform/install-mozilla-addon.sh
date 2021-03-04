#!/bin/sh
# -------------------------------------------------------
#  Command line script to install 
#  Firefox and Thunderbird add-ons
#  as global extensions available to all users
#
#  Must be run with sudo
#  Depends on unzip and wget
#  Parameters :
#    $1 = URL of extension on https://addons.mozilla.org/
# 
#  26/03/2013, V1.0 - Creation by N. Bernaerts
# -------------------------------------------------------


# -------------------  parameters  ----------------------

# set default add-ons URL base
URL_FIREFOX="https://addons.mozilla.org/firefox/"
URL_THUNDER="https://addons.mozilla.org/thunderbird/"

# set global extensions installation path
# you may have to adapt it to your environment
PATH_FIREFOX="/usr/lib/firefox-addons/extensions"
PATH_THUNDER="/usr/lib/thunderbird-addons/extensions"

# ------------------  Script  --------------------------

# determine if we are dealing with firefox or thunderbird extension
EXT_FIREFOX=`echo "$1" | grep "$URL_FIREFOX"`
EXT_THUNDER=`echo "$1" | grep "$URL_THUNDER"`

# setup global extension path accordingly
if [ "$EXT_FIREFOX" != "" ]; then PATH_EXTENSION=$PATH_FIREFOX
elif [ "$EXT_THUNDER" != "" ]; then PATH_EXTENSION=$PATH_THUNDER
else PATH_EXTENSION=""
fi

# if add-on is recognised, install it
if [ "$PATH_EXTENSION" != "" ]
then
  # download extension
  wget -O addon.xpi "$1"

  # get extension UID from install.rdf
  UID_ADDON=`unzip -p addon.xpi install.rdf | grep "<em:id>" | head -n 1 | sed 's/^.*>\(.*\)<.*$/\1/g'`

  # move extension to default installation path
  unzip addon.xpi -d "$PATH_EXTENSION/$UID_ADDON"
  rm addon.xpi

  # set root ownership
  chown -R root:root "$PATH_EXTENSION/$UID_ADDON"
  chmod -R a+rX "$PATH_EXTENSION/$UID_ADDON"

  # end message
  echo "Add-on added under $PATH_EXTENSION/$UID_ADDON"
fi