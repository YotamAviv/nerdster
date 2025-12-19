# Nerdster & ONE-OF-US.NET: Core Concepts

This document outlines the high-level architecture and philosophy of the system, distinguishing between the Identity Layer (ONE-OF-US.NET) and the Application Layer (Nerdster).

## 1. ONE-OF-US.NET: The Identity Layer (Phone App)

**ONE-OF-US.NET** is the foundation of the system. It is a mobile application responsible for managing your cryptographic identity and your relationships with other humans.

It performs the following core functions:
*   **Identity Management:** Creates and stores a public/private key pair for a person.
    *   The public key serves as the person's identity.
    *   The public key QR code is displayed front and center for easy sharing.
*   **Vouching (Web of Trust):** Allows scanning other people's identity QR codes to vouch for their humanity and identity.
    *   **Criteria:** Uses the standard "human capable and acting in good faith". People not capable of understanding how this works should not be trusted.
    *   **Management:** Manages trust statements, supporting updates (changing moniker, comment) or changing the verb from 'trust' to 'block', as well as clearing them.
*   **Service Sign-In:** Allows scanning sign-in parameters to authenticate with a service (like Nerdster).
    *   Communicates the person's identity to the service via HTTP POST.
    *   Offers to create a **Delegate Key** for the service, signing and publishing a delegate statement that authorizes that key to represent the person on that service.
    *   Securely communicates the delegate key to the service.
*   **Key Rotation:** Allows signing and publishing **Replace Statements**, enabling people to cycle through identity keys if they are lost or compromised.
*   **Advanced Scanning:** Allows scanning QR codes for other keys, statement tokens, or entire statements needed for operations like `revokeAt`, `replace`, or `claim delegate`.
*   **Clipboard Support:** Copy/paste can be used in place of QR code scanning.

The project codebase is available at: https://github.com/YotamAviv/oneofus

### Key Concepts:
*   **Self-Sovereign Identity:** You do not have an "account" on a central server. Your identity is a cryptographic key pair generated and stored securely on your phone.
*   **Vouching (The Web of Trust):** The core action in ONE-OF-US.NET is **Vouching**.
    *   When you meet someone in person, you scan their QR code to "vouch" for them.
    *   This statement means: *"I certify that this person is a real human being and I know who they are."*
    *   These vouching statements form a **Web of Trust**.
*   **Delegation:** Your main identity key stays safe on your phone. To use web apps (like Nerdster), you "delegate" a temporary, limited key to that app. If the app key is compromised, you can revoke it from your phone without losing your main identity.

## 2. Nerdster: The Application Layer (Web App)

**Nerdster** is a social application built *on top* of the ONE-OF-US.NET trust network. It is a place to discover, rate, and discuss content (movies, books, etc.).

### Key Concepts:
*   **Trust-Based Content:** Unlike traditional social networks that use algorithms to show you "engaging" content, Nerdster uses your **Web of Trust**.
    *   You see ratings and comments from people you trust, and people *they* trust.
    *   Spammers and bots are naturally filtered out because no real human in your network has vouched for them.
*   **Submitting Content:** Users submit **Content Statements** (Ratings, Comments, Relations).
    *   *Example:* "I rate 'The Matrix' 5 stars."
    *   These statements are signed by your delegated app key.
*   **Censorship as Protection:** You can "censor" content you find objectionable.
    *   This doesn't delete it from the internet, but it hides it from *your* view.
    *   Crucially, your censorship protects those who trust you. If you are a trusted node for your family, your censorship decisions can help filter their feed.

## 3. The Cloud: Dumb Storage, Smart Clients

The system uses the cloud, but differently from traditional web apps.

### Key Concepts:
*   **The Cloud is a Relay:** The cloud server (Firebase/Firestore) is a "dumb" storage bucket. It simply stores the signed statements (Trust Statements and Content Statements) uploaded by users.
*   **No Central Truth:** The cloud does not calculate who is trusted or what the "average rating" is. It doesn't know or care.
*   **Client-Side Logic:** All the intelligence lives in the **Client** (your phone or browser).
    *   Your app downloads the raw statements.
    *   Your app calculates the Trust Graph from *your* Point of View (PoV).
    *   Your app filters and sorts the content based on *your* calculated trust network.
    *   This means two different users might see different content or different ratings for the same movie, based on who they trust.
