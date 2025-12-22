# Nerdster & ONE-OF-US.NET: Core Concepts

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
*   **Trust-Based Content & Follow Contexts:**
    *   **Humanity First:** Nerdster leverages the Identity Layer to ensure that every user you see is a real person, not a bot or a fake account.
    *   **Follow Network:** While the Identity Layer establishes *who is real*, the Nerdster Application Layer establishes *who is interesting*. You can follow people for specific contexts like 'social', 'local', or 'news'.
    *   **Default Context:** The `<nerdster>` context is a built-in default. By default, you follow the people you have personally vouched for in the Identity Layer.
        *   You can specifically **follow** people you haven't identity-vouched for in the `<nerdster>` context to bring them closer to you.
        *   You can specifically **block** people in the `<nerdster>` context (even if you vouched for their identity) if you aren't interested in their ratings. This also protects those who follow you from seeing their content.
*   **Submitting Content:** Users submit **Content Statements** signed by their delegated app key. Types of statements include:
    *   **Rate:** Expressing an opinion (e.g., "I rate 'The Matrix' 5 stars").
    *   **Comment:** Adding text discussion to a subject.
    *   **Relate:** Linking two subjects together (e.g., "'The Matrix' is related to 'Cyberpunk'"). Supports negative assertions ("not related").
    *   **Equate:** Asserting that two subjects are identical (e.g., "'Sci-Fi' is the same as 'Science Fiction'"). Supports negative assertions ("not the same").
    *   **Conflict Resolution:** Nerdster resolves conflicting statements (e.g., one user says "related", another says "not related") based on who is more trusted in the active context.
*   **Censorship as Protection:** You can "censor" content you find objectionable.
    *   This doesn't delete it from the internet, but it hides it from *your* view.
    *   Crucially, your censorship protects those who follow you. If you are a trusted node for your family or friends, your censorship decisions help filter their feed, creating a community-curated safety layer.

## 3. The Cloud & Data: Portable, Signed Statements

The system treats data differently from traditional web apps. The cloud is not a source of truth, but a convenience for availability.

### Key Concepts:
*   **Portability via Signatures:** A person's statements are trusted because they are **cryptographically signed**, not because of where they are stored. This makes the data portable; it can be moved between servers or stored locally without losing its validity.
*   **Universal Publishing:** Both the Identity App and the Nerdster App publish statements to the cloud so they can be leveraged by other services.
    *   **Every Action is a Statement:** Almost every action you take (vouching, rating, commenting, following) publishes a signed statement. (Exceptions are local preferences).
    *   **Identity as the Anchor:** The core concept is that a person's identity is their public cryptographic key. The Trust Layer distributes the knowledge of *who* these keys belong to.
    *   **Open Ecosystem:** Other services can use these same identity keys but are free to define their own statement formats and behaviors. They can leverage the existing Web of Trust without being bound to Nerdster's specific data standards.
*   **Data Visibility:** All data visible in the apps comes from reading and verifying these published statements. The application constructs its view of the world by aggregating these individual assertions.
*   **The Cloud as a Relay:** Currently, the cloud acts as a "dumb" storage bucket (Firebase/Firestore). It simply stores and serves the signed statements.
    *   **No Central Truth:** The cloud does not calculate who is trusted or what the "average rating" is.
    *   **Verification:** Logic for verifying signatures and calculating the trust graph currently happens on the client, ensuring that the user's view is mathematically derived from their own trust roots.
