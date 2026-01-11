# Hosting & Home Pages

## 2 projects, 1 repository
- Nerdster Web App (might support other platforms in the future)
- ONE-OF-US.NET Phone App

Both are open source on GitHub.

Both use Firebase hosting for their websites.

Current web files (in this repository)
- `index.html` — Nerdster app wrapper (site root)
- `home.html` — Nerdster home page
- `oneofus.html` — ONE-OF-US.NET home page (served at `/oneofus.html` during development, deployed as index.html)

## Why both project web sites in same repository
I've been developing the Nerdster in VSCode, and have an AI agent configured to help there.

I've been developing the ONE-OF-US.NET phone app in Android Studio, and don't have you configured there.

Some (or rather many) styles and JavaScript helpers are expected to be common to both.

I'd like to be able to view both home pages during the development

## Nerdster
index.html must serve the web app wrapper and be available at https://nerdster.org/index.html

The "home" page is developed in file home.html and should be available at https://nerdster.org/home.html

## ONE-OF-US.NET
The "home" page is developed in oneofus.html and should be available at https://one-of-us.net/index.html

# Development
I use VSCode to debug the Flutter app, possibly using "nerdster (web fixed port)".

I want to develop both sites as well as the Flutter app.

I should be able to view and debug these:
- home.html
- oneofus.html
- index.html remains where the Nerdster Flutter web app is served

All of the pages related to either project should work during development with the exception that the one-of-us.net/index.html is not there and is at one-of-us.net/oneofus.html instead.

## deployment
### Deploy scripts
Not great, but functional
- See:
  - bin/stage_nerdster.sh
  -`bin/stage_oneofus.sh`

Notes:
- Run `flutter build web` first to generate `build/web`

###
flutter build web --release; firebase --project=nerdster deploy
firebase --project=one-of-us-net deploy --only functions
./bin/stage_nerdster.sh deploy
./bin/stage_oneofus.sh deploy
