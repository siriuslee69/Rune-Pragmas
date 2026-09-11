# ============================================================
# | Rune-Pragmas Tests                                       |
# | -> Every annotation compiles, and can be read back       |
# ============================================================
#
# A pragma that does not compile is caught the first time somebody uses
# it. A pragma that compiles but cannot be READ back is not caught at
# all - it looks like it is working right up until a tool tries to use
# it, which may be months later and in another repository. So both are
# checked here.

import std/[macros, strutils, unittest]

import runePragmas

type
  AppState {.role: truthState, tag: "probe",
    expectedCount: 1, lifeCycle: lcForever.} = object
    ## One of these, alive from the first line to the last.
    n: int

  Frame {.role: preparedData, tag: "probe",
    expectedCount: [0, 5000], lifeCycle: 100.} = object
    ## Up to five thousand at once, each one alive about a tenth of a
    ## second. The two numbers together are what says this type is worth
    ## looking at and `AppState` is not.
    b: array[400, byte]

  Conn {.role: memory, tag: "probe",
    expectedCount: [1, -1], lifeCycle: lcSession.} = object
    ## At least one, no ceiling by design - it is however many people
    ## are connected.
    id: int

  Plain = object
    ## Declares nothing. Used to check that "no declaration" is told
    ## apart from "a declaration of zero".
    n: int

proc trimMetaInput(s: string): string {.input({user}), role({helper}),
    risk(rkLow), speed(spFast), tag("probe"), stage(stDone).} =
  ## s: text from a person, with space around it.
  ## The same text, with the space taken off.
  result = s.strip()

proc weightOf(count: int, bytes: int): int {.role: math, tag: "probe".} =
  ## count: how many are alive at once   bytes: the size of one.
  ## What that costs, in bytes. The whole reason the two pragmas exist
  ## is to make this multiplication possible at all.
  result = count * bytes

suite "rune pragmas":

  # {.testKind: tkSmoke.}
  test "every annotation compiles where it belongs":
    check trimMetaInput("  pragma smoke  ") == "pragma smoke"

  # {.testKind: tkUnit.}
  test "a declared count and lifetime can be read back while building":
    ## The point of one symbol per pragma rather than one per shape.
    ## `hasCustomPragma` refuses an overloaded name, so if these two
    ## ever grow an overload this test is what says so.
    static:
      doAssert AppState.hasCustomPragma(expectedCount)
      doAssert AppState.hasCustomPragma(lifeCycle)
      doAssert AppState.getCustomPragmaVal(expectedCount) == 1
      doAssert AppState.getCustomPragmaVal(lifeCycle) == lcForever
    check true

  # {.testKind: tkUnit.}
  test "a count written as a pair reads back as a pair":
    static:
      doAssert Frame.getCustomPragmaVal(expectedCount) == [0, 5000]
      doAssert Conn.getCustomPragmaVal(expectedCount) == [1, -1]
    check true

  # {.testKind: tkUnit.}
  test "a lifetime is either a word or a number of milliseconds":
    static:
      doAssert AppState.getCustomPragmaVal(lifeCycle) == lcForever
      doAssert Conn.getCustomPragmaVal(lifeCycle) == lcSession
      doAssert Frame.getCustomPragmaVal(lifeCycle) == 100
    check true

  # {.testKind: tkEdgeCase.}
  test "a type that declares nothing says so":
    ## "No declaration" and "a declaration of zero" are different
    ## answers, and a tool that cannot tell them apart will report a
    ## program as weighing nothing.
    static:
      doAssert not Plain.hasCustomPragma(expectedCount)
      doAssert not Plain.hasCustomPragma(lifeCycle)
    check true

  # {.testKind: tkUnit.}
  test "the two numbers multiply out to what a type costs":
    ## `sizeof` is exact here, which is the whole advantage of reading
    ## the declaration while building rather than out of the text.
    var
      most: int = 0
      one: int = 0
    static:
      doAssert sizeof(Frame) >= 400
    most = Frame.getCustomPragmaVal(expectedCount)[1]
    one = sizeof(Frame)
    check weightOf(most, one) >= 2_000_000
    check weightOf(AppState.getCustomPragmaVal(expectedCount),
      sizeof(AppState)) == sizeof(AppState)
