import unittest, macros, os, osproc, strformat, strutils, sequtils

const IGNORE: seq[string] = @[]

macro fileTest(input: static[string], output: static[string]): untyped =
  result = nnkStmtList.newTree()
  var testCase = quote:
    discard execCmd("rm -rf tests/result/")
  result.add(testCase)

  var pythonPaths: seq[string] = @[]
  #echo getCurrentDir()
  let testsDir = "tests/"
  # TODO: compile time getCurrentDir
  let currentDir = "/home/alehander42/python2nim/"
  for _, pythonPath in walkDir(fmt"{testsDir}{input}", true):
    pythonPaths.add(pythonPath)
  echo pythonPaths
  for path in pythonPaths:
    let name = path.rsplit(".", 1)[0]
    let nameNode = newLit(name)
    let pythonNameNode = newLit(fmt"python/{path}")
    let nimNameNode = newLit(fmt"{testsDir}{output}{name}.nim")
    let currentDirNode = newLit(currentDir)
    let testsDirNode = newLit(testsDir)
    if name in IGNORE:
      continue
    testCase = quote:
      test `nameNode`:
        check(execCmd("./py2nim " & `currentDirNode` & `testsDirNode` & `pythonNameNode` & " -o:" & `testsDirNode` & "result/") == 0)
        let expected = readFile(`nimNameNode`).strip()
        let got = readFile(`testsDirNode` & "result/" & `nameNode` & ".nim").strip()
        check(expected == got)
    result.add(testCase)

  # echo result.repr

suite "translate":
  fileTest("python/", "nim/")

