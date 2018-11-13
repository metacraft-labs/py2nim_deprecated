mode = ScriptMode.Verbose

packageName   = "py2nim"
version       = "0.1.0"
author        = "Metacraft Labs"
description   = "A Python-to-Nim transpiler"
license       = "MIT"
skipDirs      = @["tests"]

requires "nim >= 0.19.0"

proc configForTests() =
  --hints: off
  --debuginfo
  --path: "."
  --run

task test, "run CPU tests":
  configForTests()
  setCommand "c", "tests/file_test.nim"
