Granny WebGL build - 105MB version (about 108 MB total)
====================================================

Everything for this version is inside the folder 'Granny_105MB'. Extract ALL zips starting with 'Granny_105MB_'
into the same place; you get one folder 'Granny_105MB':
  index.html
  TemplateData/
  Build/  UnityLoader.js, GrannyPortButBetter.json, wasm.code.unityweb, wasm.framework.unityweb
  Build/d105/  GrannyPortButBetter.data.unityweb.part1 ... part6   (6 parts, each under 20 MB)

UPLOAD: copy the CONTENTS of 'Granny_105MB' to the root of your repo. DELETE every old .partN file that sits directly in
Build/ (the new parts live in Build/d105/ so they can never collide with old cached files).

index.html checks every data part (size + SHA-256). If a wrong/old file is served by the CDN you will see
'LOADING FAILED: data part N ...' instead of a Unity crash. Also set <base href> to your commit hash:
  https://cdn.jsdelivr.net/gh/web-ports/granny@COMMITHASH/

If you still get 'An exception has occurred': press F12 -> Console, and copy the red/last lines.
