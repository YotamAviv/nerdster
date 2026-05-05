# The Nerdster's Trust Algorithm

## Definitions

### Degrees

- **Root:** 0 degrees. **Directly Trusted:** 1 degree. **Friends of Friends:** 2 degrees, ...

### Trust Order

- **More Trusted (Closer) -> Head of List**
- **Less Trusted (Farther) -> Tail of List**

## Algorithm Requirements

### Inputs

1.  **Root Key:** The user's Identity Key (Point of View).
2.  **TrustStatements Source:** Source for signed `trust`, `block`, and `replace` TrustStatements, can fetch by public key.

### Outputs

1.  **Trusted Network:** Ordered list of trusted keys and/or their `revokeAt` value (by distance/degrees away, then recency).
2.  **Notifications:** Actionable conflicts or key rotations requiring user attention.

## It's Simple, But Not That Simple

A key is either possessed by a human and is not compromised, or it isn't.
But 'capable' and 'acting in good faith' are judgement calls.
If a bad actor enters your network, you can block him, or you could block the person (human as he may be) that allowed him in (vouched for him).
And so even though this ONE-OF-US.NET network tries to include all humans, the 'capable and acting in good faith' means that it necessarily isn't the same network from different folks' point of view.

### Conflicts

These are easy to describe:
In case someone in your network trusts a key and another blocks that key, we have a conflict.
It's more complicated when considering replace statements.

## Complexity

The Nerdster is puny and weak. The trust algorithm it will use is not expected to handle more than hundreds.
We want the algorithm to be deterministic, simple to explain, test, and implement.
It's most likely going to be described as "Greedy BFS".

## Philosophy & Goals

### 1. The Unsolvable Problem

The goal of the trust algorithm is **not** to determine objective truth about who is trustworthy. That is unsolvable.

- **Errors without Conflicts:** Even if there are no conflicting statements, the network can still contain errors. If you trust someone, and he trusts a spammer, you now have a spammer in your network. There is no algorithmic way to detect this "error" without human judgment.

### 2. Social Resolution over Heuristics

Instead of employing heuristics to compute a better answer (e.g., voting systems, minimizing conflicts), the system leans on **Social Resolution**.

- **Notifications:** When conflicts or suspicious states arise, the system's job is to **Notify** the user.
- **Action:** The user is expected to resolve the issue socially (e.g., call or visit, and ask).
  In case 10 folks I trust trust each other but block someone else that I trust, then they're probably right, but that's complicated to do, and so we don't even try.

### 3. Goal: Compute a Reasonable Network

Compute some reasonable, consistent, network of trust rooted in PoV (center, Point of View).
This probably means that we'll 'reject' some statements. Each of those probably should generate a notification.

### 4. Goal: Optimize against 'Notification Fatigue'

If there's a rejected statement in your network, that doesn't mean that it's on you to act on it. If it's 5 degrees away, it's probably not on you.
That said, folks may use the phone app and then abandon it. They may be trusted, their trust in other identities should be respected, but they may be unresponsive, which is close to not 'capable'.

When notifying, it would be nice to help the user know what to do, whom to call or visit in person, what to ask.
The recommended action is most likely:

- clear a trust
- block a key

### 5. Goal: Confidence Levels

Allow the user to express something like:

- for 1 or 2 degrees away, just 1 path of trust is sufficient.
- for 3 or 4 degrees away, require 2 distinct paths of trust.
- for 5 or 6, require 3 distinct paths.

#### Definition of "Distinct Paths"

In this algorithm, "distinct" is defined as **Node-Disjoint Paths**. 

- **Requirement:** For a node at distance $D$ to be trusted with a confidence level of $N$, there must exist $N$ paths from the Root to that node such that no two paths share any intermediate nodes.
- **The Bottleneck Rule:** If all paths to a subject pass through a single person (e.g., Alice), then that subject has only **1 distinct path**, regardless of how many people Alice trusts or how many people trust the subject.
- **Greedy Evaluation:** This property is evaluated greedily at each layer. A node is only eligible to be an intermediate node in a path if it has already satisfied its own path requirements at a previous layer.

#### Why Node-Disjoint?

This stricter definition protects the network from "super-connector" vulnerabilities. If you only trust Alice, your network's integrity depends entirely on her. Requiring node-disjoint paths ensures that high-confidence trust is backed by truly independent social chains.

#### Implementation Note

While finding node-disjoint paths is traditionally a Network Flow problem, the Greedy BFS implementation uses an iterative shortest-path search with node removal. This remains efficient for the small values of $N$ (1, 2, or 3) used in the confidence levels.



## Replace Statements

Stating that your new key replaces an old key does 2 things:

- Revokes the key that you're replacing, which can be used maliciously.
- Associates your key with the key that you're replacing, which can be used maliciously to be followed in the affinity layer, for example.

The tricky part of this problem: treat keys independently in some ways and as an equivalence group representing a person in other ways.

### Not a Conflict

- **Replacing a Trusted Key:** During the process of adding a key to your trusted network we encounter a replace statement claiming to replace a key already in your network.

  - **Benefit of the doubt:** If the replace is legit, then someone directly trusts a key that has been replaced.
  - That's not a conflict, but a notification is in order.

- **Replacing a Blocked Key:** During the process of adding a key to your trusted network we encounter a replace statement claiming to replace a key that's been blocked.
  - **Benefit of the doubt:** It may be that the key was hacked, did bad things, and was then correctly replaced by its correct owner.
  - Without tracking a blocking offence (see discussion about 'citing' an offending statement when blocking a key), we'll give the benefit of the doubt to the replace statement's author, but not trust the replaced key at all.
  - Were we to employ 'citing' the offending statement, we could possibly trust more of that key's history.
  - This is not very important: It's easy enough for a user to restate everything worth restating that was stated using his old, replaced, compromised key. The important thing is to remain associated with it, to retain the identity it provided (like Nerdster follow statements).

## Universal Trust Algorithm Limitations

No trust algorithm can be perfect. This is a variation of the **Byzantine Generals Problem**.

- **Subjectivity:** Trust is inherently subjective. There is no "objective" truth about who is trustworthy, only who _you_ trust.
- **Conflict:** Contradictory statements (e.g., "A trusts B" vs "C blocks B") are inevitable. Any resolution strategy (e.g., majority vote, shortest path, newest statement) is a heuristic, not a proof.
- **Key Compromise:** If a private key is stolen, the attacker _is_ the user until a revocation/replacement is successfully propagated and observed.
