import macros, strformat, strutils, sequtils
import python_ast, python_types

template pyNone*: untyped =
  Node(kind: PyNone)

proc expandLiteral(node: var NimNode): NimNode =
  if node.kind == nnkObjConstr and $(node[0]) == "Node":
    return node
  case node.kind:
  of nnkCharLit:
    result = quote:
      Node(kind: PyChar, c: ' ')
  of nnkIntLit..nnkUInt64Lit:
    result = quote:
      Node(kind: PyInt, i: `node`)
  of nnkFloatLit..nnkFloat128Lit:
    result = quote:
      Node(kind: PyFloat, f: `node`)
  of nnkStrLit..nnkTripleStrLit:
    result = node #quote:
      #Node(kind: PyStr, s: `node`)
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
    Node(
      kind: PyAttribute,
      children: @[
        Node(kind: PyLabel, label: `base`),
        Node(kind: PyStr, s: `field`)])

macro attribute*(base: untyped, attr: untyped, typ: untyped = nil): untyped =
  var baseL = base
  baseL = baseL.expandLiteral()
  let t = if typ.isNil: newNilLit() else: typ
  result = quote:
    Node(
      kind: PyAttribute,
      typ: `t`,
      children: @[
        `baseL`,
        Node(kind: PyStr, s: `attr`)])

macro sequence*(args: varargs[untyped]): untyped =
  var elements = quote:
    @[`args`]
  var z = 0
  for element in elements:
    var e = element
    elements[z] = e.expandLiteral()
    z += 1
  result = quote:
    Node(
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
    Node(
      kind: PyList,
      children: `elements`)

macro assign*(target: untyped, value: untyped, declaration: untyped = nil): untyped =
  var v = value
  v = v.expandLiteral()
  var d = if declaration.isNil: nnkDotExpr.newTree(ident("Declaration"), ident("Existing")) else: declaration
  result = quote:
    Node(
      kind: PyAssign,
      declaration: `d`,
      children: @[
        Node(kind: Sequence, children: @[`target`]),
        `v`])

macro pyVarDef*(target: untyped, value: untyped): untyped =
  var v = value
  v = v.expandLiteral()
  result = quote:
    Node(
      kind: PyAssign,
      children: @[
        Node(kind: Sequence, children: @[`target`]),
        `v`])

macro label*(name: untyped): untyped =
  result = quote:
    Node(
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
    Node(kind: Sequence, children: `children`)
  result = quote:
    Node(kind: PyCall, children: @[`f`, `sequenceNode`, Node(kind: Sequence, children: @[])], typ: `t`)

template operator*(op: untyped): untyped =
  Node(
    kind: PyOperator,
    label: `op`)

macro compare*(op: untyped, left: untyped, right: untyped, typ: untyped): untyped =
  var (l, r) = (left, right)
  (l, r) = (l.expandLiteral(), r.expandLiteral())
  result = quote:
    Node(
      kind: PyCompare,
      children: @[
        `l`,
        Node(
          kind: Sequence,
          children: @[`op`]),
        Node(
          kind: Sequence,
          children: @[`r`])],
      typ: `typ`)

macro binop*(left: untyped, op: untyped, right: untyped, typ: untyped = nil): untyped =
  var (l, r) = (left, right)
  (l, r) = (l.expandLiteral(), r.expandLiteral())
  let t = if typ.kind == nnkNilLit: newNilLit() else: typ
  result = quote:
    Node(
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
    Node(
      kind: PySlice,
      children: @[
        `start`,
        `finish`,
        `step`])

macro subscript*(sequenceA: untyped, indexA: untyped): untyped =
  var (sequence, index) = (sequenceA, indexA)
  (sequence, index) = (sequence.expandLiteral(), index.expandLiteral())
  result = quote:
    Node(
      kind: PySubscript,
      children: @[
        `sequence`,
        `index`])

template add*: untyped =
  Node(kind: PyAdd)

template sub*: untyped =
  Node(kind: PySub)

template mult*: untyped =
  Node(kind: PyMult)

template pdiv*: untyped =
  Node(kind: PyDiv)

template eq*: untyped =
  Node(kind: PyEq)

template notEq*: untyped =
  Node(kind: PyNotEq)
