# ExportLRCatalog.sh
Bash script that exports all photos of a Adobe Lightroom (LR) Catalog to the filesystem whilst preserving the Collection Structure in form of (sub)directories.

## CURRENT LIMITATIONS
* Only images that are part of a collection will be exported. If you want to export all of your photos wihtin the LR catalog, make sure to have them at least in one collection. To check e.g. create the following Smart-Collection within LR assuming that you do not use any strange filenames:
         `{Collection}{doesn't contain}{a e i o u 0 1 2 3 4 5 6 7 8 9}`
* As an image can be part of 1-n collection(s), some/many images will get duplicated
* Currently one single image location is supported as source

## USAGE
1. Make a backup of your LR catalog (ideally use this one for export)
1. Make a backup of your image directory
1. Check that you have sufficient disk space in your export directory
1. Adjust the CONFIGURATION section within [`./ExportLRCatalog.sh`](ExportLRCatalog.sh) to your needs and environment
1. Run [`./ExportLRCatalog.sh`](ExportLRCatalog.sh)

## DOCUMENTATION
...

## LICENSE
see [LICENSE](LICENSE)

## CREDITS
Inspired by https://photo.stackexchange.com/a/65153 by fabrizio
