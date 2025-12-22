# The Nerdster's Trust Algorithm

## Inputs
1.  **Root Key:** The user's Identity Key (Point of View).
2.  **TrustStatements Source:** Source for signed`trust`, `block`, and `replace` TrustStatements, can fetch by public key.

## Outputs
1.  **Trusted Network:** Ordered list of trusted keys and/or their revokeAt value (by distance (degrees away), then re decy).
3.  **Notifications:** Actionable conflicts or key rotations requiring user attention.

It's simple, but not that simple

A key is either possessed by a human and is not compromised, or it isn't.
But 'capable' and 'acting in good faith' are judgement calls.
If a bad actor enters your network, you can block him, or you could block the person (human as he may be) that allowed him in (vouched for him).

In case someone in your network trusts a key and another blocks that key, we have a conflict.

## Goals & Non-Goals
*   **Goal:** Compute some reasonable, consistent, network of trust rooted in PoV (center, Point of View). 
This probably means that we'll 'reject' some statemets.

*   **Goal:** **Social Resolution** of conflicts. 
Notify the user rather than algorithmic guessing.


*   **Non-Goal:** Determining **objective truth** about who's human (unsolvable). 

Goal: confidence levels.
Allow the user to express something like:
- for 1 or 2 degrees away, just 1 path of trust is suficcient
- for 3 or 4 degrees away, require 2 distinct paths of trust.
- for 5 or 6, require 3 distinct paths.

Complexity

The Nerdster is puny and weak. The trust algorithm it will use is not expected to handle more than hundreds.
We want the algorithm to be deterministic, simple to explain, test, and implement.
It's most likely going to be described as "Greedy BFS".

Replace

Stating that your new key replaces and old key does 2 things:
- revokes the key that you're relpacing, which can be used maliciously
- associate your key with the key that you're replacing, which can be used maliciouslly to be followed in the affinity layer, for example.

The tricky part of this problem: treat keys independantly in some ways and as an equivalence group representing a person in other ways.
Not a conflict
- During teh process of adding key to your trusted network we encounter a replace staetemnt claiming to replace a key already in your network.
  Benefit of the doubt: if the replace is legit, then someone directly trusts a key that has been replaced.
  That's not a conflict, but a notification is in order
- During the process of adding key to your trusted network we encounter a replace staetemnt claiming to replace a key that's been blcoked.
  Benefit of the doubt: It may be that the key was hacked, did bad things, and was then correctly replaced by its correct owner.
  Without tracking a blcoking offence (see discussion about 'citing' an offending staetment when blcoking a key), we'll give the benefit of the doubt to the replace statement's author, but not trust the replaced key at all.
  Were we to employ 'citing' the offending statement, we could possibly trust more of that keys history.
  this is not very important: It's easy enoug for a user to restate everything worth restating that was stated using his old, replaced, compromised key. The important thing is to remain associated with it, to retain the identity it provided (like Nerdster follow statements).


## Degrees
*   **Root:** 0 degrees. **Directly Trusted:** 1 degree. **Friends of Friends:** 2 degrees, ...

## Trust order
*   **More Trusted (Closer) -> Head of List**
*   **Less Trusted (Farther) -> Tail of List**

## Trust Algorithm Implementation

### Philosophy & Goals

#### 1. The Unsolvable Problem
The goal of the trust algorithm is **not** to determine objective truth about who is trustworthy. That is an unsolvable problem.
*   **Errors without Conflicts:** Even if there are no conflicting statements (e.g., no one blocks anyone), the network can still contain errors. If you trust Alice, and Alice trusts a spammer, you now have a spammer in your network. There is no algorithmic way to detect this "error" without human judgment.

#### 2. Human Resolution over Heuristics
Instead of employing complex heuristics to "guess" the right answer (e.g., voting systems, minimizing conflicts), the system leans on **Social Resolution**.
*   **Notifications:** When conflicts or suspicious states arise, the system's job is to **Notify** the user.
*   **Action:** The user is expected to resolve the issue soc


### Universal Trust Algorithm Limitations
No trust algorithm can be perfect. This is a variation of the **Byzantine Generals Problem**.
*   **Subjectivity:** Trust is inherently subjective. There is no "objective" truth about who is trustworthy, only who *you* trust.
*   **Conflict:** Contradictory statements (e.g., "A trusts B" vs "C blocks B") are inevitable. Any resolution strategy (e.g., majority vote, shortest path, newest statement) is a heuristic, not a proof.
*   **Key Compromise:** If a private key is stolen, the attacker *is* the user until a revocation/replacement is successfully propagated and observed.

TODO: Maybe incorporate this text:
In case 10 folks I trust trust each other but block someone else that I trust, then they're probably right, but that's complicated to do, and so we don't even try.
