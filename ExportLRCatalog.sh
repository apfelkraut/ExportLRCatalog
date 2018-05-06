#!/bin/bash

# ExportLRCatalog.sh Version 0.8 BETA
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

# DOCUMENTATION
# see ./README.md

# LICENSE
# see ./LICENSE

# CREDITS
# see ./README.md


# Import configuration
source Config.sh

# Pass all global variables to child processes
export DRYRUN
export FLATEXPORT
export RENAME
export COLLECTIONHIERACHYSEP
export BLACKLISTEDCOLLECTIONS
export YEARS
export CATALOG
export LOCK_FILE
export IMPORTDIR
export EXPORTDIR
export DEBUGLOGFILE
export ERRORLOGFILE

#
# Input         $1      a string
# Return                the string, trimmed
#
function trim
{
  echo -e "$1" | sed 's/^ *//' | sed 's/ *$//'
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
# Input         $1      variable to check for null or empty
#
function checkNullOrEmpty
{
  if [[ -z "$1" || "$1" == "" ]]; then
    echo "ERROR: found NULL or EMPTY variable in <$2>, exiting ..."
    exit 1
  fi
}

#
# Return                the count of images that are not part of any collection
#
function countImagesNotInAnyCollection
{
  query "SELECT count(id_local) FROM AgLibraryFile WHERE id_local NOT IN (SELECT lf.id_local FROM AgLibraryCollection AS c JOIN AgLibraryCollectionImage AS ci ON c.id_local == ci.collection JOIN Adobe_images AS i ON i.id_local == ci.image JOIN AgLibraryFile AS lf ON lf.id_local == i.rootFile WHERE i.copyName IS NULL AND c.creationId='com.adobe.ag.library.collection' AND c.id_local NOT IN $BLACKLISTEDCOLLECTIONS);"
}

#
# Return                the count of images that are part of any collection
#
function countImagesInAnyCollection
{
  query "SELECT count(lf.id_local) FROM AgLibraryCollection AS c JOIN AgLibraryCollectionImage AS ci ON c.id_local == ci.collection JOIN Adobe_images AS i ON i.id_local == ci.image JOIN AgLibraryFile AS lf ON lf.id_local == i.rootFile WHERE i.copyName IS NULL AND c.creationId='com.adobe.ag.library.collection' AND c.id_local NOT IN $BLACKLISTEDCOLLECTIONS;"
}

#
# Return                the count of unique images that are part of any collection
#
function countImagesInAnyCollectionDistinct
{
  query "SELECT count(DISTINCT lf.id_local) FROM AgLibraryCollection AS c JOIN AgLibraryCollectionImage AS ci ON c.id_local == ci.collection JOIN Adobe_images AS i ON i.id_local == ci.image JOIN AgLibraryFile AS lf ON lf.id_local == i.rootFile WHERE i.copyName IS NULL AND c.creationId='com.adobe.ag.library.collection' AND c.id_local NOT IN $BLACKLISTEDCOLLECTIONS;"
}

#
# Return                the count of image files
#
function countImagesFiles
{
  query "SELECT count(id_local) FROM AgLibraryFile;"
}

#
# Return                the count of images within LR (including virtual copies)
#
function countLRImages
{
  query "SELECT count(id_local) FROM Adobe_images;"
}

#
# Return                the count of all collections
#
function countAllCollections
{
  # Blacklist
  echo `query "SELECT count(id_local) FROM AgLibraryCollection WHERE creationId='com.adobe.ag.library.collection' and id_local NOT IN $BLACKLISTEDCOLLECTIONS;"`
}

#
# Input         $1      the id of a collection
# Return                the name of the collection
#
function getCollectionName
{
  query "SELECT name FROM AgLibraryCollection WHERE AgLibraryCollection.id_local == $1;"
}

#
# Input         $1      the id of a collection
# Return                the id of the parent collection
#
function getCollectionParent
{
  if [ "$1" != "" ];
  then
    query "SELECT parent FROM AgLibraryCollection WHERE AgLibraryCollection.id_local == $1;"
  fi
}

#
# Input         $1      the id of a collection
# Return                the ids of images contained in the collection
#
function getImageIdsInCollection
{
  echo `query "SELECT lf.id_local FROM AgLibraryCollection AS c JOIN AgLibraryCollectionImage AS ci ON c.id_local == ci.collection JOIN Adobe_images AS i ON i.id_local == ci.image JOIN AgLibraryFile AS lf ON lf.id_local == i.rootFile WHERE i.copyName IS NULL AND c.id_local == $1;"`
}

#
# Input         $1      the id of a collection
# Return                the image specific details of given collection
#
function getImageDetailsInCollection
{
  echo `query "SELECT lf.id_local, lf.idx_filename, lf.sidecarExtensions, lfo.PathFromRoot FROM AgLibraryCollection AS c JOIN AgLibraryCollectionImage AS ci ON c.id_local == ci.collection JOIN Adobe_images AS i ON i.id_local == ci.image JOIN AgLibraryFile AS lf ON lf.id_local == i.rootFile JOIN AgLibraryFolder AS lfo ON lfo.id_local == lf.folder WHERE i.copyName IS NULL AND c.id_local == $1;"`
}

#
# Input         $1      the year to get images for that are not part of any collection
# Return                the image specific details outside of any collection captured within given year
#
function getImageDetailsNotInAnyCollectionByYear
{
  echo `query "SELECT lf.id_local, lf.idx_filename, lf.sidecarExtensions, lfo.PathFromRoot FROM Adobe_images AS i JOIN AgLibraryFile AS lf ON i.rootFile == lf.id_local JOIN AgLibraryFolder AS lfo ON lfo.id_local == lf.folder WHERE i.captureTime LIKE '$1%' AND i.copyName IS NULL AND lf.id_local NOT IN (SELECT lf.id_local FROM AgLibraryCollection AS c JOIN AgLibraryCollectionImage AS ci ON c.id_local == ci.collection JOIN Adobe_images AS i ON i.id_local == ci.image JOIN AgLibraryFile AS lf ON lf.id_local == i.rootFile WHERE i.copyName IS NULL AND c.creationId='com.adobe.ag.library.collection' AND c.id_local NOT IN $BLACKLISTEDCOLLECTIONS);"`
}

#
# Input         $1      the filter WHERE statement for years to exclude
# Return                the image specific details outside of any collection captured outside of given years
#
function getImageDetailsNotInAnyCollectionFilterByYears
{
  echo `query "SELECT lf.id_local, lf.idx_filename, lf.sidecarExtensions, lfo.PathFromRoot FROM Adobe_images AS i JOIN AgLibraryFile AS lf ON i.rootFile == lf.id_local JOIN AgLibraryFolder AS lfo ON lfo.id_local == lf.folder WHERE $1 i.copyName IS NULL AND lf.id_local NOT IN (SELECT lf.id_local FROM AgLibraryCollection AS c JOIN AgLibraryCollectionImage AS ci ON c.id_local == ci.collection JOIN Adobe_images AS i ON i.id_local == ci.image JOIN AgLibraryFile AS lf ON lf.id_local == i.rootFile WHERE i.copyName IS NULL AND c.creationId='com.adobe.ag.library.collection' AND c.id_local NOT IN $BLACKLISTEDCOLLECTIONS);"`
}

#
# Return                the ids of all collections beside the ones that are blacklisted
#
function getAllCollectionIDs
{
  # Blacklist
  query "SELECT id_local FROM AgLibraryCollection WHERE creationId='com.adobe.ag.library.collection' and id_local NOT IN $BLACKLISTEDCOLLECTIONS;"
}

#
# Input         $1      the id of a collection
# Return                the export path corresponding to the original collection hierachy
#
function getImageExportPath
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
    if [ "$FLATEXPORT" == "true" ]; then
      # Generate export path by using separator (single directory)
      exportPath="$(getCollectionName $currentCollectionId)$COLLECTIONHIERACHYSEP$exportPath"
    else
      # Generate export path by using subdirectories
      exportPath="$(getCollectionName $currentCollectionId)/$exportPath"
    fi
  done
  echo -e $exportPath
}

#
# Input         $1      the file (name) to export
# Input         $2      the relative import path
# Input         $3      the file id
# Input         $4      the relative export path
#
function copyFile
{
  # FIXME - integrity of image data could be checked if required
  # FIXME - support resume

  # Check for null values
  checkNullOrEmpty $1 "copyFile P1"
  checkNullOrEmpty $2 "copyFile P2"
  checkNullOrEmpty $3 "copyFile P3"
  checkNullOrEmpty $4 "copyFile P4"

  local SOURCE
  local DESTINATION

  SOURCE=$IMPORTDIR/$2/$1

  # check if file shall be renamed
  if [ "$RENAME" == "true" ];
  then
    # prefix for new filename
    prefixNewFilename="ALR_"

    # extract extension
    fileExtension="${1##*.}"
    fileName="${1%.*}"

    # generate new filename based on id
    DESTINATION="$EXPORTDIR/$4/$prefixNewFilename$3.$fileExtension"

  else
    # use original filname
    DESTINATION="$EXPORTDIR/$4/$1"
  fi

  if [ "$DRYRUN" == "true" ];
  then
    echo -e "$(date +%Y-%m-%d' '%H:%M:%S) [DRYRUN] Exporting $SOURCE to $DESTINATION ..." >> $DEBUGLOGFILE
  else
    if cp "$SOURCE" "$DESTINATION" ;
    then
      # if files are being renamed also rename filename within sidecar file
      if [[ "$RENAME" == "true" && "$fileExtension" == "xmp" ]];
      then
        # make backup of original sidecar file
        mv "$DESTINATION" "$DESTINATION.bak"

        # replace original with new filename within sidecar files and then delete backup
        sed -e 's/'"$fileName"'/'"$prefixNewFilename$3"'/g' <"$DESTINATION.bak" >"$DESTINATION" && rm "$DESTINATION.bak"
      fi

      echo -e "$(date +%Y-%m-%d' '%H:%M:%S) [SUCCESS] Exporting $SOURCE to $DESTINATION ..." >> $DEBUGLOGFILE
    else
      echo -e "$(date +%Y-%m-%d' '%H:%M:%S) [ERROR] Exporting $SOURCE to $DESTINATION ..." >> $ERRORLOGFILE
    fi
  fi
}

#
# Input         $1      the file ids to export
# Input         $2      the relative export path
#
function exportImages
{
  # Check for null values
  checkNullOrEmpty $1 "exportImages P1"
  checkNullOrEmpty $2 "exportImages P2"

  # Counters for proper stats
  local IMGCOUNTER
  local SIDECARCOUNTER
  local START_TIME
  local currentExportDir

  IMGCOUNTER=0
  SIDECARCOUNTER=0
  START_TIME=$SECONDS

  currentExportDir="${EXPORTDIR}/$2"

  # Inform about start
  local startExportImgsMsg
  startExportImgsMsg="$(date +%Y-%m-%d' '%H:%M:%S) [START] Starting export to directory <$2> ..."
  echo -e $startExportImgsMsg
  echo -e $startExportImgsMsg >> $DEBUGLOGFILE
  echo -e $startExportImgsMsg >> $ERRORLOGFILE

  # Check if export path for collection already exists
  if [ ! -d "$currentExportDir" ]; then
    # Path does not exist => create it
    if [ "$DRYRUN" == "true" ]; then
      echo -e "$(date +%Y-%m-%d' '%H:%M:%S) [DRYRUN] Creating directory $currentExportDir ..." >> $DEBUGLOGFILE
    else
      if mkdir -p "$currentExportDir" ;
      then
        echo -e "$(date +%Y-%m-%d' '%H:%M:%S) [SUCCESS] Creating directory $currentExportDir ..." >> $DEBUGLOGFILE
      else
        echo -e "$(date +%Y-%m-%d' '%H:%M:%S) [ERROR] Creating directory $currentExportDir ..." >> $ERRORLOGFILE
      fi
    fi
  fi

  # Copy all images of collection to export directory
  for j in $1; do

    # FIXME get full path to support different root folders in case no $IMPORTDIR is provided

    local detailsArray
    local currrentImageFileId
    local currrentImageFileName
    local currentImageSidecarExtensions
    local currentImageImportPath

    # Save default IFS
    DEFAULT_IFS=$IFS

    # Split image details
    IFS='|' read -a detailsArray <<< "$j"

    # Restore default IFS
    IFS=$DEFAULT_IFS

    # Get current image id
    currrentImageFileId=${detailsArray[0]}

    # Get currrent image file name
    currrentImageFileName=${detailsArray[1]}

    # Get current sidecar file extensions if any
    currentImageSidecarExtensions=${detailsArray[2]}

    # Get currrent image file name without trailing slash
    currentImageImportPath=$(echo "${detailsArray[3]}" | sed 's/.$//')

    # Export image file
    copyFile "$currrentImageFileName" "$currentImageImportPath" "$currrentImageFileId" "$2"
    let IMGCOUNTER++

    # Handle sidecare file (XMP) if any
    if [[ "$currentImageSidecarExtensions" != "" && "$currentImageSidecarExtensions" == *"xmp"* ]];
    then
      # Determine sidecar name
      sidecarFileName="${currrentImageFileName%.*}"
      currentImageSidecarFileName="$sidecarFileName.xmp"

      # Export sidecar file
      copyFile "$currentImageSidecarFileName" "$currentImageImportPath" "$currrentImageFileId" "$2"
      let SIDECARCOUNTER++
    fi
  done

  # Inform about finishing export of images
  local endExportImgsMsg
  endExportImgsMsg="$(date +%Y-%m-%d' '%H:%M:%S) [END] Finished export to directory <$2> ($IMGCOUNTER images, $SIDECARCOUNTER xmp-files, $(($SECONDS - $START_TIME)) seconds)."
  echo -e $endExportImgsMsg
  echo -e $endExportImgsMsg >> $DEBUGLOGFILE
  echo -e $endExportImgsMsg >> $ERRORLOGFILE
}

#
# Export all images that are part of a collection
#
function exportCollections
{
  # Inform about start of collections export
  local startExportCollMsg
  startExportCollMsg="$(date +%Y-%m-%d' '%H:%M:%S) [START] Exporting all collections of LR catalog <$CATALOG> ..."
  echo -e $startExportCollMsg
  echo -e $startExportCollMsg >> $DEBUGLOGFILE
  echo -e $startExportCollMsg >> $ERRORLOGFILE

  # Walk over all collections
  for i in $(getAllCollectionIDs);
  do

    # Get current export path
    local currrentImageExportPath
    currrentImageExportPath=$(getImageExportPath $i)

    # Get details of images within current collection
    local currentImagesDetails
    currentImagesDetails=$(getImageDetailsInCollection $i)

    # Check if current collection really contains any images
    if [ "$currentImagesDetails" != "" ];
    then
      # Export Images
      exportImages "$currentImagesDetails" "$currrentImageExportPath"
    fi

  done

  # Inform about end of collections export
  local endExportCollMsg
  endExportCollMsg="$(date +%Y-%m-%d' '%H:%M:%S) [END] Exported all collections of LR catalog <$CATALOG> ..."
  echo -e $endExportCollMsg
  echo -e $endExportCollMsg >> $DEBUGLOGFILE
  echo -e $endExportCollMsg >> $ERRORLOGFILE
}

#
# Export all images that are not part of a collection
#
function exportImagesNotInAnyCollection
{
  # Inform about start of non-collections export
  local startExportNonColMsg
  startExportNonColMsg="$(date +%Y-%m-%d' '%H:%M:%S) [START] Exporting all images that are not part of a collection of LR catalog <$CATALOG> ..."
  echo -e $startExportNonColMsg
  echo -e $startExportNonColMsg >> $DEBUGLOGFILE
  echo -e $startExportNonColMsg >> $ERRORLOGFILE

  # Base name of unspecified folder(s)
  folderBaseName="Unspezifiziert"

  # Current image details
  local currentImagesDetails

  # Prepare years string
  separateYears=${YEARS//\'/} # remove quote
  separateYears=${separateYears//(/} # remove opening bracket
  separateYears=${separateYears//)/} # remove closing bracket
  separateYears=${separateYears//,/" "} # replace comma by space

  # SQL WHERE statement for later
  sqlWHERE=""

  # Get images for given years
  for i in $separateYears;
  do
    # Get details of images within current year
    currentImagesDetails=$(getImageDetailsNotInAnyCollectionByYear $i)

    # In case there are images for given years
    if [ "$currentImagesDetails" != "" ];
    then
      # Define export path
      currrentImageExportPath="$i $folderBaseName"

      # Export Images
      exportImages "$currentImagesDetails" "$currrentImageExportPath"

      # Append SQL WHERE
      if [ "$sqlWHERE" != "" ];
      then
        sqlWHERE+=" AND "
      fi
      sqlWHERE+="i.captureTime NOT LIKE '$i%'"
    fi
  done

  # Add an AND to the SQL
  if [ "$sqlWHERE" != "" ];
  then
    sqlWHERE+=" AND "
  fi

  # Export left images for other years
  currentImagesDetails=$(getImageDetailsNotInAnyCollectionFilterByYears $sqlWHERE)
  if [ "$currentImagesDetails" != "" ];
  then
    exportImages "$currentImagesDetails" "$folderBaseName"
  fi

  # Inform about end of non-collections export
  local endExportNonColMsg
  endExportNonColMsg="$(date +%Y-%m-%d' '%H:%M:%S) [END] Exported all images that are not part of a collection of LR catalog <$CATALOG> ..."
  echo -e $endExportNonColMsg
  echo -e $endExportNonColMsg >> $DEBUGLOGFILE
  echo -e $endExportNonColMsg >> $ERRORLOGFILE

}

# Write a dedicated error log
exec 2>$ERRORLOGFILE

# Immediately stop in case of error
# set -e

# Check if LR catalog exists
if [ ! -f "$CATALOG" ];
then
  echo -e "LR catalog not found at $CATALOG."
  exit 1
fi

# Check if LR application is open and locking the catalog
if [ -f "$LOCK_FILE" ];
then
  echo -e "LR catalog appears to be locked. Please quit Lightroom before running this script."
  exit 1
fi

# Check if import directory exists
if [ ! -d "$IMPORTDIR" ] ;
then
  echo -e "Import directory $IMPORTDIR not found."
  exit 1
fi

# Check if export directory exists
if [ ! -d "$EXPORTDIR" ] ;
then
  echo -e "Export directory $EXPORTDIR not found."
  exit 1
fi

# Check if export directory is writeable
if ! touch $DEBUGLOGFILE || ! touch $ERRORLOGFILE ;
then
  echo -e "Export directory $EXPORTDIR it not writable."
  exit 1
fi

# Check if sqlite3 is available
if ! which sqlite3 ;
then
  echo -e "Command line interface for SQLite 3 (sqlite3) not found."
  exit 1
fi

# Check if sed is available
if ! which sed ;
then
  echo -e "GNU stream editor (sed) not found."
  exit 1
fi

# Check if bc is available
if ! which bc ;
then
  echo -e "GNU bc (bc) not found."
  exit 1
fi

# Now let's really start
startCatMsg="$(date +%Y-%m-%d' '%H:%M:%S) [START] Starting exporting all collections of LR catalog <$CATALOG> ..."

echo -e $startCatMsg >> $ERRORLOGFILE

# Generate statistics
numAllCollections=$(countAllCollections)
numImagesInAnyCollection=$(countImagesInAnyCollection)
numImagesInAnyCollectionDistinct=$(countImagesInAnyCollectionDistinct)
numImagesNotInAnyCollection=$(countImagesNotInAnyCollection)
numImagesFiles=$(countImagesFiles)
numLRImages=$(countLRImages)
duplicationRate=`echo "scale=3;$numImagesInAnyCollection/$numImagesInAnyCollectionDistinct" | bc -l`

# Header of stats
startCatMsg+="\n"
startCatMsg+="------- Catalog Statistics -------"

# Add number of collections to be exported
startCatMsg+="\n"
startCatMsg+="Collections: $numAllCollections"
startCatMsg+="\n"

# Add total number of images in collections plus duplication of images within all collections
startCatMsg+="Images in collections: $numImagesInAnyCollection (duplication rate: $duplicationRate)"
startCatMsg+="\n"

# Add total number of images not in any collection
startCatMsg+="Images w/o collection: $numImagesNotInAnyCollection"
startCatMsg+="\n"

# Add total number of LR images (including virtual copies)
startCatMsg+="Total LR images: $numLRImages (incl. virtual copies)"
startCatMsg+="\n"

# Add total number of image files
startCatMsg+="Total image files: $numImagesFiles"
startCatMsg+="\n"

# Footer of stats
startCatMsg+="----------------------------------"

echo -e $startCatMsg
echo -e $startCatMsg >> $DEBUGLOGFILE

# Export all images that are part of a collections
exportCollections

# Export all images that are part of a collections
exportImagesNotInAnyCollection
