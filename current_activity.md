These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation

# Current Activity:




I think that the associations are working fairly well now
Android app:
- https://one-of-us.net/ : YES
- keymeid:// : YES
iOS app:
- https://one-of-us.net/ : YES
- keymeid:// : YES
Chrome on Android
- https://one-of-us.net/ : YES
- keymeid:// : YES
Firefox on Android
- https://one-of-us.net/ : YES
- keymeid:// : YES
Chrome on iOS
- https://one-of-us.net/ : YES
- keymeid:// : YES
Safari on iOS
- https://one-of-us.net/ : YES
- keymeid:// : NO

Let me know if these are known if you have any knowlege beyond this.

-------
Changes to SignInDialog:

Keep it simple. Remove any remaining complexity where we try to guess how well a magic link
will perform on a given device.

Regardless of platform, show:
Identity app on this device:
  - https://one-of-us.net/ (universal link)
Identity app on different device:
  - Scan QR code

Add a "+" / "-" toggle to the blue header box that says, "Use your identity app (ONE-OF-US.NET)".
When "+" is shown, the following are shown:
Identity app on this device:
  - keymeid:// (custom scheme)
  - https://one-of-us.net/ (universal link)
Identity app on different device:
  - Scan QR code
No identity app: (Restrictions for No identity app:) 
  - Enter the Nerdster!

Restrictions for No identity app:
- only on mobile
- only if there is currently no signed in identity (delegate not required).


Clicking the blue header box 7 times (instead of the text, "Identity app on this device") will show all options including
- Paste keys




Upates:
- https://keymeid did not work from Safari on iOS
- hide Enter the Nerdster if have identity, only show if don't
- improve text on sign-in.html


--------------------
From Clacker:
Your breakdown aligns perfectly with how modern browsers handle deep linking, but there are a few important nuances worth noting beyond your list:

Safari on iOS does support keymeid://, BUT only if the app is installed: If the identity app is actually installed on the iPhone, Safari will prompt "Open in [App Name]?". The reason it's a hard "NO" in practice is that if the app is NOT installed, Safari fails aggressively with a jarring error dialogue: "Safari cannot open the page because the address is invalid". There is no graceful fallback.
Chrome/Firefox on iOS are just Safari underneath: Because Apple forces all iOS browsers to use the Safari WKWebView engine, keymeid:// usually fails in the exact same jarring way on iOS Chrome if the app isn't installed. If you saw a "YES" for Chrome on iOS, it's likely because the app was already installed on that specific test device, or Chrome intercepted the uninstalled error slightly more gracefully than Safari's terrifying popup.
Android's graceful fallback: Chrome and Firefox on Android support custom schemes so well because Android uses intent:// URIs under the hood. If the app isn't installed, Android can smoothly redirect to the Play Store or a fallback URL without an ugly error. Apple has no equivalent mechanism for custom schemes—only for Universal Links.
Desktop Browsers (Windows/Mac/Linux): You didn't list desktop, but it's worth noting that keymeid:// will fail completely (or do absolutely nothing) on desktop web browsers unless the user happens to have a desktop wallet installed that registered that specific OS-level protocol.
Summary for your UI logic: Apple has essentially killed relying on custom URI schemes (keymeid://) on iOS Web specifically because of that uninstalled error popup. Universal Links (https://one-of-us.net/) are the only way to get a bulletproof, graceful fallback on iOS Safari.

If you want to hide the https option to emphasize the open scheme:

On Android (Native & Web) / iOS (Native): Safe to hide the https link and exclusively show keymeid://.
On Desktop Web: You probably still need the https link, as keymeid:// will be a dead click for 99% of desktop users.
On iOS Web (Safari/Chrome): You must use the https Universal Link to avoid the Safari error bomb if they don't have an app installed.

--------------------

When we know the platform and know that keymeid:// hide the https://one-of-us.net/ from the SignInDialog.


- Hide https://one-of-us.net/ sign in option as the goal is *open* and *heterogeneous*.

- If the user clicks 7 times to reveal the Paste option, then also un-hide the https://one-of-us.net/ option if it was hidden.

- Add a timeout so that if we're trying to sign in and don't receive (through the Firebase collection we're listening to) a response from the app within 5 seconds, show an explanation dialog and also show the https://one-of-us.net/ option if it was previously hidden.
- Add a web page on the https://one-of-us.net/ site if we ended up on the web site because the app wasn't installed explaining the situation, offering the keymeid:// URI to copy and paste, and offering a link to the app store.


## NOTES FOR ME, THE HUMAN - DON'T START WITHOUT ME

Check: TODO, SUSPECT, BUG ..



### relating statements

I used the app to relate 2 Bart's relate statement on El Barto and Marge's dontRelate statement on El Barto. This is what I see in LGTM:

I was expecting JSON subjects, not tokens.
After the statement took effect, I saw that Lisa related the statement to 8 digits of gibberish.
Clacker looked into it had started working on it, but I stopped it.

I should think about relating statements.


### another simpsons demo for a variety of reasons.
I want to add
- reactions on reactions (comment on comment, like  on comment, comment on like, etc..)
- relations (like simpsons_relate_demo)
- plenty of subjects (like the current simpsons_demo)
- some conflicts (like the current simpsons_demo, but different)
- different  conflicts from different PoVs
- different high level data shown from different PoVs
- the ability to use it either fake or emulator and be able to sign in as any person
  I used to be able to do that when using fake using the menus, but I seem to haev lost that ability
  Having that ability when using the emulator would require exporting and saving a file with the full public/private delegate keys
- furthermore, it'd be nice to have the "script" not be a Dart program. I don't want to invent a new language and syntax. Any suggestions?

### ..

- filter/sort content 
  - sort by: most activity (not just comments)

- upgrade related tags to use equivalence tech

- Show Path(s) from PoV on other users, delegate keys (phase 2, 3 from graph doc)

- embed in home page and on aviv.net

Still thinking... ??
- diss + like = show it to me again in case of new likes, comments
  - diss + dislike = never show it to me again
  - diss (no rating) = show me in case of ???

# Probably next - DO NOT GET STARTED.

# longer term - DO NOT GET STARTED ON THESE!

# Nerdster recommends (Have the Nerdster recommend an action)

- Nerdster recommends (Have the Nerdster recommend an action)
  - get in touch with your associate and
    - verify the key you have represents him and has not been compromised (maybe mention a specific action)
    - ask about a different key.
  - scan this key, verify that you've vouched for it
    - add 'suspect' (moves to the end of your direct trusts, hints to others)
    - add generated comment
    - clear it?
    - block it?

# Graph layout, traversal, linking, expansion...

- document this as a requirements doc (for AI)

Lay the graph out better.

- include keys dive in when crypto enabled
  Deal with hugeness:
- fade out nodes beyond 2 degrees, but highlight start of paths.
- scroll through or something when there are too many edges.
  Ditch the shadow view graph entirely.
- visualize the network
  - ideally not as a tree
    - graph that you can drag around: blue, green, red edges
      - only goes 1 or degrees out and then fades, have to change PoV to explore
  - ideally without deprecated libraries
  - ability to link to a person, key, statement
- crypto on
  - keys
  - statements
    - rejected statements
  - link to all statements
- crypto off
  - people
  - paths to them
  - names
  - long press / tooltip to see all names and paths
- actions
  - PoV
  - view/edit follow
  -

# UI regression testing

## implement in cloud

## implement in cloud, Nerdster queries ONE-OF-US.NET

- estimate cost
- prototype performance

# phone rewrite

- consider showing phone interface on web
  - possibly acting as Bart, Lisa.. and affecting the embedded Nerdster
