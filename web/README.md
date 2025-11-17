# 2 projects, 1 repository
- Nerdster
- ONE-OF-US.NET

Both are open source on GitHub.

Both use Firebase hosting for their websites.

## Why both projects in same repository
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
### TODO
- create deploy scripts
  - nerdster: nothing special, copy everything from web/.. to build/web/..
  - oneofus: similar but overwrite the Nerdster's index.html with oneofus.html