
### Build instructions for AI assistant (keep these here)

- Source of truth: this `human-site-copy.md` is the canonical content file. 
Humans should not edit `web/oneofus.html` or its CSS directly — the AI assistant will regenerate/update `web/oneofus.html` from this markdown.
- What I (the human) expect the AI assistant to do when asked to "build" the page:
  1. Read `content/source/human-site-copy.md`
  3. Generate `web/oneofus.html`

# top of page
## left
- ONE-OF-US.NET
- ONE-OF-US.NET logo
### slightly below the logo
- Tagline (three lines). Render this block as preformatted text under the site title so spacing and indentation are preserved.

Tagline (exact lines to render):

    A network of the people, by the people, for the people.
      All your likes are belong to us.
        Retis, ergo sum.

Rendering note: When producing the HTML page, place the block above (exactly as shown) in a <pre> or an element styled with `white-space: pre-wrap;` and a monospace font. This keeps the indentation and line breaks verbatim.

## app store links
[Apple App Store]
- link: https://apps.apple.com/us/app/one-of-us/id6739090070?itscg=30200&itsct=apps_box_badge&mttnsubad=6739090070

[Google Play]
- link: https://play.google.com/store/apps/details?id=net.oneofus.app

Use the files apple.webp and google.web in web/img
Put the 2 links at the top right of the page and stack them vertically.

## Wide box
Our own identity network
Tech advances have made it possible for us to own and use our own cyprtographic keys and authenticate ourselves without relying on any authority. By vouching for each other's identities directly and securely, we can know who we are on any service.
If you believe having <strong>decentralized, heterogenous</strong> network like this, who would you want to build and own it? Google? Elon? The Gov't? Or us.

--I am not a robot
You reading this now are either one of us or one of them.

## Comic image wide box
- person image
Use img/jones.png

- Text in a comic font to say:
Farmers' market today, hmm... They don't like me over there..
Wait! Maybe I'll go using an incogneto browser. That way
- I can be totally annoying, and they won't know it's me.
- I could come again next week, and they won't even know it's the same dude.
If everyone went using incogneto windows, no-one would know who's who or who's even a person.
SicK!"

# page bottom
- Contact: contact@one-of-us.net 
- Source: https://github.com/YotamAviv/oneofus