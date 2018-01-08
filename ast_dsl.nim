import macros, strformat, strutils, sequtils
import python_ast, python_types

template pyNone*: untyped =
  PythonNode(kind: PyNone)

proc expandLiteral(node: var NimNode): NimNode =
  if node.kind == nnkObjConstr and $(node[0]) == "PythonNode":
    return node
  case node.kind:
  of nnkCharLit:
    result = quote:
      PythonNode(kind: PyChar, c: ' ')
  of nnkIntLit..nnkUInt64Lit:
    result = quote:
      PythonNode(kind: PyInt, i: `node`)
  of nnkFloatLit..nnkFloat128Lit:
    result = quote:
      PythonNode(kind: PyFloat, f: `node`)
  of nnkStrLit..nnkTripleStrLit:
    result = node #quote:
      #PythonNode(kind: PyStr, s: `node`)
  of nnkSym, nnkIdent:
    result = node
  else:
    var z = 0
    result = node
    for child in node:
      var c = child
      result[z] = c.expandLiteral()
      z += 1

macro pyLambda*(args: seq[untyped], argTypes: seq[untyped], a: seq[untyped]): untyped =
  nil

macro attribute*(label: static[string]): untyped =
  let fields = label.split(".")
  let base = newLit(fields[0])
  let field = newLit(fields[1])
  result = quote:
    PythonNode(
      kind: PyAttribute,
      children: @[
        PythonNode(kind: PyLabel, label: `base`),
        PythonNode(kind: PyStr, s: `field`)])

macro attribute*(base: untyped, attr: untyped): untyped =
  var baseL = base
  baseL = baseL.expandLiteral()
  result = quote:
    PythonNode(
      kind: PyAttribute,
      children: @[
        `baseL`,
        PythonNode(kind: PyStr, s: `attr`)])

macro sequence*(args: varargs[untyped]): untyped =
  var elements = quote:
    @[`args`]
  var z = 0
  for element in elements:
    var e = element
    elements[z] = e.expandLiteral()
    z += 1
  result = quote:
    PythonNode(
      kind: Sequence,
      children: `elements`)

macro list*(args: varargs[untyped]): untyped =
  var elements = quote:
    @[`args`]
  var z = 0
  for element in elements:
    var e = element
    elements[z] = e.expandLiteral()
    z += 1
  result = quote:
    PythonNode(
      kind: PyList,
      children: `elements`)

macro assign*(target: untyped, value: untyped, declaration: untyped = nil): untyped =
  var v = value
  v = v.expandLiteral()
  var d = if declaration.isNil: nnkDotExpr.newTree(ident("Declaration"), ident("Existing")) else: declaration
  result = quote:
    PythonNode(
      kind: PyAssign,
      declaration: `d`,
      children: @[
        PythonNode(kind: Sequence, children: @[`target`]),
        `v`])

macro pyVarDef*(target: untyped, value: untyped): untyped =
  var v = value
  v = v.expandLiteral()
  result = quote:
    PythonNode(
      kind: PyAssign,
      children: @[
        PythonNode(kind: Sequence, children: @[`target`]),
        `v`])

macro label*(name: untyped): untyped =
  result = quote:
    PythonNode(
      kind: PyLabel,
      label: `name`)

macro call*(f: untyped, args: untyped, typ: untyped = nil): untyped =
  var children = args
  var z = 0
  if children.kind == nnkPrefix:
    for child in children[1]:
      var c = child
      children[1][z] = c.expandLiteral()
      z += 1
    if children.kind != nnkPrefix:
      children = nnkPrefix.newTree(ident("@"), nnkBracket.newTree(children))
  let t = if typ.isNil: newNilLit() else: typ
  let sequenceNode = quote:
    PythonNode(kind: Sequence, children: `children`)
  result = quote:
    PythonNode(kind: PyCall, children: @[`f`, `sequenceNode`, PythonNode(kind: Sequence, children: @[])], typ: `t`)

template operator*(op: untyped): untyped =
  PythonNode(
    kind: PyOperator,
    label: `op`)

macro compare*(op: untyped, left: untyped, right: untyped, typ: untyped): untyped =
  var (l, r) = (left, right)
  (l, r) = (l.expandLiteral(), r.expandLiteral())
  result = quote:
    PythonNode(
      kind: PyCompare,
      children: @[
        `l`,
        PythonNode(
          kind: Sequence,
          children: @[`op`]),
        PythonNode(
          kind: Sequence,
          children: @[`r`])],
      typ: `typ`)

macro binop*(left: untyped, op: untyped, right: untyped, typ: untyped = nil): untyped =
  var (l, r) = (left, right)
  (l, r) = (l.expandLiteral(), r.expandLiteral())
  let t = if typ.kind == nnkNilLit: newNilLit() else: typ
  result = quote:
    PythonNode(
      kind: PyBinOp,
      children: @[
        `l`,
        `op`,
        `r`],
      typ: `t`)


macro slice*(startA: untyped, finishA: untyped = nil, stepA: untyped = nil): untyped =
  var start = startA
  start = start.expandLiteral()
  var q = quote:
    pyNone()
  var finish = if finishA.isNil: q else: finishA
  var step = if stepA.isNil: q else: stepA
  (finish, step) = (finish.expandLiteral(), step.expandLiteral())
  result = quote:
    PythonNode(
      kind: PySlice,
      children: @[
        `start`,
        `finish`,
        `step`])

macro subscript*(sequenceA: untyped, indexA: untyped): untyped =
  var (sequence, index) = (sequenceA, indexA)
  (sequence, index) = (sequence.expandLiteral(), index.expandLiteral())
  result = quote:
    PythonNode(
      kind: PySubscript,
      children: @[
        `sequence`,
        `index`])

template add*: untyped =
  PythonNode(kind: PyAdd)

template sub*: untyped =
  PythonNode(kind: PySub)

template mult*: untyped =
  PythonNode(kind: PyMult)

template pdiv*: untyped =
  PythonNode(kind: PyDiv)

template eq*: untyped =
  PythonNode(kind: PyEq)

template notEq*: untyped =
  PythonNode(kind: PyNotEq)
