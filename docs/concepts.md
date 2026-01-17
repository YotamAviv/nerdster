# Nerdster & ONE-OF-US.NET: Core Concepts

## Decentralized Identity Network

The goal is a decentralized identity network where a person's identity is their own public/private cryptographic key pair. The network uses digital signatures to authentically vouch for identities. This information is published by various services where it can be fetched and cryptographically verified by any other service. This allows any participating application to resolve which keys represent which people and how those identities map to **delegate keys** across different services.

## 1. ONE-OF-US.NET: The Identity Layer (Phone App)

**ONE-OF-US.NET** is the foundation of the system. It is a mobile application responsible for managing your cryptographic identity and your relationships with other humans.

It performs the following core functions:

- **Identity Management:** Creates and stores a public/private key pair for a person.
  - The public key serves as the person's identity.
  - The public key QR code is displayed front and center for easy sharing.
- **Vouching (Web of Trust):** Allows scanning other people's identity QR codes to vouch for their humanity and identity.
  - **Criteria:** Uses the standard "human capable and acting in good faith". People not capable of understanding how this works should not be trusted.
  - **Management:** Manages trust statements, supporting updates (changing moniker, comment) or changing the verb from 'trust' to 'block', as well as clearing them.
- **Service Sign-In:** Allows scanning sign-in parameters to authenticate with a service (like Nerdster).
  - Communicates the person's identity to the service via HTTP POST.
  - Offers to create a **Delegate Key** for the service, signing and publishing a delegate statement that authorizes that key to represent the person on that service.
  - Securely communicates the delegate key to the service.
- **Key Rotation:** Allows signing and publishing **Replace Statements**, enabling people to cycle through identity keys if they are lost or compromised.
- **Advanced Scanning:** Allows scanning QR codes for other keys, statement tokens, or entire statements needed for operations like `revokeAt`, `replace`, or `claim delegate`.
- **Clipboard Support:** Copy/paste can be used in place of QR code scanning.

The project codebase is available at: https://github.com/YotamAviv/oneofusv2

### Key Concepts:

- **Self-Sovereign Identity:** You do not have an "account" on a central server. Your identity is a cryptographic **identity key** pair generated and stored securely on your phone.
- **Vouching (The Web of Trust):** The core action in the Identity Layer is **Vouching**.
  - When you meet someone in person, you scan their **identity key** QR code to "vouch" for them.
  - This statement means: _"I certify that this person is a real human being and I know who they are."_
  - These vouching statements form a **Web of Trust**.
- **Delegation:** Your main identity key stays safe on your phone. To use web apps (like Nerdster), you "delegate" a temporary, limited key to that app. If the app key is compromised, you can revoke it from your phone without losing your main identity.

### Identity Statement Hosting

All actions a person carries out using the ONE-OF-US.NET app use their **identity key** to sign a structured **Trust Statement**. These statements are published at `one-of-us.net`, but they are portable; that is they're trusted becuase they're signed by trusted keys, not because they're served by the domain hosting the phone app. Any key's signed statements can be fetched using that key's token (the SHA-1 hash of the public key). This applies to all critical identity actions: `trust`, `block`, `delegate`, and `replace`. Local actions, such as exporting keys or changing UI preferences, do not result in published statements.

## 2. Nerdster: The Application Layer (Web App)

**Nerdster** is a social application built _on top_ of the ONE-OF-US.NET trust network. It is a place to discover, rate, and discuss content (movies, books, etc.).

### Key Concepts:

- **Trust-Based Content & Follow Contexts:**
  - **Humanity First:** Nerdster leverages the Identity Layer to ensure that every user you see is a real person, not a bot or a fake account.
  - **Follow Network:** While the Identity Layer establishes _who is real_, the Nerdster Application Layer establishes _who is interesting_. You can follow people for specific contexts like 'social', 'local', or 'news'.
  - **Default Context:** The `<nerdster>` context is a built-in default. By default, you follow the people you have personally vouched for in the Identity Layer.
    - You can specifically **follow** people you haven't identity-vouched for in the `<nerdster>` context to bring them closer to you.
    - You can specifically **block** people in the `<nerdster>` context (even if you vouched for their identity) if you aren't interested in their ratings. This also protects those who follow you from seeing their content.
- **Submitting Content:** Users submit **Content Statements** signed by their delegated app key. Types of statements include:
  - **Rate:** Expressing an opinion (e.g., "I rate 'The Matrix' 5 stars").
  - **Comment:** Adding text discussion to a subject.
  - **Relate:** Linking two subjects together (e.g., "'The Matrix' is related to 'Cyberpunk'"). Supports negative assertions ("not related").
  - **Equate:** Asserting that two subjects are identical (e.g., "'Sci-Fi' is the same as 'Science Fiction'"). Supports negative assertions ("not the same").
  - **Conflict Resolution:** Nerdster resolves conflicting statements (e.g., one user says "related", another says "not related") based on who is more trusted in the active context.
- **Censorship as Protection:** You can "censor" content you find objectionable.
  - This doesn't delete it from the internet, but it hides it from _your_ view.
  - Crucially, your censorship protects those who follow you. If you are a trusted node for your family or friends, your censorship decisions help filter their feed, creating a community-curated safety layer.

### Subject Identity (Canonicalization)

Nerdster makes a strict distinction between what a subject *is* (its identity) and how it *looks* (its presentation).

- The goal is for different users rating the same thing (e.g., the same news article) to end up with the exact same **Subject Token**.
- For articles, the identity is defined by the **URL**.
- For books and movies, the identity is defined by specific fields like **Title**, **Author**, or **Year**.
- **Images are NEVER part of a subject's identity.** If images were included in the subject definition, two users rating the same book with different cover art would accidentally create two different subjects.
- When "Establishing a Subject" from a URL, we fetch the **Canonical Title** only to ensure the user doesn't have to type it manually (which leads to typos and fragmentation).

### Application Statement Hosting

Just like the ONE-OF-US.NET phone app, the Nerdster web app serves content signed by its **delegate keys** (which users have authorized and associated with their identities) on its domain: `nerdster.org`. These statements are published where they can be fetched using the delegate key's token (the SHA-1 hash of the public key). This applies to all critical application actions: `rate`, `relate`, `equate`, `follow`, and `clear`.

## 3. The Cloud & Data: Portable, Signed Statements

The system treats data differently from traditional web apps. The cloud is not a source of truth, but a convenience for availability.

### Key Concepts:

- **Portability via Signatures:** A person's statements are trusted because they are **cryptographically signed**, not because of where they are stored or from where they are served. This makes the data portable; it can be moved between servers or stored locally without losing its validity.
- **Data Visibility:** All data visible in the apps comes from reading and verifying these published statements. The application constructs its view of the world by aggregating these individual assertions.
- **The Cloud as a Relay:** Currently, the cloud acts as a "dumb" storage bucket (Firebase/Firestore). It simply stores and serves the signed statements.
  - **No Central Truth:** The cloud does not calculate who is trusted or what the "average rating" is.
  - **Verification:** Logic for verifying signatures and calculating the trust graph currently happens on the client, ensuring that the user's view is mathematically derived from their own trust roots.
