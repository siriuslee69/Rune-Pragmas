# Progress

Commit Message: Let a type say how many of it there will be, and for how long

Features (Planned):
- A reader on the Otter side: multiply each declared count by the type's
  real `sizeof` and rank the tree by what it costs, so the declarations
  turn into a table rather than staying notes.
- A check that a type carrying one of the two also carries the other,
  since either alone cannot tell weight from churn.

Features (Done):
- `role`, `input`, `risk`, `speed`, `issues`, `tag`, `stage` on routines.
- `testKind`, `covers`, `pins` on evaluation routines.
- `expectedCount` and `lifeCycle` on types: how many are alive at once,
  and how long one of them stays. `MetaLife` carries the four words
  (`lcForever`, `lcSession`, `lcJob`, `lcScratch`); a plain number means
  milliseconds instead.
- Six tests, including the readback ones that hold the one-symbol
  decision down.
- A `.nimble` with `test`, `smoke`, and the canonical git tasks.

Features (In Progress):
- None.

Notes:
- Last big change: the two new pragmas are ONE template each taking
  `untyped`, not one per shape like `tag` and `role` are.
- Why, and it was found by trying the obvious thing first: an overloaded
  pragma is two symbols sharing a name, and Nim's own `hasCustomPragma`
  and `getCustomPragmaVal` refuse that outright -
  `ambiguous identifier: 'expectedCount'`. With one symbol a repository
  can read its own declarations back while it builds and multiply them
  by `sizeof(T)`, which is exact; a tool reading the source as text can
  only estimate a size and cannot see padding at all. The cost is that
  the value is unchecked, which is the same trade the tags already make.
- Every other pragma here stays overloaded. Changing them would be a
  break for no gain, since nothing reads them back today - but it does
  mean `hasCustomPragma(tag)` will not work, and that is worth knowing
  before somebody tries it.
