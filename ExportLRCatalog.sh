#!/bin/bash

# ExportLRCatalog.sh
# Copyright (ɔ) 2018 Apfelkraut.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# SUMMARY
# Bash Script that will exports all collections of an Adobe Lightroom (LR)
# catalog to filesystem

# LIMITATION
# see ./README.md

# USAGE
# see ./README.md

# DOCUMENTATION
# see ./README.md

# LICENSE
# see ./LICENSE

# CREDITS
# see ./README.md

########## CONFIGURATION (START) ##########

# Dry run to change nothing and just log actions
DRYRUN=true

# Single directory per collection that includes all parent collection groups or
# create (sub)directory structure following the collection's hierachy
FLATEXPORT=false

# Seperator to be used when multiple collection (group) names are combined to
# a single directory name during export. Otherwise being ignored.
COLLECTIONHIERACHYSEP=" - "

# Path to the LR catalog
CATALOG="$HOME/Pictures/Lightroom/Lightroom Catalog.lrcat"
LOCK_FILE="$CATALOG.lock"

# Directory where the LR catalog usually expects the files (without trailing slash)
IMPORTDIR="$HOME/Pictures"

# Directory where the files shall be exported  (without trailing slash)
EXPORTDIR="$HOME/Downloads/LR_Export"

# Debug log file
DEBUGLOGFILE=$EXPORTDIR/ExportLRCollections_debug.log

# Error log file
ERRORLOGFILE=$EXPORTDIR/ExportLRCollections_stderr.log

########## CONFIGURATION (END) ##########


# Pass all global variables also to child processes
export DRYRUN
export CATALOG
export LOCK_FILE
export IMPORTDIR
export EXPORTDIR
export DEBUGLOGFILE
export ERRORLOGFILE
export FLATEXPORT
export COLHIERACHYSEP

# Write a dedicated error log
exec 2>$ERRORLOGFILE

# Immediately stop in case of error
# set -e

# FIXME check if LR catalog can be found
# FIXME check if export directory is writable

# Check if LR application is open and locking the catalog
if [ -f "$LOCK_FILE" ];
then
  echo "Catalog appears to be locked. Please quit Lightroom before running this script."
  exit 1
fi

# Now let's really start
startCatMsg="$(date +%Y-%m-%d' '%H:%M:%S) [START] Starting exporting all collections of LR catalog <$CATALOG> ..."
echo $startCatMsg
echo $startCatMsg > $DEBUGLOGFILE
echo $startCatMsg > $ERRORLOGFILE

# Catalog Statistics
# FIXME display number of collections to be exported
# FIXME display number of images per collection are exported
# FIXME display duplication rate of catalog (images files per collection vs total image files)
# FIXME display number of images that are not part of a collection

#
# Input         $1      a string
# Return                the string, trimmed
#
function trim
{
  echo "$1" | sed 's/^ *//' | sed 's/ *$//'
}

#
# Input         $1      a SQL query
# Return                the result of the query separated by spaces
#
function query
{
  trim "`sqlite3 "$CATALOG" "$1" | tr '\n' ' '`"
}

#
# Input         $1      the id of a collection
# Return                the name of the collection
#
function getCollectionName
{
  query "SELECT name FROM AgLibraryCollection WHERE AgLibraryCollection.id_local = $1;"
}

#
# Input         $1      the id of a collection
# Return                the type of the collection
#
function getCollectionType
{
  query "SELECT creationId FROM AgLibraryCollection WHERE AgLibraryCollection.id_local = $1;"
}

#
# Input         $1      the id of a collection
# Return                the id of the parent collection
#
function getCollectionParent
{
  if [ "$1" != "" ];
  then
    query "SELECT parent FROM AgLibraryCollection WHERE AgLibraryCollection.id_local = $1;"
  fi
}

#
# Input         $1      the id of a collection
# Return                the file name + copy name of the images contained in the collection
#
function getImageIdsInCollection
{
  echo `query "SELECT lf.id_local FROM AgLibraryCollection AS c JOIN AgLibraryCollectionImage AS ci ON c.id_local = ci.collection JOIN Adobe_images AS i ON i.id_local = ci.image JOIN AgLibraryFile AS lf ON lf.id_local = i.rootFile WHERE c.id_local = $1;"`
}

#
# Input         $1      the id of a collection
# Return                the id of the parent collection
# Note: LR stores the path including a slash at the end.
#       Will be removed for reasons of consistency ...
#
function getImageImportPath
{
  echo `query "SELECT lfo.PathFromRoot FROM AgLibraryFile AS lfi JOIN AgLibraryFolder AS lfo ON lfo.id_local = lfi.folder WHERE lfi.id_local = $1;"` | sed 's/.$//'
}

#
# Input         $1      the id of a collection
# Return                the export path in form of subdirs
#                       corresponding to the original collection hierachy
#
function getImageExportSubDirsPath
{
  local exportPath
  exportPath=$(getCollectionName $1)
  local currentCollectionId
  currentCollectionId=$1
  while :
  do
    currentCollectionId=$(getCollectionParent $currentCollectionId)
    if [ "$currentCollectionId" == "" ];
    then
      break
    fi
    exportPath="$(getCollectionName $currentCollectionId)/$exportPath"
  done
  echo $exportPath
}

#
# Input         $1      the id of a collection
# Return                the export path in form of a single dir which filename
#                       corresponds to the original collection hierachy
#
function getImageExportSingleDirPath
{
  local exportPath
  exportPath=$(getCollectionName $1)
  local currentCollectionId
  currentCollectionId=$1
  while :
  do
    currentCollectionId=$(getCollectionParent $currentCollectionId)
    if [ "$currentCollectionId" == "" ];
    then
      break
    fi
    exportPath="$(getCollectionName $currentCollectionId)$COLLECTIONHIERACHYSEP$exportPath"
  done
  echo $exportPath
}

#
# Input         $1      the id of a image
# Return                the name of the image file
#
function getImageFileName
{
  query "SELECT lf.idx_filename FROM AgLibraryFile AS lf WHERE lf.id_local = $1;"
}

#
# Input         $1      the id of a collection
# Return                the name of the image's sidecar file if any
#
function getImageSidecarFileName
{
  query "SELECT lf.baseName || '.xmp' FROM AgLibraryFile AS lf WHERE lf.id_local = $1 AND NOT (lf.sidecarExtensions='' OR lf.sidecarExtensions IS NULL OR lf.sidecarExtensions='JPG' OR lf.sidecarExtensions='THM');"
}

#
# Return                the ids of the collections that are a web gallery, separated by spaces
#
function getAllCollectionIDs
{
  # Whitelist
  # query "SELECT DISTINCT id_local FROM AgLibraryCollection WHERE creationId='com.adobe.ag.library.collection' and id_local IN ('1595385');"

  # Blacklist
  query "SELECT DISTINCT id_local FROM AgLibraryCollection WHERE creationId='com.adobe.ag.library.collection' and id_local NOT IN ('21');"

  # Full scope
  # query "SELECT DISTINCT id_local FROM AgLibraryCollection WHERE creationId='com.adobe.ag.library.collection';"
}

#
# Input         $1      the file (name) to export
# Input         $2      the relative import path
# Input         $3      the relative export path
#
function exportFile
{
  # FIXME - destination files could be renamed to e.g. ALR_<AgLibraryFile.id_local>
  # FIXME - integrity of image data could be checked if required

  local SOURCE
  SOURCE=$IMPORTDIR/$2/$1
  local DESTINATION
  DESTINATION=$EXPORTDIR/$3/$1
  if [ "$DRYRUN" = "true" ];
  then
    echo "$(date +%Y-%m-%d' '%H:%M:%S) [DRYRUN] Exporting $SOURCE to $DESTINATION ..." >> $DEBUGLOGFILE
  else
    if cp "$SOURCE" "$DESTINATION" ;
    then
      echo "$(date +%Y-%m-%d' '%H:%M:%S) [SUCCESS] Exporting $SOURCE to $DESTINATION ..." >> $DEBUGLOGFILE
    else
      echo "$(date +%Y-%m-%d' '%H:%M:%S) [ERROR] Exporting $SOURCE to $DESTINATION ..." >> $ERRORLOGFILE
    fi
  fi
}

#
# Migrate all Collection of the Lightroom Catalog
#
function migrateCollections
{
  # FIXME For all images that are not part of a collection create a folder structure e.g. "YYYY unspecified" (year of <Adobe_images.captureTime) and export them as well

  # Walk over all collections
  for i in $(getAllCollectionIDs);
  do

    # Get current export path
    local currrentImageExportPath
    if [ "$FLATEXPORT" = "true" ]; then
      currrentImageExportPath=$(getImageExportSingleDirPath $i)
    else
      currrentImageExportPath=$(getImageExportSubDirsPath $i)
    fi

    # Inform about start
    local startColMsg
    startColMsg="$(date +%Y-%m-%d' '%H:%M:%S) [START] Starting migration of collection <$currrentImageExportPath> ..."
    echo $startColMsg
    echo $startColMsg > $DEBUGLOGFILE
    echo $startColMsg > $ERRORLOGFILE

    # Collection Statistics
    # FIXME Display progress current / total number of collections
    # FIXME Display current SUCCESS / current ERROR / total image count

    local START_TIME
    START_TIME=$SECONDS

    local currentExportDir
    currentExportDir="${EXPORTDIR}/${currrentImageExportPath}"

    # Check if export path for collection already exists
    if [ ! -d "$currentExportDir" ]; then
      # Path does not exist => create it
      if [ "$DRYRUN" = "true" ]; then
        echo "$(date +%Y-%m-%d' '%H:%M:%S) [DRYRUN] Creating directory $currentExportDir ..." >> $DEBUGLOGFILE
      else
        if mkdir -p "$currentExportDir" ;
        then
          echo "$(date +%Y-%m-%d' '%H:%M:%S) [SUCCESS] Creating directory $currentExportDir ..." >> $DEBUGLOGFILE
        else
          echo "$(date +%Y-%m-%d' '%H:%M:%S) [ERROR] Creating directory $currentExportDir ..." >> $ERRORLOGFILE
        fi
      fi
    fi

    # Counters for proper stats
    local IMGCOUNTER
    local SIDECARCOUNTER
    IMGCOUNTER=0
    SIDECARCOUNTER=0

    # Copy all images of collection to export directory
    for j in $(getImageIdsInCollection $i); do

      # Get current image path
      # FIXME get full path to support different root folders in case no $IMPORTDIR is provided
      local currentImageImportPath
      currentImageImportPath=$(getImageImportPath $j)

      # Get currrent image file name
      local currrentImageFileName
      currrentImageFileName=$(getImageFileName $j)

      # Export image file
      exportFile "$currrentImageFileName" "$currentImageImportPath" "$currrentImageExportPath"
      let IMGCOUNTER++

      # Handle sidecare file (XMP) if any
      if [ "$(getImageSidecarFileName $j)" != "" ];
      then

        # Get current sidecare file name
        currentImageSidecarFileName=$(getImageSidecarFileName $j)
        # echo "Sidecar: $currentImageSidecarFileName"

        # Export sidecar file
        exportFile "$currentImageSidecarFileName" "$currentImageImportPath" "$currrentImageExportPath"
        let SIDECARCOUNTER++

      fi
    done

    # Inform about end of collection export
    local endColMsg
    endColMsg="$(date +%Y-%m-%d' '%H:%M:%S) [END] Finished migration of collection <$currrentImageExportPath> ($IMGCOUNTER images, $SIDECARCOUNTER xmp-files, $(($SECONDS - $START_TIME)) seconds)."
    echo $endColMsg
    echo $endColMsg > $DEBUGLOGFILE
    echo $endColMsg > $ERRORLOGFILE
  done

  # Inform about end of catalog export
  endCatMsg="$(date +%Y-%m-%d' '%H:%M:%S) [END] Exported all collections of LR catalog <$CATALOG> ..."
  echo $endCatMsg
  echo $endCatMsg > $DEBUGLOGFILE
  echo $endCatMsg > $ERRORLOGFILE
}

migrateCollections
