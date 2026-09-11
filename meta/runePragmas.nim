## -------------------------------------------------------------------------
## Rune Pragmas <- the annotations every Nim repository in this workspace
##                 hangs on its routines, in one place
## -------------------------------------------------------------------------
##
## Import it and annotate:
##
##     import runePragmas
##
##     proc openFrame(A: openArray[byte]): Frame {.role: parser,
##         tag: "ame|wire".} =
##       ...
##
## Nothing here is repository-specific, which is the whole point. This file
## used to be copied into every repository with a per-repository `MetaTag`
## enum inside it, and two things went wrong every time:
##
##   1. The copies drifted. One repository's copy had silently lost the
##      `testKind` and `stage` pragmas altogether and grown two invented
##      roles, so 475 of its 487 tests could not declare a kind even if
##      somebody wanted to.
##
##   2. The copies collided. They are all called `metaPragmas`, they all end
##      up on the Nim path together, and Nim takes the LAST `--path` entry
##      that matches a module name. So exactly one repository compiled
##      against its own tag list and the rest silently got that one's, then
##      failed on the first tag their own list had:
##
##          padding.nim(84, 33) Error: undeclared identifier: 'tagCryptoBoundary'
##
## Tags are plain strings here, so there is no per-repository enum left to
## drift or to collide. One file, one copy, every repository.
##
## ╭⟢ writing a tag
##
## One string, pieces separated by `|` (a comma or a semicolon also work):
##
##     tag: "ame|cryptoBoundary|kdf"
##
## or a list, if that reads better where you are:
##
##     tag: ["ame", "cryptoBoundary", "kdf"]
##
## Both reach the tools as the same three tags. Lower camel case, no `tag`
## prefix -- the pragma already says what it is.
##
## Nothing checks a tag name at compile time, on purpose: a fixed enum is
## what forced this file to be copied and edited per repository. Otter reads
## every tag string instead and reports the ones that look like typos.
##
## ╭⟢ saying how much of something there will be
##
## A type says what one of them looks like. It never says how many there
## are, and that second number is the one that decides whether a program
## fits in memory:
##
##     one object of 400 bytes        400 bytes      <- nobody cares
##     5000 objects of 400 bytes      2 megabytes    <- now we care
##
## Nothing in the source text can work that out, because it depends on
## how the program is used. The person writing the type knows it, so
## they write it down:
##
##     type
##       AppState* {.role: truthState,
##         expectedCount: 1, lifeCycle: lcForever.} = object
##         ## one of these, alive from start to finish
##
##       Frame* {.role: preparedData,
##         expectedCount: [0, 5000], lifeCycle: 100.} = object
##         ## up to five thousand at once, each alive about 100ms
##
## `expectedCount` is either an exact number or a `[fewest, most]` pair.
## `lifeCycle` is either one of the `MetaLife` words above, or a plain
## number meaning milliseconds.
##
## The reading contract, so a tool does not have to guess: after
## `lifeCycle:` a digit or a minus sign means milliseconds, and a letter
## means one of the `MetaLife` words. In `expectedCount`, `-1` as the
## second number means there is no ceiling by design.
##
##     what is written              how it reads
##     ---------------------------  --------------------------------
##     expectedCount: 1             exactly one
##     expectedCount: [0, 5000]     none to five thousand
##     expectedCount: [1, -1]       at least one, no ceiling
##     lifeCycle: lcForever         never freed
##     lifeCycle: 100               about a tenth of a second
##
## Both are estimates and are meant to be. They are written to be read
## together - a count with no lifetime cannot tell churn from weight,
## and a lifetime with no count cannot tell a busy program from an idle
## one. Write both or write neither.
##
## Why these two take anything at all, where the others take a type.
## `expectedCount` and `lifeCycle` are ONE template each, with an
## `untyped` parameter, rather than one per shape. An overloaded pragma
## is two symbols with one name, and Nim's own `hasCustomPragma` and
## `getCustomPragmaVal` refuse an overloaded name:
##
##     ambiguous identifier: 'expectedCount' -- you need a helper proc
##
## Keeping it to one symbol means a repository can read its own
## declarations back while it builds, and multiply each by `sizeof(T)`,
## which is exact. A tool reading the source as text can only estimate
## that. The cost is the same one the tags pay: a value nobody checks,
## so `lifeCycle: lcFrever` compiles and is caught on reading, not on
## writing.
##
## ╭⟢ why `tag` and not `tags`
##
## `tags` is taken. Nim's own effect-tracking pragma owns that name and wants
## a type, so `{.tags: "a|b".}` fails with "expected type, but got". The
## singular is free.

type
  MetaRole* = enum
    ## What a routine is FOR. Perceive data, build truth state, act on it.
    helper, math,
    dataFetcher, decryptor, sanitizer, parser, truthBuilder, metaParser,
    actor, orchestrator, metaOrchestrator, encryptor, dataWriter,
    configurator,
    other,
    rawData, preparedData,
    truthState, memory

  MetaInput* = enum
    ## Where a routine's input came from, when that decides how much it is
    ## allowed to trust it.
    user, llm, thirdParty, trusted

  MetaRisk* = enum
    rkLow, rkMedium, rkHigh

  MetaSpeed* = enum
    ## Prefixed, and deliberately not `{.pure.}`. The template these came
    ## from was pure AND shared the name `medium` with MetaRisk, so
    ## `speed: medium` resolved to the risk value and `speed: fast` needed
    ## qualifying -- which is why no repository here ever used `speed`.
    spFast, spMedium, spLong, spDataDependent

  MetaIssue* = tuple
    name: string ## short description or name
    id: uint64   ## issue id/reference
  MetaIssues* = seq[MetaIssue]

  MetaTestKind* = enum
    ## What one test is for. A test carries exactly one of these, so the
    ## suite can be read as a shape rather than a list of names.
    ##
    ##   tkUnit         one proc, ordinary input
    ##   tkEdgeCase     the ends of the range: empty, zero, one, huge
    ##   tkBenchmark    speed or size, measured rather than asserted
    ##   tkRegression   something that broke once and must not again
    ##   tkBugfix       one named bug, pinned by `pins`
    ##   tkIntegration  several parts together
    ##   tkFuzz         random or generated input
    ##   tkSmoke        the thing starts at all
    ##   tkProperty     a law that must hold for every input
    ##   tkOther        anything the list above does not cover
    tkUnit, tkEdgeCase, tkBenchmark, tkRegression, tkBugfix,
    tkIntegration, tkFuzz, tkSmoke, tkProperty, tkOther
  MetaTestKinds* = set[MetaTestKind]

  MetaStage* = enum
    ## How finished one routine is. A routine without this pragma is taken
    ## to be finished; the pragma exists so that a routine that is NOT
    ## finished can say so out loud, instead of being guessed at from the
    ## wording of its body.
    ##
    ##   stStubbed     declared, and does nothing yet
    ##   stPartial     some of it works, some of it does not
    ##   stDeprecated  still here, on its way out
    ##   stDone        finished, said explicitly
    stStubbed, stPartial, stDeprecated, stDone

  MetaLife* = enum
    ## How long ONE of something stays in memory. Written on a type, not
    ## on a routine, and paired with `expectedCount` - the two together
    ## are what turns "this object exists" into "this object costs".
    ##
    ##   lcForever   made once at start-up, freed when the program exits
    ##   lcSession   as long as a connection, a login, an open file
    ##   lcJob       one request, one frame, one message
    ##   lcScratch   made and dropped inside one routine
    ##
    ## The ladder runs from longest to shortest, and each step down means
    ## the same memory is handed back and taken again more often. A pool
    ## is written as `lcForever` with the pool's size as the count: the
    ## objects in it are reused rather than freed, so the memory never
    ## goes back even though each one is borrowed for a moment.
    lcForever, lcSession, lcJob, lcScratch

template input*(x: MetaInput) {.pragma.}
template input*(x: set[MetaInput]) {.pragma.}
template role*(x: MetaRole) {.pragma.}
template role*(x: set[MetaRole]) {.pragma.}
template risk*(x: MetaRisk) {.pragma.}
template speed*(x: MetaSpeed) {.pragma.}
template issues*(x: MetaIssues) {.pragma.}
template stage*(x: MetaStage) {.pragma.}

template tag*(x: string) {.pragma.}
template tag*(x: openArray[string]) {.pragma.}

template testKind*(x: MetaTestKind) {.pragma.}
template testKind*(x: MetaTestKinds) {.pragma.}
template covers*(x: string) {.pragma.}
template covers*(x: seq[string]) {.pragma.}
template pins*(x: MetaIssue) {.pragma.}
template pins*(x: MetaIssues) {.pragma.}

template expectedCount*(x: untyped) {.pragma.}
template lifeCycle*(x: untyped) {.pragma.}
