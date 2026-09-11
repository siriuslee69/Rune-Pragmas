# Rune-Pragmas

The annotations every Nim repository in this workspace hangs on its routines
and its types, in one file that nobody copies.

Installation:

**NixOS / Linux / Windows 11** — there is nothing to build. Clone it beside
the repositories that use it and put its `meta` directory on the Nim path:

```sh
git clone <url> Rune-Pragmas
```

```nim
# config.nims, in the repository that wants it
addPathIfExists(joinPath(repoRoot, "..", "Rune-Pragmas", "meta"))
```

Then, in any file:

```nim
import runePragmas

proc openFrame(A: openArray[byte]): Frame {.role: parser, tag: "ame|wire".} =
  ...
```

That is the whole of it. This repository has no dependencies, no build step
and no client, so depending on it pulls in nothing else.

╭⟢ what the annotations are for 🌊

Otter reads them out of the source text to draw a repository's statistics:
which routines fetch data, which decrypt it, which act on it, how much of the
tree is tested and with what kind of test. A routine with no `role` is
dropped from every chart, which is why the convention is to declare one.

```text
  on a ROUTINE
+---------------+--------------------------------------------------------+
| role          | what the routine is FOR                                |
| input         | where its input came from, when that decides trust     |
| risk          | low | medium | high                                    |
| speed         | fast | medium | long | data-dependent                  |
| stage         | say out loud that a routine is NOT finished            |
| tag           | free-form labels, as a string                          |
| issues        | issue references                                       |
+---------------+--------------------------------------------------------+

  on a TEST
+---------------+--------------------------------------------------------+
| testKind      | what one test is for -- exactly one per test           |
| covers        | which routine(s) a test exercises                      |
| pins          | the bug a regression test holds down                   |
+---------------+--------------------------------------------------------+

  on a TYPE
+---------------+--------------------------------------------------------+
| expectedCount | how many of them are alive at the same time            |
| lifeCycle     | how long ONE of them stays in memory                   |
+---------------+--------------------------------------------------------+
```

╭⟢ writing a tag 🐦‍🔥

One string, pieces separated by `|`:

```nim
tag: "ame|cryptoBoundary|kdf"
```

or a list, where that reads better:

```nim
tag: ["ame", "cryptoBoundary", "kdf"]
```

Both reach the tools as the same three tags. Lower camel case, and no `tag`
prefix on each one — the pragma already says what it is.

**Nothing checks a tag name at compile time.** That is deliberate, and it is
the reason this file can be shared at all. See below.

╭⟢ saying how much of something there will be ⟡

A type says what **one** of them looks like. It never says how many
there are, and that second number is what decides whether a program
fits in memory:

```text
  one object of 400 bytes       ->  400 bytes     nobody cares
  5000 objects of 400 bytes     ->  2 megabytes   now we care
```

Nothing in the source can work that out, because it depends on how the
program is used. The person writing the type knows, so they write it
down:

```nim
type
  AppState* {.role: truthState,
    expectedCount: 1, lifeCycle: lcForever.} = object
    ## one of these, alive from the first line to the last

  Frame* {.role: preparedData,
    expectedCount: [0, 5000], lifeCycle: 100.} = object
    ## up to five thousand at once, each alive about 100ms
```

**Def. 1 — expected count.** How many are alive *at the same time*. Not
how many are ever made. A type that is created and dropped a million
times but only ever has three alive has a count of three.

**Def. 2 — life cycle.** How long **one** of them stays in memory.
Either one of four words, or a plain number meaning milliseconds:

```text
  lcForever   made once at start-up, freed when the program exits
  lcSession   as long as a connection, a login, an open file
  lcJob       one request, one frame, one message
  lcScratch   made and dropped inside one routine
```

The ladder runs longest to shortest, and each step down means the same
memory is handed back and taken again more often. A **pool** is written
as `lcForever` with the pool's size as the count: the objects in it are
reused rather than freed, so the memory never goes back even though
each one is only borrowed for a moment.

╭⟢ how the two are read ❧

```text
  what is written              how it reads
  ---------------------------  --------------------------------
  expectedCount: 1             exactly one
  expectedCount: [0, 5000]     none to five thousand
  expectedCount: [1, -1]       at least one, no ceiling by design
  lifeCycle: lcForever         never freed
  lifeCycle: 100               about a tenth of a second
```

After `lifeCycle:` a digit or a minus sign means milliseconds and a
letter means one of the four words. That is the contract, so a tool
does not have to guess.

Both numbers are estimates and are meant to be. They are written to be
read **together** — a count with no lifetime cannot tell churn from
weight, and a lifetime with no count cannot tell a busy program from an
idle one. Write both or write neither.

╭⟢ why these two are readable and the others are not 🍣

Every other pragma here is overloaded: `tag` takes a string *or* a
list, `role` takes one value *or* a set. An overloaded pragma is two
symbols sharing a name, and Nim's own readers refuse that:

```text
  ambiguous identifier: 'expectedCount' -- you need a helper proc
```

So `expectedCount` and `lifeCycle` are **one** template each, taking
`untyped`. One symbol means a repository can read its own declarations
back while it builds:

```nim
import std/macros

static:
  doAssert Frame.hasCustomPragma(expectedCount)
  echo Frame.getCustomPragmaVal(expectedCount)[1] * sizeof(Frame)
  #     5000                                    * 400  =  2000000
```

`sizeof` there is **exact**. A tool reading the source as text has to
estimate it, and cannot see padding at all. That is what the one-symbol
form buys.

The cost is the same one the tags pay: nothing checks the value, so
`lifeCycle: lcFrever` compiles and is caught when something reads it,
not when somebody writes it. ʚ♡ɞ・the same trade, for the same reason.

╭⟢ why the tags are strings 🍣

They used to be a `MetaTag` enum, and because each repository needed its own
tags, each repository needed its own copy of this file. Two things went wrong
every time, and both are the kind that stay invisible for months.

**Def. 3 — drift.** A copy stops matching the others. One repository's copy
had silently lost the `testKind` and `stage` pragmas altogether and grown two
invented roles. The visible symptom was that 475 of its 487 tests could not
declare a test kind — not because nobody wanted to, but because the pragma
did not exist in the file they were importing.

**Def. 4 — capture.** Two copies, both called `metaPragmas`, both on the Nim
path. Nim resolves a module name by taking the **last** matching `--path`
entry:

```text
  --path:A --path:B     import collide  ->  B's copy
  --path:B --path:A     import collide  ->  A's copy
```

Ordering cannot fix that, because every repository in a build needs its own
list at the same time. Whichever one loses compiles against somebody else's
tags and dies on the first tag of its own, pointing several imports away from
the cause:

```text
  padding.nim(84, 33) Error: undeclared identifier: 'tagCryptoBoundary'
```

Strings remove the reason for the copies. With no per-repository enum left,
this file is the same everywhere, so there is one of it.

The cost is that a misspelled tag now compiles. That check moves to Otter,
which reads every tag string anyway and is better placed to do it: it can see
that `cryptoBoundry` appears once in a tree where `cryptoBoundary` appears
four hundred times, which a compiler cannot.

╭⟢ why `tag` and not `tags` ⌜guide⌟

`tags` is taken. Nim's own effect-tracking pragma owns that name and expects
a type:

```text
  {.tags: "a|b".}   ->  Error: expected type, but got: "a|b"
```

The singular is free, and it is also the key the reading tools already split.

╭⟢ what Otter says about this repository, and why ⌜guide⌟

Measuring this repository reports **18 routines that declare no role**.
That is every pragma template in `meta/runePragmas.nim`, and it is
expected: this is the file that *defines* the annotations, so it cannot
wear them. `role` cannot be hung on `role`.

It also reports all 18 as untested. They are applied as pragmas rather
than called, and the tests in `evaluation/tests/` apply every one of
them — which is the only way a pragma template *can* be exercised.

Both findings are correct readings of a file that is a special case.
Nothing to fix.
