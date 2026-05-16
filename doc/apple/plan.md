# Apple Review — Plan

## History files
The dated correspondence files in this folder are for reference only. Do not modify them.

## Current state

### What I've built to address launch usability
Apple previously asked that the app be usable without requiring ONE-OF-US.NET. I added a bootstrap feature to address that, and Apple appear to have accepted it (their next message moved on to UGC). However, I've since decided I don't like the bootstrap feature. In its place:

- **The Nerdster opens `https://nerdster.org` links.** The in-app Share function creates these links, so people can share content and others can open it directly in the app — no ONE-OF-US.NET app required to browse.
- **4th sign-in option: "Preview without an account"** — lets anyone browse as me (Yotam Aviv) and see content/features, though they can't rate, comment, follow, etc. without signing in with ONE-OF-US.NET.

These two additions together mean the app is usable at launch without any other app.

### Argument on content visibility (response to prior rejection)
Apple's concern was that users can't see content on launch. The TikTok/Instagram comparison: yes, you can open those and see content immediately — but you have no idea who anyone is, and you never will.

The Nerdster/ONE-OF-US.NET paradigm is the opposite: everyone whose content you see has been invited through your (or your network's) trust chain. There is a cryptographic signature chain to all content. You *know* who everyone is.

### Argument on moderation (in response to Guideline 1.2)
The Nerdster has *decentralized* moderation built in by design:
TODO: Mention that the CENSOR button is on the rate dialog and has always been there. Content you censor is gone immediately.
Nerdster layer:
- **Decentralized censorship:** People you in your follow network censor content for you by design.
- **Decentralized blocking:** You can block any person and so can others in your follow network. If your trusted network blocks someone, they're likely blocked for you too (unless you or someone who is more trusted in your network else explicitly followed them).
ONE-OF-US.NET idenity layer:
- **Identity-level trust:** The ONE-OF-US.NET app allows people block identities ("Bots, spammers, bad actors, careless, confused") entirely. The Nerdster only surfaces content from people your network recognizes as "Human, capable, acting in good faith."

I want to try to have Apple accept the app as-is, using these existing features as the moderation argument.

If they don't accept this, I will add centralized censorship as described in a separate doc (not in this branch).

