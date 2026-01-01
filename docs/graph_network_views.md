# Nerdster Graph Network Views

Visualizing some of the network of trust and interest starting from a Point of View (PoV).

## Requirements

- **Equivalence Groups (EGs)**: Nodes represent people (EGs), not individual keys.
  - Replacement keys are labeled by the system as Homer', Homer'', ...
  - Node Label for an EG is the canonical moniker (e.g., "Homer").
- **Crypto Proofs**: Ability to see the signed statements (trust, follow, etc.) when clicking an edge.
- **Lineage**: Support viewing the `replace` history within an EG (e.g., in a side panel or expanded node view when clicking the EG).
### Support linking to the graph to highlight a person
- **Path of Interest**: When focusing on a specific person, highlight the path(s) from Me to the Target.
  - **Path Count Function**: The number of paths shown depends on the distance (degrees) of the subject from the PoV.

- **Focus on Relevance**: Show relevant paths to the subject and any conflicts (rejected statements) encountered along those paths.

## Identity Mode (Context: `<identity>`)

Shows who has vouched for whom (the Trust Network).
- **Trusts**: Solid green arrows.
- **Blocks**: Red arrows.
- **Replaces**: not shown.
- **Non-canonical Trust**: If a trust statement points to a key that has been replaced (e.g., Lisa trusts Homer'), use a **dotted green arrow**.

## Conflicts

Conflicts represent statements that were rejected by the Trust Algorithm because they contradict the established network or violate safety rules.

- **Visual Encoding**: Orange dashed arrows.
- **Types of Conflicts**:
  - **Root Attack**: Attempting to `block` or `replace` you, the PoV.
  - **Trust Contradiction**: Attempting to `block` an EG that is already reachable via a trust path at a shallower or equal distance.
  - **Double Replacement**: Multiple keys claiming to replace the same old key.
  - **Blocked Statement**: A statement issued by a key that has been blocked (or is downstream of a block).
- **Interaction**: Clicking a conflict edge should explain *why* it was rejected (e.g., "Homer tried to block Marge, but Marge is already trusted by PoV").
- **Discovery**: Conflicts are discovered during the `reduceTrustGraph` process and stored as `TrustNotification` objects. The graph view maps these notifications back to visual edges.

## Follow Mode (Context: `<nerdster>`, `news`, `music`, etc.)

Shows who follows whom within a specific interest context.
- **Switching Context**: Allow the user to change the context and see the graph update.
- **Pure View**: Layout the graph strictly according to the Follow Network of the selected context.

## Navigation & Interaction

- **Focus**: Clicking a person's link in the feed switches the graph to focus on them.
- **Highlighting**: The focused node and the paths leading to it are bolded or highlighted.
- **PoV Shift**: Ability to "become" another node to see the network from their perspective.
- **Node Details**: Tapping a node opens a details dialog showing information relevant to the current context.

### Node Details Logic

The content of the details dialog depends on the currently selected context:

1.  **Context: `<identity>`**
    *   Show incoming **Trust** statements (vouches) targeting this identity.

2.  **Context: Specific (e.g., `news`, `music`)**
    *   Show incoming **Follow/Block** statements that explicitly include the selected context.

3.  **Context: `<nerdster>`**
    *   *Explanation*: The `<nerdster>` context is a hybrid. It includes explicit follows in the `<nerdster>` context AND "virtual" follows derived from the Identity Trust graph (if you trust someone, you implicitly follow them on Nerdster unless you block them).
    *   **Section 1: Explicit Follows**
        *   Show incoming **Follow/Block** statements that explicitly include the `<nerdster>` context.
    *   **Section 2: Implicit Follows (Trust)**
        *   Show incoming **Trust** statements (vouches) *only if* there is no explicit `<nerdster>` follow/block statement from that issuer. (Explicit follows override implicit trust-based follows).

## Integration with Content View

- **Contributor Links**: Clicking a contributor's name in a `ContentCard` opens the graph focused on that person.
- **Crypto Proofs**: Yes, see Node Details above

## Layout Strategy

**Custom Fan Layout**: Avoid stock scatter algorithms. The graph starts with the Root (PoV) at the top left and expands radially (3 PM to 6 PM) down and to the right.
- **Depth-Based Radius**
- **Curved Edges**: Try to maintain the "fan" aesthetic (perhaps using Bezier curves instead of straight lines or elbows)
- **Directional Arrows**: All edges must have arrowheads indicating the direction of trust or follow.

## Implementation Phases

### Phase 1: Show paths to subject node (In Progress)
Show the required number of paths to the subject node (the node clicked in the content view).

### Phase 2: Interesting Edges & Conflicts (Planned)
- **Cross-Path Edges**: If multiple paths exist to the subject, show edges between nodes on different paths.
- **Conflict Visualization**: Show rejected statements (blocks, invalid replaces) that relate to nodes on the paths to the subject.

### Phase 3: Subject-Relative Exploration (Planned)
Allow the user to explore the network from the subject's perspective without fully changing their own PoV.
- **Subject PoV**: Compute a temporary network starting from the subject node using the current settings.
- **Discovery**
