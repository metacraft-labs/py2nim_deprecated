# maybe we don't need it in the nim part anymore
# but still useful: load the python ast

import macros, strutils, sequtils, strformat, tables
import osproc, json, python_ast, python_types, gen_kind

proc importAst*(ast: JsonNode): PythonNode =
  if ast{"kind"} == nil:
    return nil
  var kind = ($ast{"kind"})[1..^2]
  var node: PythonNode 
  if kind == "PyNone":
    return PythonNode(kind: PyNone)
  for z in low(PythonNodeKind)..high(PythonNodeKind):
    if kind == $z:
      node = genKind(PythonNode, z)
      break
  if node.isNil:
    echo fmt"add {kind} to python_ast.nim"
  case node.kind:
  of PyStr, PyBytes:
    node.s = ($ast{"s"})[1..^2]
  of PyInt:
    node.i = parseInt($ast{"i"})
  of PyFloat:
    node.f = parseFloat($ast{"f"})
  of PyLabel:
    node.label = ($ast{"label"})[1..^2]
  elif ast{"children"} != nil:
    node.children = (ast{"children"}[]).elems.mapIt(importAst(it))
  node.line = parseInt($ast{"line"})
  node.column = parseInt($ast{"column"})
  result = node

