import strutils, sequtils, tables, sets, future
import nim_types, gen_kind

type
  NodeKind* = enum
    PyAST, PyAdd, PyAnd, PyAnnAssign, PyAssert, PyAssign, PyAsyncFor, PyAsyncFunctionDef, PyAsyncWith, PyAttribute,
    PyAugAssign, PyAugLoad, PyAugStore, PyAwait, PyBinOp, PyBitAnd, PyBitOr, PyBitXor, PyBoolOp, PyBreak, PyBytes,
    PyCall, PyClassDef, PyCompare, PyConstant, PyContinue, PyDel, PyDelete, PyDict,
    PyDictComp, PyDiv, PyEllipsis, PyEq, PyExceptHandler, PyExpr, PyExpression,
    PyExtSlice, PyFloorDiv, PyFor, PyFormattedValue, PyFunctionDef, PyGeneratorExp, PyGlobal, PyGt, PyGtE,
    PyIf, PyIfExp, PyImport, PyImportFrom, PyIn, PyIndex, PyInteractive, PyInvert, PyIs, PyIsNot,
    PyJoinedStr, PyLShift, PyLambda, PyList, PyListComp, PyLoad, PyLt, PyLtE, Sequence,
    PyMatMult, PyMod, PyModule, PyMult,
    PyName, PyLabel, PyNameConstant, PyNodeTransformer, PyNodeVisitor, PyNonlocal, PyNot, PyNotEq, PyNotIn, PyInt, PyFloat, PyNone,
    PyOr, PyParam, PyPass, PyPow, PyPyCF_ONLY_AST, PyRShift, PyRaise, PyReturn,
    PySet, PySetComp, PySlice, PyStarred, PyStore, PyStr, PySub, PySubscript, PySuite,
    PyTry, PyTuple,
    PyUAdd, PyUSub, PyUnaryOp, PyWhile, PyWith, PyYield, PyYieldFrom, Py_NUM_TYPES, Pyalias, Pyarguments, Pyarg, Pykeyword, Pycomprehension, Pywithitem,
    PyOperator, PyVarDef, PyChar, PyConstr, NimWhen, PyHugeInt, NimRange, NimRangeLess, NimCommentedOut, NimExprColonExpr, NimInfix, NimAccQuoted, NimOf, NimPrefix

  Declaration* {.pure.} = enum Existing, Let, Var, Const

  Node* = ref object
    typ*: Type # The nim type of the node
    debug*: string # Eventually python source?
    idiomatic*: bool # Makes sure a node is converted to an idiom max 1
    line*: int # Line, -1 or actual
    column*: int # Column, -1 or actual
    ready*: bool # Ready for gen
    case kind*: NodeKind:
    of PyStr, PyBytes:
      s*: string
    of PyInt:
      i*: int
    of PyFloat:
      f*: float
    of PyLabel, PyOperator:
      label*: string
    of PyChar:
      c*: char
    of PyHugeInt:
      h*: string
    of PyAssign:
      declaration*: Declaration
    of PyImport:
      aliases*: seq[Node]
    of PyFunctionDef:
      isIterator*: bool
      isMethod*: bool
      calls*: HashSet[string]
      isGeneric*: bool
    else:
      discard
    children*: seq[Node] # complicates everything to have it disabled for several nodes

proc dump*(node: Node, depth: int, typ: bool = false): string =
  if node.isNil:
    return "nil"
  let offset = repeat("  ", depth)
  var left = if node.isNil: "nil" else: ""
  let kind = if node.kind != Sequence: ($node.kind)[2..^1] else: $node.kind
  var typDump = if typ: "#$1" % dump(node.typ, 0) else: ""
  if typDump == "#nil":
    typDump = ""
  if left == "":
    left = case node.kind:
      of PyStr, PyBytes:
        "$1($2)$3" % [kind, node.s, typDump]
      of PyInt:
        "Int($1)$2" % [$node.i, typDump]
      of PyFloat:
        "Float($1)$2" % [$node.f, typDump]
      of PyLabel, PyOperator:
        "Label($1)$2" % [node.label, typDump]
      of PyChar:
        "Char($1)$2" % [$node.c, typDump]
      of PyHugeInt:
        "HugeInt($1)$2" % [node.h, typDump]
      of PyAssign:
        "Assign $1$2:\n$3\n$4" % [$node.declaration, typDump, dump(node.children[0], depth + 1, typ), dump(node.children[1], depth + 1, typ)]
      else:
        "$1$2:\n$3" % [kind, typDump, node.children.mapIt(dump(it, depth + 1, typ)).join("\n")]
  result = "$1$2" % [offset, left]

proc dumpList*(nodes: seq[Node], depth: int): string =
  result = nodes.mapIt(dump(it, depth, true)).join("\n")

proc `[]`*(node: Node, index: int): var Node =
  case node.kind:
  of PyStr, PyBytes, PyInt, PyFloat, PyLabel, PyChar, PyHugeInt:
    raise newException(ValueError, "no index")
  else:
    return node.children[index]

proc `[]=`*(node: var Node, index: int, a: Node) =
  case node.kind:
  of PyStr, PyBytes, PyInt, PyFloat, PyLabel, PyChar, PyHugeInt:
    raise newException(ValueError, "no index")
  else:
    node.children[index] = a

iterator items*(node: Node): Node =
  case node.kind:
  of PyStr, PyBytes, PyInt, PyFloat, PyLabel, PyChar, PyHugeInt:
    discard
  else:
    for child in node.children:
      yield child

iterator mitems*(node: Node): var Node =
  for child in node.children.mitems:
    yield child

iterator nitems*(node: Node): (int, var Node) =
  var z = 0
  for child in node.children.mitems:
    yield (z, child)
    z += 1

proc `$`*(node: Node): string =
  result = dump(node, 0)


proc notExpr*(node: Node): Node =
  result = node
  while result.kind == PyExpr:
    result = result.children[0]

proc testEq*(a: Node, b: Node): bool =
  if a.isNil or b.isNil:
    return false
  elif a.kind == PyExpr or b.kind == PyExpr:
    var newA = notExpr(a)
    var newB = notExpr(b)
    result = testEq(newA, newB)
  elif a.kind != b.kind:
    return false
  else:
    case a.kind:
      of PyStr, PyBytes:
        result = a.s == b.s
      of PyInt:
        result = a.i == b.i
      of PyFloat:
        result = a.f == b.f
      of PyLabel, PyOperator:
        result = a.label == b.label
      of PyChar:
        result = a.c == b.c
      of PyHugeInt:
        result = a.h == b.h
      else:
        if not a.children.isNil and not b.children.isNil:
          if len(a.children) != len(b.children):
            return false
          result = zip(a.children, b.children).allIt(it[0].testEq(it[1]))
        else:
          result = (a.children.isNil or len(a.children) == 0) and (b.children.isNil or len(b.children) == 0)

proc deepCopy*(a: Node): Node =
  if a.isNil:
    return nil
  result = genKind(Node, a.kind)
  case a.kind:
  of PyStr, PyBytes:
    result.s = a.s
  of PyInt:
    result.i = a.i
  of PyFloat:
    result.f = a.f
  of PyLabel:
    result.label = a.label
  of PyHugeInt:
    result.h = a.h
  of PyChar:
    result.c = a.c
  of PyAssign:
    result.declaration = a.declaration
  of PyImport:
    result.aliases = a.aliases.mapIt(deepCopy(it))
  of PyFunctionDef:
    result.isIterator = a.isIterator
    result.isMethod = a.isMethod
    result.calls = a.calls
    result.isGeneric = a.isGeneric
  else:
    discard
  result.children = @[]
  for child in a.children:
    result.children.add(deepCopy(child))

