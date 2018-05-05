#!/bin/bash

# Dry run to change nothing and just log actions
DRYRUN=false

# Single directory per collection that includes all parent collection groups or
# create (sub)directory structure following the collection's hierachy
FLATEXPORT=true

# Rename files when exporting or leave original filename
RENAME=true

# Seperator to be used when multiple collection (group) names are combined to
# a single directory name during export. Otherwise being ignored.
COLLECTIONHIERACHYSEP=" - "

# Which collections shall not be exported? (e.g. the Quick Collection)
BLACKLISTEDCOLLECTIONS="('21')"

# Which years shall be exported in separate unspecified folders?
YEARS="('2008','2009','2010','2011','2012','2013','2014','2015','2016','2017','2018')"

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
