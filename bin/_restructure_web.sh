#!/usr/bin/env bash
# _restructure_web.sh
# Shared helper: restructures build/web after `flutter build web --base-href /app/`
# so that:
#   build/web/app/  <- Flutter app (all Flutter-generated files)
#   build/web/      <- Static site (home page, terms, safety, etc.)
#
# Source this file, then call: restructure_web

restructure_web() {
  echo "=== Restructuring build output ==="

  # Rename trick: move the entire Flutter output to /app/ by renaming,
  # then move only the known static site files back to root.
  # This avoids having to enumerate Flutter's generated files.
  mv build/web build/web_tmp
  mkdir build/web
  mv build/web_tmp build/web/app

  # Move static site files back to root
  for f in terms.html safety.html policy.html man.html favicon.ico; do
    [ -e "build/web/app/$f" ] && mv "build/web/app/$f" "build/web/"
  done
  for d in common img .well-known; do
    [ -d "build/web/app/$d" ] && mv "build/web/app/$d" "build/web/"
  done

  # Rename home page files to index.*
  mv build/web/app/home.html build/web/index.html
  mv build/web/app/home.css  build/web/index.css
  mv build/web/app/home.js   build/web/index.js

  # Copy favicon.ico to /app/ too (Flutter PWA references it at /app/favicon.ico)
  cp build/web/favicon.ico build/web/app/

  echo "  Done. Flutter app -> build/web/app/, home page -> build/web/"
}
