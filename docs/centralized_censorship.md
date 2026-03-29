# Centralized Censorship — Design Notes

Mobile app only (not the web app).

## UX

When a user clicks the censor button, they get a tip / second prompt to also submit the item for centralized moderation.

At that point the subject is "flagged" — put on a list for me to go through and either act on or not.

## Review

I'll manually review flagged items and either accept or reject each.

To make a decision I need to see the subject itself — not just a token (e.g. someone else's censor statement is not itself objectionable). The subject fields should be enough: URL, comment, title, author.

## If Accepted

A token of that subject is added to a centralized list that applies to all app users. Those subjects are always censored and the tokens are cleared from the list during pipeline processing.

## Closed Questions

- What exactly do Apple and Google require here?
https://developer.apple.com/app-store/review/guidelines/#user-generated-content

- Do I need to notify the person who flagged an item if I decline to remove the content?
No.

- Can I give the user a URL immediately after flagging, where the outcome will be shown later?
Not required


## Open Questions
