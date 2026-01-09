# V2 Content Card Design & Interaction Specification

## 1. Conceptual Overview

The `ContentCard` is the atomic unit of the Nerdster feed. It represents a **Subject** (a URL, a concept, a person) and aggregates all **Statements** made about it by the user's trusted network.

### Core Philosophy
- **Subject-Centric**: The card is about the *Subject*, not just a single post.
- **Aggregation**: It combines ratings, comments, and structural relationships (equivalence/relations) from multiple people.
- **Provenance**: Every claim (relation, rating) is attributed to a specific user with cryptographic verification.

---

## 2. Visual Layout & Widget Map

```
+-----------------------------------------------------------------------+
|  [HEADER SECTION]                                                     |
|  [ACTION BAR] [Link Icon] [React Icon] [Score]                        |
|  +---+  Title: "Skateboard"                                           |
|  |IMG|  Type:  resource                                               |
|  +---+  #poignant #horses (Aggregated Tags - Clickable)               |
|         (Click Title -> Open URL or search for subject terms)         |
+-----------------------------------------------------------------------+
|  (History Section - No Title)                                         |
|  Lisa@nerdster.org [👍]                                     [💬] [🛡️]|
|        "It's a vehicle!" (Truncated 1 line)                           |
|  Bart@nerdster.org [≈] "Toy"                                [💬] [🛡️]|
|        (Click "Toy" -> Inspect)                                       |
|  ... (Show all history button if more)                                |
+-----------------------------------------------------------------------+
|  --------------------- Divider -------------------------------------  |
|  (Relationships Section - No Title)                                   |
|  [=] "Transportation"             (Clickable Blue Title)              |
|  [≈] "Art"                        (Clickable Blue Title)              |
|  ... (Show all related button if more)                                |
+-----------------------------------------------------------------------+
```

### Relationships Section Logic
The items in this section are **aggregated (computed) subjects**, not raw user statements.
(So if Subject A is related to Subject B, and Subject B is related to Subject C, then the card for Subject A will display both B and C.)

### Icon Legend & Meanings

| Icon | Name | Meaning / Action |
| :--- | :--- | :--- |
| 🔗 | **Link Icon** | **Toggle Mark** (Currently Disabled). <br>Gray: Inactive.<br>Orange: Active (Subject is "Marked").<br>Used to start a "Relate" or "Equate" action. |
| 💬 | **React Icon** | **My Stance**. <br>Single generic icon (Text Bubble).<br>Gray: You have not reacted.<br>Blue: You have reacted (Like, Comment, Relate, etc).<br>Click to open `RateDialog`. |
| 🛡️ | **Guard Icon** | **Verify**. <br>Shows the statement is cryptographically signed.<br>Click to view raw JSON and signature. |
| @ | **User Link** | **Identity**. <br>Text link (e.g., `Bart@nerdster.org`).<br>Click to focus the Trust Graph on this user. |

### Statement Type Icons (History View)

| Icon | Verb | Meaning |
| :--- | :--- | :--- |
| ≈ | `relate` | Subject is related to another. |
| ≉ | `dontRelate` | Subject is explicitly NOT related (or relation removed). |
| = | `equate` | Subject is equivalent to another. |
| ≠ | `dontEquate` | Subject is explicitly NOT equivalent. |

---

## 3. Symmetric Perspective (Symmetry)

When a statement involves two subjects (Relate/Equate), the UI must shift its perspective to show the "Other" subject relative to the card being viewed. 

- **Example**: A statement says `A = B`.
- **On Card A**: Display text should be ` = B`.
- **On Card B**: Display text should be ` = A`.

This applies even if A and B are categorized in the same Equivalence Group. The card for one literal token must always treat the other token as the target.

---

## 4. Use Cases

### UC1: Inspecting Related/Equated Content
**Goal**: Bart is looking at "Science" and sees it is related to "Math". He wants to see what "Math" is about.

1.  **Find Link**: Bart sees "Math" in the "Related" list of the "Science" card.
2.  **Click**: Bart clicks the word "Math".
3.  **Inspect**: A bottom sheet slides up displaying the **"Math" Content Card**.
    *   *Constraint*: This MUST open the Inspection Sheet. It should not just expand/collapse or do nothing.
4.  **Interact**: Bart can rate "Math" directly in this sheet.
5.  **Dismiss**: Bart swipes the sheet down to return to "Science".

*Note: This also applies to "Equivalents" (Equated content). Clicking an equated subject opens the Inspection Sheet for that specific subject.*

### UC2: Relating Two Subjects (The "Mark & Relate" Workflow)
*(Note: The Link Icon is currently disabled in the UI as of recent updates. This workflow is preserved for future re-enablement.)*
**Goal**: Bart wants to say "Science" is related to "Math".

1.  **Find Subject A**: Bart finds the card for **"Science"**.
2.  **Mark**: Bart clicks the **Link Icon** (🔗) on the "Science" card.
    *   *Feedback*: The icon turns **Orange**. "Science" is now the "Marked Subject".
3.  **Find Subject B**: Bart scrolls to find **"Math"**.
4.  **Relate**: Bart clicks the **Link Icon** (🔗) on the "Math" card.
5.  **Dialog**: The `RelateDialog` opens automatically.
    *   *Title*: "Relate Science to Math?"
    *   *Options*: [Relate] [Equate] [Cancel]
6.  **Confirm**: Bart clicks **[Relate]**.
7.  **Result**: A new `ContentStatement` (verb: `relate`) is published. The "Science" card now lists "Math" under the "Related" section.

### UC3: Contradicting a Relation (Un-relating)
**Goal**: Lisa thinks "Science" is NOT related to "Math" (or wants to undo a relation).

1.  **Find Subject**: Lisa finds **"Science"**.
2.  **See Relation**: She sees "Math" listed in the "Related" section.
3.  **Mark**: She clicks the **Link Icon** (🔗) next to "Math" *inside the Related list*.
    *   *Feedback*: "Math" is marked (Orange).
4.  **Target**: She clicks the **Link Icon** (🔗) on the main "Science" card header.
5.  **Dialog**: `RelateDialog` opens: "Relate Math to Science?".
6.  **Action**: She selects **[Don't Relate]** (or [Un-relate] if she authored the original).
7.  **Result**: A `dontRelate` statement is published. If she is the viewer, the relation disappears or is marked as contested.

### UC4: Reacting to a Relation (Comment/Rate)
**Goal**: Homer liked "Donuts". Marge wants to comment on Homer's like. Or, Marge wants to comment on Bart's relation between "Science" and "Math".

1.  **Expand History**: Marge clicks "Show all history" (if the item is hidden).
2.  **Find Statement**: She sees "Bart related to 'Math'".
3.  **React**: She clicks the **Rate Icon** (💬) *on Bart's row* in the history.
4.  **Dialog**: `RateDialog` opens for *Bart's Statement*.
5.  **Action**: Marge types "I disagree!" and clicks [Post].
6.  **Constraint**: Users cannot "Dismiss" a relation. The code ignores dismiss actions on structural statements.

---

## 4. Widget Hierarchy (Implementation Map)

*   `ContentCard` (StatefulWidget)
    *   `Card` (Container)
        *   `Column`
            *   **Header**:
                *   **Action Bar**: `Row` (Link Button, Rate Button, Score) - *Top Right*
                *   **Content**: `ListTile` (Title, Image)
                    *   **Tags**: `Wrap` of clickable `#tag` text (Under Type)
            *   **History Section**:
                *   `Column` of `StatementTile` widgets (Shows top 2 by default)
                *   "Show all history" button (if > 2 items) - Expands to show full list
            *   **Divider**
            *   **Relationships Section**:
                *   `Column` of custom `Row` widgets (Icon + Clickable Title) (Shows top 2 by default)
                *   "Show all related" button (if > 2 items) - Expands to show full list

## 5. Navigation Logic

*   **Clicking Title**:
    *   *If URL*: Open in browser.
    *   *If Text*: Search for subject terms.
*   **Clicking Related Item Title**:
    *   **Action**: Open **Inspection Sheet** (Modal Bottom Sheet).
    *   *Behavior*: Shows the full card for the related subject in a sheet that covers ~85% of the screen. Background is dimmed.
*   **Clicking Equated Item Title (in Equivalents)**:
    *   **Action**: Open **Inspection Sheet** (Modal Bottom Sheet).
    *   *Behavior*: Same as above. Allows inspecting the hidden/merged subject.
*   **Clicking User Link (e.g., Bart@nerdster.org)**:
    *   **Action**: Navigate to `NerdyGraphView`.
    *   *Behavior*: Focuses the Trust Graph on that user.
*   **Clicking Guard Icon**:
    *   **Action**: Show `AlertDialog` with raw JSON.

## 6. Statement Display Logic (History)

The text displayed in the history list depends on the statement's verb and content. 

### Dynamic Perspective (Symmetry)
For binary statements (`relate`, `equate`, etc.), the UI must pivot the display relative to the **literal card** being viewed.
- If Subject A is viewed and a statement says `A = B`, show **"= B"**.
- If Subject B is viewed and the *same* statement is shown, show **"= A"**.
- **Rule**: Use the literal subject token of the current card to determine which side of the statement is "Self" and which is "Other".

| Verb | Condition | Icon(s) | Display Text |
| :--- | :--- | :--- | :--- |
| `rate` | `comment` is not empty | 💬 | Comment text |
| `rate` | `like` == true | 👍 | *None* |
| `rate` | `like` == false | 👎 | *None* |
| `relate` | - | ≈ | "[Other Subject]" |
| `equate` | - | = | "[Other Subject]" |
| `dontRelate` | - | ≉ | "[Other Subject]" |
| `dontEquate` | - | ≠ | "[Other Subject]" |
| *Any* | Fallback | ❓ | *None* |

*Note: "Reacted" should only be used as a fallback if no other condition matches.*

## 7. Inspection Sheet Behavior

The **Inspection Sheet** is a modal view that allows users to "peek" at another subject without losing their place in the feed.

*   **Context**: The sheet slides up over the current card.
*   **Interaction**: The card inside the sheet is fully functional (Rate, Link, View History).
*   **Closing**: Swipe down or tap the dimmed background to close.
*   **Navigation**: If the user clicks a Related item *inside* the Inspection Sheet, it replaces the content of the sheet (or pushes a new sheet, depending on depth preference - simpler is replacing).

## Implementation Plan

1.  **Refine `ContentCard` Layout**:
    - Implement the "Header / History (Top 2 + Expand) / Relationships (Top 2 + Expand)" structure.
2.  **Fix History Display**:
    - Update `_buildStatementTile` to show the `verb` (Rate, Relate, Equate) and the `other` subject if applicable.
3.  **Improve Navigation**:
    - Make the Title of related/equated items clickable -> Open **Inspection Sheet**.
4.  **Visual Feedback**:
    - Ensure the Link Icon turns Orange when active.

---

## Note on Icons
The `💬` emoji used in this document is a visual placeholder. The actual implementation uses the Flutter vector icon `Icons.rate_review_outlined`.
