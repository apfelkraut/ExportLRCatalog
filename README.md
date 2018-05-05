# ExportLRCatalog.sh
Bash script that exports all photos of a Adobe Lightroom (LR) Catalog to the filesystem.

* Images that are part of a collection will be exported to a directory. One directory per collection.
* Images that are not part of any collection will be exported in one or more dedicated directories (if configured).
* In sum all image files that are known to the LR catalog shall get exported either way.
* Image files will be exported along with its XMP sidecar files (if available).
* Image files can be renamed (if configured).
* The export is non-destructive. You can still continue working with LR and (re)run the export at any time.
* The LR application or a LR license is not required. The actual catalog file (e.g. `Lightroom Catalog.lrcat`) and its image repository (e.g. `$HOME/Pictures`) are sufficient.
* Any performed action is logged.
* A "dry run" mode is available in order to check what would actually happen via the logs.

## MOTIVATION
* LR meanwhile "Lightroom Classic" was and still is a great tooling for image organization and image manipulation.
* LR version 6 was the last release that you could actually buy and own. The successor "Lightroom Classic CC" (some kind of version 7) is only available for renting.
* LR is a proprietary product (in contrast to [Free Software](https://en.wikipedia.org/wiki/Free_software)), so you never know where you and especially your photo library will end up one day.
* Free alternatives have matured over the years. Depending on personal perception and preferences they might have already outperformed LR in respected to functionality and usability. At least in respect to user's freedoms. There is e.g. [Darktable](https://www.darktable.org/), [RawTherapee](http://rawtherapee.com/), or [digiKam](https://www.digikam.org/) to name just a few.
* Those but even any proprietary alternatives do not offer to migrate/import the LR catalog en bloc. The only workaround is via the filesystem. So that the image collection structure is represented by (sub)directories if you do not want to or simply cannot rely on your images' metadata.
* A typical LR image repository is organized within subdirectories of YYYY/MM/DD, which might not be the preferred structure to bring to any other application.
* A collection can be exported by hand. But as one typically has many collections, this might not be what you really want to do manually.
* The LR catalog (`.lrcat`) is actually a [SQLite](https://sqlite.org/) database file that can be opened with any compatible tooling.

## LIMITATIONS
* This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.
* It is still work in progress (BETA) and might not do what is promised.
* As an image can be part of 1-n collection(s), some/many images will get duplicated.
* Virtual copies will be ignored and not get exported.
* Currently only a single root location where all of your image folders are located is supposed (e.g. `$HOME/Pictures`).
* Implementation is far from being efficient.
* Error handling is far from being perfect.
* Currently tested only on macOS with LR version 6

## PREREQUISITE
* Make sure that the XMP sidecar files are enabled in your LR application
* Make sure that all metadata are synced to the actual files via your LR application
* Prepare your LR catalog (via the LR application if you still have it)
  * Delete any unnecessary collections to prevent image file duplication (current duplication rate will be displayed)
  * Create new collections for images that you want to have within a dedicated subdirectory. To find any image that are not part of a collection you could e.g. create the following Smart-Collection within LR assuming that you do not use any strange filenames:
           `{Collection}{doesn't contain}{a e i o u 0 1 2 3 4 5 6 7 8 9}`
* Make sure that you have sufficient disk space in your export directory
* You need to have `bash`, `sed`, `sqlite3`, and `bc` available in your `$PATH` on a POSIX-compliant environment like Linux or macOS

## USAGE
1. Note that this is still BETA (work in progress) and might not do what is promised
1. Prepare your LR catalog as described above
1. Make a backup of your LR catalog and ideally use the backup for this export
1. Adjust the configuration in [`./Config.sh`](Config.sh) to your needs and environment
1. Run [`./ExportLRCatalog.sh`](ExportLRCatalog.sh)
1. When completed carefully review the results and especially the logs

## LICENSE
GNU GPLv3, see [LICENSE](LICENSE) for details.

## CREDITS
* Inspired by https://photo.stackexchange.com/a/65153 by fabrizio
* Thanks to Adobe Systems Inc. for a still great LR (Classic) and implementing its catalog in form of a freely accessible SQLite database
