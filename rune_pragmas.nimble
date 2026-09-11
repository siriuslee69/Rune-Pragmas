import std/[os, strutils]

version       = "0.1.0"
author        = "siriuslee69"
description   = "The annotations every Nim repository in this workspace hangs on its code"
license       = "Unlicense"
srcDir        = "meta"
requires "nim >= 2.0.0"

proc resolveProgressPath(): string =
  var
    ts: seq[string] = @[
      "agents/PROGRESS.md",
      "agents/progress.md"
    ]
  for t in ts:
    if fileExists(t):
      return t
  result = ts[0]

proc resolveGitIndexLockPath(): string =
  result = joinPath(".git", "index.lock")

proc resolveAutopushMessagePath(): string =
  result = joinPath(".git", "autopush-commit-message.txt")

proc resolveCommitMessage(progressPath: string): string =
  var msg: string = ""
  if fileExists(progressPath):
    var content = readFile(progressPath)
    for line in content.splitLines:
      if line.startsWith("Commit Message:"):
        msg = line["Commit Message:".len .. ^1].strip()
        break
  if msg.len == 0:
    msg = "No specific commit message given."
  result = msg

proc captureGit(args: string): string =
  ## args: one git subcommand line; output is returned, failure quits.
  var t = gorgeEx("git " & args)
  if t.exitCode != 0:
    if t.output.len > 0:
      echo t.output
    quit(t.exitCode)
  result = t.output

proc isGeneratedOrLocalArtifact(path: string): bool =
  ## path: one staged repo-relative path checked against local/generated outputs.
  var p = path.replace('\\', '/')
  result = splitPath(p).tail.startsWith(".fuse_hidden") or
    p.startsWith("nimcache") or
    p.startsWith("build/") or p.startsWith("builds/") or
    p.startsWith(".gradle/") or p.startsWith(".kotlin/") or
    p.endsWith(".exe") or p.endsWith(".dll") or p.endsWith(".so") or
    p.endsWith(".dylib") or p.endsWith(".o") or p.endsWith(".obj") or
    p.endsWith(".a") or p.endsWith(".lib") or p.endsWith(".pdb") or
    p == "local.properties" or p == "userconfig.toml" or
    p == "nimble.paths" or p == "nimble.develop" or
    p.startsWith("agents/.local")

## ---------------------------------------------------------------------------
## Canonical git workflow tasks <- copy autopush/switch/applyNightly verbatim
## into every repo's .nimble file. Repos work on `nightly` day to day;
## `applyNightly` promotes the tested state onto `main` by fast-forward.
##
##   autopush     -> stage all, refuse generated/local artifacts, commit
##                   with the message from agents/PROGRESS.md, then push
##   switch       -> toggle the checkout between nightly and main
##   applyNightly -> fast-forward main to nightly locally and on origin
## ---------------------------------------------------------------------------

task autopush, "Add, commit, and push after rejecting generated/local artifacts":
  var
    progressPath: string = resolveProgressPath()
    lockPath: string = resolveGitIndexLockPath()
    msg: string = resolveCommitMessage(progressPath)
    msgPath: string = resolveAutopushMessagePath()
    staged: string = ""
  if fileExists(lockPath):
    quit(
      "Refusing to run autopush because Git lock exists at " & lockPath &
      ". If no Git process is active, remove the stale lock and retry."
    )
  exec "git add -A ."
  staged = captureGit("diff --cached --name-only").strip()
  if staged.len == 0:
    echo "No staged changes. Skipping commit."
  else:
    for stagedPath in staged.splitLines:
      if isGeneratedOrLocalArtifact(stagedPath):
        echo "Refusing autopush: generated/local artifact staged: " & stagedPath
        echo "Remove it from the index or extend .gitignore before committing."
        quit(1)
    writeFile(msgPath, msg & "\n")
    exec "git commit --file " & msgPath
  exec "git push"

task switch, "Toggle the working branch between nightly and main":
  var
    branch: string = captureGit("branch --show-current").strip()
    target: string = "nightly"
  if branch == "nightly":
    target = "main"
  echo "Switching from '" &
    (if branch.len > 0: branch else: "(detached HEAD)") &
    "' to '" & target & "'."
  exec "git checkout " & target

task applyNightly, "Promote nightly onto main by fast-forward and push":
  var
    branch: string = captureGit("branch --show-current").strip()
  if branch == "main":
    quit "On 'main'. Run `nimble switch` to move to nightly before applying."
  exec "git fetch . nightly:main"
  exec "git push origin nightly:main"
  echo "main is now at the nightly state; nightly branch left intact."

task find, "Use local clones for submodules in parent folder":
  let modulesPath = ".gitmodules"
  if not fileExists(modulesPath):
    echo "No .gitmodules found."
  else:
    let root = parentDir(getCurrentDir())
    var current = ""
    for line in readFile(modulesPath).splitLines:
      let s = line.strip()
      if s.startsWith("[submodule"):
        let start = s.find('"')
        let stop = s.rfind('"')
        if start >= 0 and stop > start:
          current = s[start + 1 .. stop - 1]
      elif current.len > 0 and s.startsWith("path"):
        let parts = s.split("=", maxsplit = 1)
        if parts.len == 2:
          let subPath = parts[1].strip()
          let tail = splitPath(subPath).tail
          let localDir = joinPath(root, tail)
          if dirExists(localDir):
            let localUrl = localDir.replace('\\', '/')
            exec "git config -f .gitmodules submodule." & current & ".url " & localUrl
            exec "git config submodule." & current & ".url " & localUrl
    exec "git submodule sync --recursive"

## ---------------------------------------------------------------------------
## Repository tasks
## ---------------------------------------------------------------------------

task test, "Compile and run the pragma tests":
  exec "nim c --hints:off --path:meta -r evaluation/tests/test_rune_pragmas.nim"

task smoke, "Compile the pragma module on its own":
  exec "nim c --hints:off --path:meta -o:builds/smoke meta/runePragmas.nim"
