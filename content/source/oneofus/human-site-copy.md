
### Build instructions for AI assistant (keep these here)

- Source of truth: this `human-site-copy.md` is the canonical content file. 
Humans should not edit `web/oneofus.html` or its CSS directly — the AI assistant will regenerate/update `web/oneofus.html` from this markdown.
- What I (the human) expect the AI assistant to do when asked to "build" the page:
  1. Read `content/source/human-site-copy.md`
  3. Generate `web/oneofus.html`

Ideally, this file (human-site-copy.md) would be like "source code" for the AI agent's file (oneofus.html)

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

Use the files apple.webp and google.webp in web/img
Put the 2 links at the top right of the page and stack them vertically.

- Notes for the builder: the app links should use `web/img/apple.webp` and `web/img/google.webp`, include `aria-label` attributes, open in a new tab (`target="_blank"`) and use `rel="noopener noreferrer"`. Stack them vertically in the header actions area.

## Wide box
Our own identity network
Tech advances have made it possible for us to own and use our own cyprtographic keys and authenticate ourselves without relying on any authority. By vouching for each other's identities directly and securely, we can know who we are on any service.
If you believe having <strong>decentralized, heterogenous</strong> network like this, who would you want to build and own it? Google? Elon? The Gov't? Or us.

--I am not a robot
You reading this now are either one of us or one of them.

- Notes for the builder: render this copy in a full-bleed hero band (100vw) separate from the centered container so the band spans the viewport width.

## Comic image wide box
- person image
Use img/jones.png

- Text in a comic font to say:
Farmers' market today, hmm... They don't like me over there..
Wait! Maybe I'll go using an incogneto browser. That way
- I can be totally annoying, and they won't know it's me.
- I could come again next week, and they won't even know it's the same dude.
If everyone went using incogneto windows, no-one would know who's who or who's even a person.
Sick!

- Notes for the builder: the comic band should be a separate full-bleed section containing two columns: the image (`img/jones.png`) and a caption bubble.
  - `.comic` styling: thick black border (~6px), rounded corners, subtle drop shadow.
  - `.comic-image`: clip overflow and apply `border-radius:10px` so the image corners are rounded.
  - Image: apply `border:4px solid #000` and `border-radius:10px`.
  - Caption bubble: use a comic font (Comic Neue or Bangers), reset paragraph margins inside the bubble to small inter-paragraph spacing as used in the page (`.bubble p { margin: 0 0 0.4rem; }` and `.bubble p:last-child { margin-bottom:0; }`), style with `border:3px solid #000`, white fill, speech-tail (black outline behind + white fill in front), and defaults `padding:6px 8px; font-size:1.05rem; line-height:1.12`.

# page bottom
- Contact: contact@one-of-us.net 
- Source: https://github.com/YotamAviv/oneofus

