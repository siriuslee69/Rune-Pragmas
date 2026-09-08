# Rune-Pragmas

The annotations every Nim repository in this workspace hangs on its routines,
in one file that nobody copies.

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
+-------------+----------------------------------------------------------+
| role        | what the routine is FOR                                  |
| input       | where its input came from, when that decides trust        |
| risk        | low | medium | high                                      |
| speed       | fast | medium | long | data-dependent                    |
| stage       | say out loud that a routine is NOT finished              |
| tag         | free-form labels, as a string                            |
| issues      | issue references                                         |
+-------------+----------------------------------------------------------+
| testKind    | what one test is for -- exactly one per test             |
| covers      | which routine(s) a test exercises                        |
| pins        | the bug a regression test holds down                     |
+-------------+----------------------------------------------------------+
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

╭⟢ why the tags are strings 🍣

They used to be a `MetaTag` enum, and because each repository needed its own
tags, each repository needed its own copy of this file. Two things went wrong
every time, and both are the kind that stay invisible for months.

**Def. 1 — drift.** A copy stops matching the others. One repository's copy
had silently lost the `testKind` and `stage` pragmas altogether and grown two
invented roles. The visible symptom was that 475 of its 487 tests could not
declare a test kind — not because nobody wanted to, but because the pragma
did not exist in the file they were importing.

**Def. 2 — capture.** Two copies, both called `metaPragmas`, both on the Nim
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
