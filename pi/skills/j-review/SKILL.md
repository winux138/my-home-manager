---
name: j-review
description: Pre-review skill based on Julien's preferences.
---

3 levels/kind of PR review, for each, prompt user against which branch to diff against:

## skim

The first and quickest level of reviews.
It consists of reading through the changed code and seeing if anything catches your eye.

The sort of feedback skimming normally results in:
- "There's a smarter way to implement X method"
- "Have you tried using X method from Y library here?"
- "There's an edge case here - are we sure we handle that correctly?"
- "The tests you've written here fails to cover this edge case"

Skimming explicitly doesn't look at anything but the diff, so it generally won't be able to give feedback like:
- Is this refactor adequately covered by our existing tests (under assumptions that the tests haven't been changed)
- How does this feature or modification fit into the larger picture?

Skimming in general is useful for:
- A first look at a large PR if you expect multiple rounds of reviews
- If you have someone who is proficient with the given tech stack but not necessarily the codebase in question.
- Changes to non-critical systems, or where the author has a large amount of confidence that the changes fit well into the big-picture

## regular

This is the level of thoroughness where you not only look at the changed code, but also that everything fits well into the big picture.

For code with UI it will generally also include running the code and trying out the new interface, perhaps also trying to break it for a few minutes.

In a regular review you consider these things (in addition to what you considered in skimming):
- Are there any pieces of logic already in the codebase that the reviewee is re-implementing
- Does the code fit well into the rest of the code in style?
- Should new abstractions be created in light of the new additions?
- Is the refactoring or features adequately covered by tests?

## thorough

Thorough reviews are for critical or security-related code. It's for code that's extremely important to get right for one reason or another, and should probably be used sparingly.

A thorough review essentially does the same thing as a regular review, but spends longer on it. It might consist of:
- Thinking of edge cases, and actively trying to see if you can provoke or exploit them
- Seeing if some feature or functionality needs to be implemented in other files or subsystems
- Spending time attempting to break a user interface
- Considering whether or not this code comes with a heavier maintenance burden than usual and strategies to mitigate it
- Trying out webpages in different browsers
- For performance critical code, comparing or creating benchmarks and providing suggestions for more performant implementations
