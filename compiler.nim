import
  strformat, os, strutils, sequtils, tables, json,
  python_ast, python_types, nim_types, core, env, tracer,
  ast_parser, ast_dsl, generator, module, deduckt_db, helpers,
  idioms/[idioms_dsl, operators, string_methods, list_methods]

type
  Pass* {.pure.} = enum AST, Generation

  Compiler* = object
    db*: DeducktDb
    command: string
    asts*: Table[string, PythonNode]
    modules*: Table[string, Module]
    maybeModules*: Table[string, bool]
    stack*: seq[(string, seq[(Type, string)])]
    path*: string
    envs*: Table[string, Env]
    untilPass*: Pass
    generated*: Table[string, string]
    currentModule*: string
    currentClass*: Type
    currentFunction*: string
    base*: string

proc newCompiler*(db: DeducktDb, command: string): Compiler =
  result = Compiler(db: db, command: command)

proc moduleOf*(compiler: Compiler, name: string): string =
  let tokens = compiler.currentModule.split(".")
  var m: seq[string] = @[]
  for z, token in tokens:
    if token == compiler.db.package:
      m = tokens[z..^1]
      break
  m.add(name)
  result = m.join(".")

proc compileNode*(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode

proc mergeFunctionTypeInfo(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode

proc replaceNode(node: PythonNode, original: PythonNode, newNode: PythonNode): PythonNode

proc registerImport(compiler: var Compiler, label: string)

proc typed(node: var PythonNode, typ: Type): PythonNode =
  node.typ = typ
  result = node

proc collapse(node: PythonNode): seq[PythonNode] =
  case node.kind:
  of Sequence:
    result = @[]
    for child in node.children.mitems:
      result = result.concat(collapse(child))
  else:
    result = @[node]

proc compileModule*(compiler: var Compiler, file: string, node: PythonNode): Module =
  var moduleEnv = compiler.envs[file]
  var childNodes: seq[PythonNode] = @[]
  for child in node.mitems:
    childNodes.add(compiler.compileNode(child, moduleEnv))
  var collapsedNodes: seq[PythonNode] = @[]
  for child in childNodes.mitems:
    collapsedNodes = collapsedNodes.concat(collapse(child))
  result = compiler.modules[file]
  for child in collapsedNodes:
    case child.kind:
    of PyImport:
      result.imports.add(child)
    of PyClassDef:
      result.types.add(child)
    of PyFunctionDef:
      result.functions.add(child)
    else:
      result.init.add(child)

proc compileImport(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # store imports
  # by default make them false in maybeModules:
  # only if the module is used, toggle it
  assert node.kind == PyImport
  if node[0].kind == Pyalias and node[0][0].kind == PyStr:
    compiler.maybeModules[node[0][0].s] = false
    result = PythonNode(kind: PyImport, children: @[pyLabel(node[0][0].s)])
  else:
    warn("import")
    result = PythonNode(kind: Sequence, children: @[])

proc compileImportFrom(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # from x import original
  #
  # import x
  #
  # from x import original as alias
  #
  # import x
  # alias = original

  if node.kind != PyImportFrom or node[0].kind != PyStr:
    return PythonNode(kind: Sequence, children: @[])
  let m = node[0].s
  var aliases: seq[PythonNode] = @[]
  for child in node[1]:
    if child.kind == Pyalias:
      assert child[0].kind == PyStr
      let original = child[0].s
      let alias = if child[1].kind == PyStr: child[1].s else: original
      let fullName = fmt"{compiler.db.package}.{m}#{original}"
      if compiler.db.types.hasKey(fullName):
        env[alias] = compiler.db.types[fullName]
      if original != alias:
        aliases.add(assign(label(alias), attribute(label(m), original), Declaration.Var))
  result = PythonNode(kind: PyImport, children: @[pyLabel(m)], aliases: aliases)
  compiler.maybeModules[fmt"{compiler.base}/{m}.py"] = true

proc compileAssign(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  let value = compiler.compileNode(node[1], env)
  if len(node[0].children) > 1:
    warn("assign")
  elif node[0][0].kind == PyLabel:
    var label = node[0][0].label
    node[1] = value
    if not env.types.hasKey(label):
      node.declaration = Declaration.Var
    env[label] = value.typ
  elif node[0][0].kind == PySubscript:
    node[0][0] = compiler.compileNode(node[0][0], env)
    node[1] = value
  result = node

proc compilePrint(compiler: var Compiler, name: string, args: seq[PythonNode], env: var Env): PythonNode =
  # variadic
  var printArgs = args
  # for z, arg in args:
  #   if arg.typ != T.String:
  #     printArgs[z] = call(label("$"), @[arg], T.String)
  result = call(label("echo"), printArgs, T.Void)

proc compileSpecialStrMethod(compiler: var Compiler, name: string, args: seq[PythonNode], env: var Env): PythonNode =
  result = call(label("$"), args, T.String)

proc compileLen(compiler: var Compiler, name: string, args: seq[PythonNode], env: var Env): PythonNode =
  var a: seq[PythonNode] = @[]
  for arg in args:
    var arg2 = arg
    a.add(compiler.compileNode(arg2, env))
  if len(a) != 1:
    result = call(PythonNode(kind: PyLabel, label: name), a, NIM_ANY)
  else:
    result = call(PythonNode(kind: PyLabel, label: name), a, T.Int)

proc compileReversed(compiler: var Compiler, name: string, args: seq[PythonNode], env: var Env): PythonNode =
  if len(args) == 1:
    result = call(PythonNode(kind: PyLabel, label: name), args, args[0].typ)
    compiler.registerImport("algorithm")
  else:
    result = call(PythonNode(kind: PyLabel, label: name), args, NIM_ANY)

proc compileIsinstance(compiler: var Compiler, name: string, args: seq[PythonNode], env: var Env): PythonNode =
  result = PythonNode(kind: NimOf, children: args, typ: T.Bool)

proc compileInt(compiler: var Compiler, name: string, args: seq[PythonNode], env: var Env): PythonNode =
  result = call(PythonNode(kind: PyLabel, label: name), args, T.Int)

var BUILTIN* = {
  "print": "echo"
}.toTable()

var SPECIAL_FUNCTIONS* = {
  "print": compilePrint,
  "str": compileSpecialStrMethod,
  "len": compileLen,
  "reversed": compileReversed,
  "isinstance": compileIsinstance,
  "int": compileInt
}.toTable()

proc compileCall*(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  let function = compiler.compileNode(node[0], env)
  let args = compiler.compileNode(node[1], env)
  if function.typ.isNil and (function.kind != PyLabel or function.label notin SPECIAL_FUNCTIONS):
    warn("failed to determine type of function:\n" & $node)
    function.typ = NIM_ANY

  if function.kind == PyAttribute:
    assert function[1].kind == PyStr
    result = maybeApplyMethodIdiom(node, function[0], function[1].s, args.children)
  elif function.kind == PyLabel:
    if function.label in SPECIAL_FUNCTIONS:
      result = SPECIAL_FUNCTIONS[function.label](compiler, function.label, args.children, env)
    else:
      result = maybeApplyMethodIdiom(node, nil, function.label, args.children)
  else:
    result = node
  if result.isNil: # no idiom
    result = node
    if function.typ.kind == N.Function:
      result.typ = function.typ.returnType
    else:
      if function.typ.kind == N.Any:
        result.typ = function.typ
      elif function.typ.kind == N.Record:
        result.kind = PyConstr
        result[2] = result[1]
        var members: seq[PythonNode] = @[]
        for member, _ in function.typ.members:
          members.add(label(member))
        result[1] = PythonNode(kind: Sequence, children: members)
        result.typ = function.typ
      else:
        # echo fmt"wtf {function.typ}"
        result.typ = function.typ

proc compileLabel*(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  assert node.kind == PyLabel
  if node.label in SPECIAL_FUNCTIONS:
    result = node
  elif node.label == "True" or node.label == "False":
    result = PythonNode(kind: PyLabel, label: node.label.toLowerAscii(), typ: T.Bool)
  elif node.label == "None":
    result = PY_NIL
  else:
    var typ = env.get(node.label)
    if typ.isNil:
      typ = env.get(fmt"{compiler.currentModule}.{node.label}")
    result = typed(node, typ)

proc compileStr(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = typed(node, T.String)

proc compileInt(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = typed(node, T.Int)

proc compileHugeInt(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = typed(node, T.HugeInt)

proc compileFloat(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = typed(node, T.Float)

proc compileConstant(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = typed(node, T.Bool)

proc compileExpr(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = compiler.compileNode(node[0], env)

proc compileBinOp(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  var left = compiler.compileNode(node[0], env)
  var right = compiler.compileNode(node[2], env)
  let op = node[1]
  if left.typ == T.Float and right.typ == T.Int:
    right = call(attribute(right, "float"), @[], T.Float)
  elif left.typ == T.Int and right.typ == T.Float:
    left = call(attribute(left, "float"), @[], T.Float)
  elif left.typ.isNil or left.typ.kind == N.Any:
    left.typ = right.typ
  elif right.typ.isNil or right.typ.kind == N.Any:
    right.typ = left.typ
  node[0] = left
  node[2] = right
  result = node
  if left.typ == T.Int or left.typ == T.Float:
    result.typ = left.typ
    # TODO:
    result = applyOperatorIdiom(result)
  else:
    result = applyOperatorIdiom(result)

proc pureConstr(compiler: var Compiler, node: var PythonNode): bool =
  let args = node[1][0].mapIt(it[0].s)
  for child in node[2]:
    if child.kind != PyAssign or len(child[0].children) != 1 or child[0][0].kind != PyAttribute or
       child[0][0][0].kind != PyLabel or child[0][0][0].label != "self" or child[0][0][1].kind != PyStr or
       child[0][0][1].s notin args or child[1].kind != PyLabel or child[1].label != child[0][0][1].s:
       return false
  return true

proc translateInit(compiler: var Compiler, node: var PythonNode, env: var Env, child: bool = false, assignments: seq[PythonNode] = @[]): PythonNode =
  result = node
  if not child:
    result[0].s = compiler.currentClass.init
    result[1][0].children = result[1][0].children[1..^1]
    result.typ.functionArgs = result.typ.functionArgs[1..^1]
    result.typ.returnType = compiler.currentClass
    result[2].children = assignments.concat(result[2].children)
    if compiler.currentClass.isRef:
      result[2].children = @[call(label("new"), @[label("result")])].concat(result[2].children)


  case node.kind:
  of PyLabel:
    if node.label == "self":
      result.label = "result"
  else:
    var z = 0
    for next in result.mitems:
      result[z] = compiler.translateInit(next, env, true)
      z += 1

proc replaceReturnYield(node: PythonNode): PythonNode =
  if node.kind == PyReturn:
    return PythonNode(kind: PyYield, children: node.children)
  else:
    result = node
    var z = 0
    for child in node:
      result[z] = replaceReturnYield(child)
      z += 1

proc compileFunctionDef(compiler: var Compiler, node: var PythonNode, env: var Env, assignments: seq[PythonNode] = @[], fTyp: Type = nil): PythonNode =
  assert node.kind == PyFunctionDef

  var f = node[0]
  assert f.kind == PyStr # TODO: label
  var label = f.s

  let typ = if fTyp.isNil: env.get(label) else: fTyp
  if typ.isNil or typ.kind notin {N.Overloads, N.Function}:
    return PythonNode(kind: Sequence, children: @[])
  elif typ.kind == N.Overloads:
    result = PythonNode(kind: Sequence, children: @[])
    for overload in typ.overloads:
      # echo fmt"compile {overload}"
      result.children.add(compiler.compileFunctionDef(node, env, fTyp=overload))
    return
  var isInit = false
  if label == "__init__":
    if len(assignments) == 0 and compiler.pureConstr(node):
      compiler.currentClass.init = ""
      return PythonNode(kind: Sequence, children: @[])
      # TODO mark it so we can use PyConstr
      # and rename to newType, change return type and remove self otherwise
      # idiomatic function
    else:
      if compiler.currentClass.isRef:
        compiler.currentClass.init = fmt"new{compiler.currentClass.label}"
      else:
        compiler.currentClass.init = fmt"make{compiler.currentClass.label}"
      isInit = true
  elif label == "__len__":
    label = "len"
    node[0].s = label
  elif label == "__getitem__":
    label = "[]"
    node[0] = PythonNode(kind: NimAccQuoted, children: @[PythonNode(kind: PyLabel, label: label)])
  elif label == "__setitem__":
    label = "[]="
    node[0] = PythonNode(kind: NimAccQuoted, children: @[PythonNode(kind: PyLabel, label: label)])
  elif label == "__iter__":
    if len(node[2].children) != 1 or not node[2][0].testEq(PythonNode(kind: PyReturn, children: @[PythonNode(kind: PyLabel, label: "self")])):
      warn("def __iter__(self): return self only supported")
    result = PythonNode(kind: Sequence, children: @[])
    return
  elif label == "__next__":
    node[2] = replaceReturnYield(node[2])
    node[2] = replaceNode(node[2], PythonNode(kind: PyRaise, children: @[call(PythonNode(kind: PyLabel, label: "StopIteration"), @[], T.Void), PY_NIL]), PythonNode(kind: PyBreak, children: @[]))
    node[2] = PythonNode(
      kind: Sequence,
      children: @[
        PythonNode(
          kind: PyWhile,
          children: @[pyBool(true), node[2]])])
    label = "items"
    node[0].s = label
    typ.functionArgs[0].isVar = true
    node.isIterator = true
  elif label == "__enter__":
    label = "enter"
    node[0].s = label
    typ.functionArgs[0].isVar = true
  elif label == "__exit__":
    label = "exit"
    node[0].s = label
    typ.functionArgs[0].isVar = true
    if len(typ.functionArgs) == 4:
      typ.functionArgs[1] = Type(kind: N.Atom, label: "Exception", isRef: true)
      typ.functionArgs[2] = Type(kind: N.Atom, label: "Exception", isRef: true)
      typ.functionArgs[3] = T.String
  elif label == "__str__":
    label = "$"
    node[0] = PythonNode(kind: NimAccQuoted, children: @[PythonNode(kind: PyLabel, label: label)])

  var args = initTable[string, Type]()
  var z = 0
  for v in node[1][0]:
    assert v.kind == Pyarg and v[0].kind == PyStr
    # echo node[1][0]
    args[v[0].s] = typ.functionArgs[z]
    z += 1

  var functionEnv = childEnv(env, label, args, typ.returnType)
  compiler.currentFunction = typ.fullLabel

  var sequence = node[2]
  assert sequence.kind == Sequence

  z = 0
  for child in sequence.children.mitems:
    sequence.children[z] = compiler.compileNode(child, functionEnv)
    z += 1

  compiler.currentFunction = ""

  if functionEnv.hasYield:
    node.isIterator = true
  if isInit:
    result = compiler.translateInit(node, env, assignments=assignments)
  else:
    result = node

proc compileAttribute*(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = node
  var base = compiler.compileNode(node[0], env)
  var typ = base.typ
  if typ.isNil or typ.kind == N.Any:
    result.typ = NIM_ANY # TODO: experiment with just generating the same code for some nodes
    #fail(fmt"no type for node {node}")
    return
  var fullName = typ.label
  var oldTyp = typ
  if typ.kind == N.Atom:
    fullName = fmt"{compiler.currentModule}.{typ.label}"
    typ = env.get(fullName)
    if typ.isNil and compiler.db.types.hasKey(fullName):
      typ = compiler.db.types[fullName]
      env[fullName] = typ
    elif typ.isNil:
      typ = oldTyp

  if typ.kind == N.Record:
    assert node[1].kind == PyStr
    if node[1].s notin typ.members:
      var methodName = fmt"{compiler.currentModule}.{typ.label}#{node[1].s}"
      if methodName notin compiler.db.types:
        warn(fmt"no type for {node[1].s} in {fullName}")
        methodName = fmt"{compiler.currentModule}#{node[1].s}"
        if methodName notin compiler.db.types:
          warn(fmt"no type for {node[1].s} in {fullName}")
          result.typ = NIM_ANY
        else:
          result.children[0] = base
          result.typ = compiler.db.types[methodName]
      else:
        result.children[0] = base
        result.typ = compiler.db.types[methodName]
    else:
      result.children[0] = base
      result.typ = typ.members[node[1].s]
  else:
    result.typ = NIM_ANY
  if not result.typ.isNil and result.typ.kind == N.Function and len(result.typ.functionArgs) == 1:
    if result.typ.functionArgs[0].kind == N.Atom:
      result.typ = result.typ.returnType
    elif result.typ.functionArgs[0].kind == N.Record and result.typ.functionArgs[0].members.hasKey(node[1].s):
      result.typ = result.typ.returnType

proc compileSequence*(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = node
  var z = 0
  for child in result.children.mitems:
    result.children[z] = compiler.compileNode(child, env)
    z += 1

proc compileList*(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = node
  var z = 0
  for child in result.children.mitems:
    result[z] = compiler.compileNode(child, env)
    z += 1
  if len(result.children) > 0:
    result.typ = seqType(result[0].typ)
  else:
    result.typ = seqType(NIM_ANY)


proc compileReturn(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  node[0] = compiler.compileNode(node[0], env)
  if node[0].typ != env.returnType:
    warn(fmt"{compiler.currentFunction} expected {$env.returnType} got {$node[0].typ} return")
  result = node

proc compileIf(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = node
  if node[0].kind == PyCompare and node[0][0].kind == PyLabel and
     node[0][0].label == "__name__" and
     node[0][1][0].kind == PyEq and node[0][2][0].kind == PyStr and node[0][2][0].s == "__main__":
    result.kind = NimWhen
    result[0] = PythonNode(kind: PyLabel, label: "isMainModule", typ: T.Bool)
  else:
    result[0] = compiler.compileNode(node[0], env)
    if result[0].typ != T.Bool:
      warn(fmt"expected bool got {$result[0].typ} if")
  result[1] = compiler.compileNode(node[1], env)

proc compileCompare(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # TODO: compound compare
  var left = compiler.compileNode(node[0], env)
  var op = node[1][0]
  var right = compiler.compileNode(node[2][0], env)
  if not (
      left.typ == T.Int and right.typ == T.Int or
      left.typ == T.Float and right.typ == T.Float or
      op.kind == PyEq or op.kind == PyNotEq):
    warn(fmt"{$op} {$left.typ} {$right.typ}")
  result = node
  result.typ = T.Bool


proc createInit(compiler: var Compiler, assignments: seq[PythonNode]): PythonNode =
  if compiler.currentClass.isRef:
    compiler.currentClass.init = fmt"new{compiler.currentClass.label}"
  else:
    compiler.currentClass.init = fmt"make{compiler.currentClass.label}"
  result = PythonNode(
    kind: PyFunctionDef,
    children: @[
      PythonNode(kind: PyStr, s: compiler.currentClass.init),
      PythonNode(kind: Pyarguments, children: @[PythonNode(kind: Sequence, children: @[]), PY_NIL, PythonNode(kind: Sequence, children: @[])]),
      PythonNode(kind: Sequence, children: assignments),
      PY_NIL])
  result.typ = Type(kind: N.Function, label: compiler.currentClass.init, functionArgs: @[], returnType: compiler.currentClass)

proc compileClassDef(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  assert node[0].kind == PyStr
  let label = node[0].s
  var typ = env[label]
  compiler.currentClass = typ
  compiler.currentClass.init = ""

  node[0] = PythonNode(kind: PyLabel, label: label)

  if node[1].kind == Sequence and len(node[1].children) > 0:
    if len(node[1].children) == 1 and node[1][0].kind == PyLabel:
      typ.base = env.get(node[1][0].label)
      if typ.base.isNil:
        typ.base = Type(kind: N.Atom, label: node[1][0].label)

  result = node

  if len(node[3].children) > 0:
    result = PythonNode(kind: Sequence, children: @[result])

    var classEnv = childEnv(env, label, initTable[string, Type](), nil)

    var z = 0
    var assignments: seq[PythonNode] = @[]
    for child in node[3].mitems:
      if child.kind == PyFunctionDef:
        node[3][z] = compiler.mergeFunctionTypeInfo(child, classEnv)
      elif child.kind == PyAssign and len(child[0].children) == 1 and child[0][0].kind == PyLabel:
        var value = compiler.compileNode(child[1], classEnv)
        assignments.add(assign(attribute(PythonNode(kind: PyLabel, label: "result"), child[0][0].label), value))
        if not typ.members.hasKey(child[0][0].label):
          typ.members[child[0][0].label] = value.typ
      z += 1

    z = 0
    var hasInit = false
    for child in node[3].mitems:
      if child.kind == PyFunctionDef:
        if child[0].kind == PyLabel and child[0].label == "__init__":
          hasInit = true
        result.children.add(compiler.compileFunctionDef(child, classEnv, assignments))
      z += 1
    if not hasInit and len(assignments) > 0:
      result.children.add(compiler.createInit(assignments))
  compiler.currentClass = nil

proc replaceFile(compiler: var Compiler, node: var PythonNode, handler: string, filename: PythonNode): PythonNode =
  result = nil
  if node.kind == PyCall and node[0].kind == PyAttribute and node[0][0].kind == PyLabel and 
     node[0][0].label == handler:
    result = nil
    if node[0][1].s == "read" and len(node[1].children) == 0:
      result = call(label("readFile"), @[filename], T.String)
      result.ready = true
    elif node[0][1].s == "write" and len(node[1].children) == 1:
      let arg = node[1][0]
      result = call(label("writeFile"), @[filename, arg], T.Void)
      result.ready = true
  if result.isNil:
    result = node
    var z = 0
    for child in node.mitems:
      result[z] = compiler.replaceFile(child, handler, filename)
      z += 1

proc compileWith(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # with open(filename, mode) as f:
  #    code .. 
  #    f.read() / f.write(source) 
  #   .. code
  #
  # is translated to 
  # 
  # code .. 
  # readFile() / writeFile(source)
  # .. code 
  # TODO: append etc
  # TODO: other common context
  
  assert node.kind == PyWith

  assert node[0][0].kind == Pywithitem

  var header = node[0][0][0]
  var handler = node[0][0][1]
  var code = node[1]
  if header.kind == PyCall and header[0].kind == PyLabel and header[0].label == "open" and
     handler.kind == PyLabel:
    let filename = header[1][0]
    result = compiler.replaceFile(code, handler.label, filename)
    result = compiler.compileNode(result, env)
  else:
    result = PythonNode(
      kind: PyWith,
      children: @[
        PythonNode(
          kind: Pywithitem,
          children: @[
            compiler.compileNode(header, env),
            compiler.compileNode(handler, env)]),
        compiler.compileNode(code, env)])
    compiler.registerImport("py2nim_helpers")

proc compileFor*(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # for element in a:
  #   code
  # 
  # doesn't change
  #
  # for z, element in enumerate(a):
  #   code
  #
  # becomes
  #
  # for z, element in a:
  #   code
  #
  # for k, v in a.items(): # a is dict
  #    code
  #
  # becomes
  #
  # for k, v in a:
  #   code
  #
  # for z in range([start], finish, [step]):
  #   code
  #
  # becomes
  #
  # for z in [start]..<finish: / for z in countup(start, finish, step):
  #   code
  # TODO
  # else

  let element = node[0]
  let sequence = node[1]
  let code = node[2]

  if sequence.kind == PyCall and sequence[0].kind == PyAttribute and sequence[0][1].kind == PyStr and sequence[0][1].s == "items":
    let candidateDict = compiler.compileNode(sequence[0][0], env)
    if candidateDict.typ.isDict():
      node[1] = candidateDict
      if element.kind == PyLabel:
        element.typ = candidateDict.typ.args[0]
        env[element.label] = element.typ
      elif element.kind == PyTuple and element[0].kind == PyLabel and element[1].kind == PyLabel:
        element[0].typ = candidateDict.typ.args[0]
        element[1].typ = candidateDict.typ.args[1]
        env[element[0].label] = element[0].typ
        env[element[1].label] = element[1].typ
  elif sequence.kind == PyCall and sequence[0].kind == PyLabel and sequence[0].label == "enumerate":
    let candidateList = compiler.compileNode(sequence[1][0], env)
    if candidateList.typ.isList():
      node[1] = candidateList
      if element.kind == PyTuple and element[0].kind == PyLabel and element[1].kind == PyLabel:
        element[0].typ = T.Int
        element[1].typ = candidateList.typ.args[0]
        env[element[0].label] = element[0].typ
        env[element[1].label] = element[1].typ
  elif sequence.kind == PyCall and sequence[0].kind == PyLabel and sequence[0].label == "range":
    var start: PythonNode
    var finish: PythonNode
    if len(sequence[1].children) == 1:
      start = pyInt(0)
      finish = sequence[1][0]
      node[1] = PythonNode(kind: NimRangeLess, children: @[start, finish])
    elif len(sequence[1].children) == 2:
      start = sequence[1][0]
      finish = sequence[1][1]
      node[1] = PythonNode(kind: NimRangeLess, children: @[start, finish])
    elif len(sequence[1].children) == 3:
      node[1][0].label = "countup"
    if element.kind == PyLabel:
      element.typ = T.Int
      env[element.label] = element.typ
  else:
    node[1] = compiler.compileNode(node[1], env)
  node[2] = compiler.compileNode(node[2], env)

  result = node

proc registerImport(compiler: var Compiler, label: string) =
  var module = compiler.modules[compiler.path]
  for imp in module.imports.mitems:
    if imp.children[0].label == label:
      return

  compiler.modules[compiler.path].imports.add(PythonNode(kind: PyImport, children: @[PythonNode(kind: PyLabel, label: label)], aliases: @[]))

proc compileDict(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  if len(node[0].children) > 0:
    node[0] = compiler.compileNode(node[0], env)
    node[1] = compiler.compileNode(node[1], env)
    node.typ = tableType(node[0][0].typ, node[1][0].typ)
  else:
    node.typ = tableType(NIM_ANY, NIM_ANY)
  result = node
  compiler.registerImport("tables")

proc toBool(test: PythonNode): PythonNode =
  if test.typ == T.Bool:
    result = test
  elif test.typ == T.Int:
    result = compare(notEq(), test, 0, T.Bool)
  elif test.typ == T.Float:
    result = compare(notEq(), test, 0.0, T.Bool)
  elif test.typ == T.String:
    result = compare(notEq(), test, pyString(""), T.Bool)
  else:
    result = PythonNode(kind: PyUnaryOp, children: @[operator("not"), call(attribute(test, "isNil"), @[], T.Bool)], typ: T.Bool)

proc compileWhile(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  var test = compiler.compileNode(node[0], env)
  if test.typ != T.Bool:
    test = toBool(test)
  node[0] = test
  node[1] = compiler.compileNode(node[1], env)
  result = node

proc commentedOut(s: string): PythonNode =
  result = PythonNode(kind: NimCommentedOut, children: @[PythonNode(kind: PyStr, s: s, typ: T.String)], typ: NIM_ANY)

proc replaceNode(node: PythonNode, original: PythonNode, newNode: PythonNode): PythonNode =
  if node.testEq(original):
    result = newNode
  else:
    result = node
    var z = 0
    for child in node.mitems:
      result[z] = replaceNode(child, original, newNode)
      z += 1

proc compileListComp(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # [code for element in a]
  #
  # becomes
  #
  # a.mapIt(code) # element becomes it
  #
  # [code for element in a if test]
  #
  # becomes
  #
  # a.filterIt(test).mapIt(code) # element becomes it
  

  assert node[1][0].kind == Pycomprehension and node[1][0][3].kind == PyInt and node[1][0][3].i == 0
  
  let sequence = compiler.compileNode(node[1][0][1], env)
  if not sequence.typ.isList():
    warn("list comprehension on {$sequence.typ}")
    return commentedOut($node)
  var element = node[1][0][0]
  var code = node[0]
  if element.kind != PyLabel:
    warn("only list comprehension with `element` in supported")
    return commentedOut($node)    
  let types = {"it": sequence.typ.args[0]}.toTable()
  var codeEnv = childEnv(env, "<code>", types, nil)
  var mapIt = replaceNode(code, element, PythonNode(kind: PyLabel, label: "it"))
  let mapCode = compiler.compileNode(mapIt, codeEnv)
  if len(node[1][0][2].children) > 0:
    var test = node[1][0][2][0]
    var filterIt = replaceNode(test, element, PythonNode(kind: PyLabel, label: "it"))
    let filterCode = compiler.compileNode(filterIt, codeEnv)
    result = call(attribute(call(attribute(sequence, "filterIt"), @[filterCode]), "mapIt"), @[mapCode], seqType(mapCode.typ))
  else:
    result = call(attribute(sequence, "mapIt"), @[mapCode], seqType(mapCode.typ))
  compiler.registerImport("sequtils")

proc compileGeneratorExp(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # for now we'll just close our eyes and send it to our brother to translate it
  result = compiler.compileListComp(node, env)


proc compileDictComp(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # {k: v for k, v in dict.items()}
  #
  # becomes
  #
  # dict.mapTable(k:v) # k and v are magical
  #
  # {k: v for element in list}
  #
  # becomes
  #
  # list.mapTable(k:v) # element becomes it 

  var sequence: PythonNode
  if node[2][0][1].kind == PyCall and node[2][0][1][0].kind == PyAttribute and
     node[2][0][1][0][1].kind == PyStr and node[2][0][1][0][1].s == "items":
    sequence = compiler.compileNode(node[2][0][1][0][0], env)
  else:
    sequence = compiler.compileNode(node[2][0][1], env)
  if not sequence.typ.isDict() and not sequence.typ.isList():
    warn("dict comp without dict or list not supported")
    return commentedOut($node)

  var element = node[2][0][0]
  var key = node[0]
  var value = node[1]
  var types: Table[string, Type]
  var keyReplaced: PythonNode
  var valueReplaced: PythonNode
  var test: PythonNode
  if len(node[2][0][2].children) > 0:
    test = node[2][0][2]

  if sequence.typ.isList() and element.kind == PyLabel:
    types = {"it": sequence.typ.args[0]}.toTable()
    keyReplaced = replaceNode(key, element, PythonNode(kind: PyLabel, label: "it"))
    valueReplaced = replaceNode(value, element, PythonNode(kind: PyLabel, label: "it"))
    if not test.isNil:
      test = replaceNode(test, element, PythonNode(kind: PyLabel, label: "it"))
  elif sequence.typ.isDict() and element.kind == PyTuple and element[0].kind == PyLabel and element[1].kind == PyLabel:
    types = {"k": sequence.typ.args[0], "v": sequence.typ.args[1]}.toTable()
    keyReplaced = replaceNode(key, element[0], PythonNode(kind: PyLabel, label: "k"))
    keyReplaced = replaceNode(keyReplaced, element[1], PythonNode(kind: PyLabel, label: "v"))
    valueReplaced = replaceNode(value, element[0], PythonNode(kind: PyLabel, label: "k"))
    valueReplaced = replaceNode(value, element[1], PythonNode(kind: PyLabel, label: "v"))
    if not test.isNil:
      test = replaceNode(test, element[0], PythonNode(kind: PyLabel, label: "k"))
      test = replaceNode(test, element[1], PythonNode(kind: PyLabel, label: "v"))
  var base: PythonNode
  var codeEnv = childEnv(env, "<code>", types, nil)
  if test.isNil:
    base = sequence
  else:
    let testCode = compiler.compileNode(test, codeEnv)
    base = call(attribute(sequence, "filterTable"), @[testCode])
  let keyCode = compiler.compileNode(keyReplaced, codeEnv)
  let valueCode = compiler.compileNode(valueReplaced, codeEnv)

  result = call(attribute(base, "mapTable"), @[PythonNode(kind: NimExprColonExpr, children: @[keyCode, valueCode])], tableType(keyCode.typ, valueCode.typ))
  compiler.registerImport("tables")
  compiler.registerImport("py2nim_helpers")


let EXCEPTIONS = {
  "IndexError": "IndexError",
  "ValueError": "ValueError",
}.toTable()

proc compileException(compiler: var Compiler, label: string, env: var Env): PythonNode =
  if EXCEPTIONS.hasKey(label):
    result = PythonNode(kind: PyLabel, label: EXCEPTIONS[label])
  else:
    result = PythonNode(kind: PyLabel, label: label)

proc compileTry(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # try:
  #   code
  # except E as e:
  #   print(e)
  #   handler
  #
  # becomes
  #
  # try:
  #   code
  # except NimE:
  #   echo getCurrentExceptionMsg()
  #   handler
  #
  # TODO finally
  result = PythonNode(kind: PyTry, children: @[])
  var code = compiler.compileNode(node[0], env)
  result.children.add(code)
  result.children.add(PythonNode(kind: Sequence, children: @[]))
  for handler in node[1]:
    if handler.kind == PyExceptHandler:
      var exception = handler[0]
      if exception.kind == PyLabel:
        exception = compiler.compileException(exception.label, env)
      else:
        exception = compiler.compileNode(exception, env)
      var e = handler[1]
      var handlerCode = compiler.compileNode(handler[2], env)
      if e.kind == PyStr:
        handlerCode = replaceNode(handlerCode, PythonNode(kind: PyLabel, label: e.s), call(PythonNode(kind: PyLabel, label: "getCurrentExceptionMsg"), @[], T.String))
      result[1].children.add(PythonNode(kind: PyExceptHandler, children: @[exception, handlerCode]))

proc compileSubscript(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  node[0] = compiler.compileNode(node[0], env)
  node[1] = compiler.compileNode(node[1], env)
  var typ: Type
  if node[0].typ.isList() and node[1].typ == T.Int:
    typ = node[0].typ.args[0]
  elif node[0].typ.isDict() and node[1].typ == node[0].typ.args[0]:
    typ = node[0].typ.args[1]
  elif node[0].typ == T.String:
    typ = T.Char
  elif node[0].typ == T.Bytes:
    typ = T.Int
  elif not node[0].typ.fullLabel.isNil:
    var getitem = fmt"{node[0].typ.fullLabel}#__getitem__"
    if compiler.db.types.hasKey(getitem):
      typ = compiler.db.types[getitem]
      if typ.kind == N.Function:
        typ = typ.returnType
      else:
        typ = NIM_ANY
    else:
      typ = NIM_ANY
  else:
    typ = NIM_ANY
  result = typed(node, typ)

proc compileIndex(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  if len(node.children) == 1:
    result = compiler.compileNode(node[0], env)
  else:
    warn node

proc compileRaise(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  var exception: PythonNode
  var arg: PythonNode
  if node[0].kind == PyCall:
    if node[0][0].kind == PyLabel:
      exception = compiler.compileException(node[0][0].label, env)
    else:
      exception = node[0][0]
    if len(node[0][1].children) > 0:
      arg = node[0][1][0]
    else:
      arg = pyString("")
  else:
    exception = PythonNode(kind: PyLabel, label: "Exception")
    arg = node[0]
  result = PythonNode(kind: PyRaise, children: @[call(PythonNode(kind: PyLabel, label: "newException"), @[exception, arg], T.Void)], typ: T.Void)

proc compileAugAssign(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  var operator = case node[1].kind:
    of PyAdd: "+="
    of PySub: "-="
    of PyMult: "*="
    of PyFloorDiv: "div"
    else: "?"
  var left = compiler.compileNode(node[0], env)
  var right = compiler.compileNode(node[2], env)
  if operator[^1] != '=':
    result = assign(left, binop(left, PythonNode(kind: PyLabel, label: operator), right))
  else:
    result = PythonNode(kind: NimInfix, children: @[PythonNode(kind: PyLabel, label: operator), left, right], typ: T.Void)

proc compileBytes(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = typed(node, T.Bytes)

proc compileYield(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  node[0] = compiler.compileNode(node[0], env)
  result = node
  env.hasYield = true

proc compileBreak(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = node

proc parseOp(node: PythonNode): string =
  case node.kind:
  of PyLabel:
    result = node.label
  of PyAnd:
    result = "and"
  of PyOr:
    result = "or"
  else:
    result = $node.kind

proc compileBoolOp(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  var z = 0
  for child in node[1].mitems:
    child = compiler.compileNode(child, env)
    node[1][z] = toBool(child)
    z += 1
  
  let label = parseOp(node[0])
  result = node[1][0]
  for z in 1..<len(node[1].children):
    var right = node[1][z]
    result = binop(result, operator(label), right, typ=T.Bool)

proc compileNode*(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # TODO: write a macro
  # echo fmt"compile {node.kind}"
  try:
    if node.ready:
      result = node
      return
    case node.kind:
    of PyImport:
      result = compiler.compileImport(node, env)
    of PyImportFrom:
      result = compiler.compileImportFrom(node, env)
    of PyAssign:
      result = compiler.compileAssign(node, env)
    of PyCall:
      result = compiler.compileCall(node, env)
    of PyLabel:
      result = compiler.compileLabel(node, env)
    of PyStr:
      result = compiler.compileStr(node, env)
    of PyInt:
      result = compiler.compileInt(node, env)
    of PyHugeInt:
      result = compiler.compileHugeInt(node, env)
    of PyFloat:
      result = compiler.compileFloat(node, env)
    of PyConstant:
      result = compiler.compileConstant(node, env)
    of PyExpr:
      result = compiler.compileExpr(node, env)
    of PyBinOp:
      result = compiler.compileBinOp(node, env)
    of PyFunctionDef:
      result = compiler.compileFunctionDef(node, env)
    of PyAttribute:
      result = compiler.compileAttribute(node, env)
    of Sequence:
      result = compiler.compileSequence(node, env)
    of PyList:
      result = compiler.compileList(node, env)
    of PyReturn:
      result = compiler.compileReturn(node, env)
    of PyIf:
      result = compiler.compileIf(node, env)
    of PyCompare:
      result = compiler.compileCompare(node, env)
    of PyClassDef:
      result = compiler.compileClassDef(node, env)
    of PyPass:
      result = PY_NIL
    of PyNone:
      result = PY_NIL
    of PyWith:
      result = compiler.compileWith(node, env)
    of PyFor:
      result = compiler.compileFor(node, env)
    of PyDict:
      result = compiler.compileDict(node, env)
    of PyWhile:
      result = compiler.compileWhile(node, env)
    of PyListComp:
      result = compiler.compileListComp(node, env)
    of PyGeneratorExp:
      result = compiler.compileGeneratorExp(node, env)
    of PyDictComp:
      result = compiler.compileDictComp(node, env)
    of PyTry:
      result = compiler.compileTry(node, env)
    of PySubscript:
      result = compiler.compileSubscript(node, env)
    of PyIndex:
      result = compiler.compileIndex(node, env)
    of PyRaise:
      result = compiler.compileRaise(node, env)
    of PyAugAssign:
      result = compiler.compileAugAssign(node, env)
    of PyBytes:
      result = compiler.compileBytes(node, env)
    of PyYield:
      result = compiler.compileYield(node, env)
    of PyBreak:
      result = compiler.compileBreak(node, env)
    of PyBoolOp:
      result = compiler.compileBoolOp(node, env)
    else:
      result = PY_NIL
      warn($node.kind)
      # fail($node.kind)
  except Exception:
    warn(fmt"compile {getCurrentExceptionMsg()}")
    result = PY_NIL

proc compileAst*(compiler: var Compiler, file: string) =
  var node = compiler.asts[file]
  compiler.path = file
  assert(not node.isNil)
  if node.kind == PyModule:
    compiler.modules[file] = compiler.compileModule(file, node)
  compiler.maybeModules.del(file)

proc loadNamespace*(compiler: Compiler, path: string): string =
  assert path[^3..^1] == ".py" and path.startsWith(compiler.db.projectDir)
  let tokens = path[len(compiler.db.projectDir)..^1].split("/")
  var t = tokens.join(".")[0..^4]
  return fmt"{compiler.db.package}{t}"

proc mergeFunctionTypeInfo(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  assert node.kind == PyFunctionDef

  var f = node.children[0]
  assert f.kind == PyStr # TODO: label
  var label = f.s

  var typ: Type
  var fullName = if compiler.currentClass.isNil: fmt"{compiler.currentModule}#{label}" else: fmt"{compiler.currentModule}.{compiler.currentClass.label}#{label}"
  for name, t in compiler.db.types:
    if name == fullName:
      typ = t
      break
  if typ.isNil:
    fullName = fmt"{compiler.currentModule}#{label}"
    for name, t in compiler.db.types:
      if name == fullName:
        typ = t
    if typ.isNil:
      warn(fmt"no type for {fullName}")
      return node

  assert typ.kind in {N.Overloads, N.Function}

  typ.label = label
  # typ.fullLabel = fullName
  env[label] = typ
  result = node
  result.typ = typ

proc mergeClassTypeInfo(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  assert node[0].kind == PyStr
  let label = node[0].s
  let fullName = fmt"{compiler.currentModule}.{label}"
  var typ: Type
  for name, t in compiler.db.types:
    if not t.isNil and t.kind == N.Record and name == fullName:
      typ = t
      typ.fullLabel = fullName
      break

  if typ.isNil:
    typ = Type(kind: N.Record, init: "", label: label, fullLabel: fullName, members: initTable[string, Type]())
  env[label] = typ

  result = node
  result.typ = typ

proc mergeCallTypeInfo(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  result = node

proc mergeModuleTypeInfo(compiler: var Compiler, node: var PythonNode, env: var Env): PythonNode =
  # loads aliases , functions and classes
  if node.isNil:
    return
  case node.kind:
  of PyImportFrom:
    result = compiler.compileImportFrom(node, env)
    result.ready = true
  of PyFunctionDef:
    result = compiler.mergeFunctionTypeInfo(node, env)
  of PyClassDef:
    result = compiler.mergeClassTypeInfo(node, env)
  of PyCall:
    result = compiler.mergeCallTypeInfo(node, env)
  else:
    var z = 0
    for child in node.mitems:
      node[z] = compiler.mergeModuleTypeInfo(child, env)
      z += 1
    result = node

proc compile*(compiler: var Compiler, untilPass: Pass = Pass.Generation) =
  var firstPath = compiler.db.startPath()
  var node = compiler.db.loadAst(firstPath)
  compiler.maybeModules = {firstPath: true}.toTable()
  compiler.asts = {firstPath: node}.toTable()
  compiler.modules = initTable[string, Module]()
  compiler.generated = initTable[string, string]()
  compiler.base = firstPath.rsplit("/", 1)[0]
  # while len(compiler.maybeModules) > 0:
  for z, path in compiler.db.modules:
    if path.startsWith(compiler.db.projectDir): # and "codec" in path:
    # for path, maybe in compiler.maybeModules:
      try:
        if not compiler.modules.hasKey(path):
          if not compiler.asts.hasKey(path):
            compiler.asts[path] = compiler.db.loadAst(path)
          compiler.currentModule = compiler.loadNamespace(path)
          compiler.modules[path] = Module(name: compiler.currentModule, imports: @[], types: @[], functions: @[], init: @[])
          compiler.stack = @[]
          compiler.envs = {path: childEnv(nil, "", initTable[string, Type](), nil)}.toTable()
          compiler.currentFunction = ""
          var node = compiler.asts[path]
          var env = compiler.envs[path]
          compiler.asts[path] = compiler.mergeModuleTypeInfo(node, env)
          compiler.compileAst(path)
      except Exception:
        echo getCurrentExceptionMsg()
  if untilPass == Pass.Generation:
    var generator = Generator(indent: 2, v: generator.NimVersion.Development)
    for path, module in compiler.modules:
      compiler.generated[path] = generator.generate(module)

when false:
  proc compileToAst*(source: string): PythonNode =
    var compiler = Compiler()
    var (types, sysPath) = traceTemp("temp.py", source)
    var node = loadAst("temp.py")
    compiler.compile(node, types, "temp.py", sysPath, untilPass = Pass.AST)
    result = compiler.asts["temp.py"]


  proc compile*(source: string): string =
    var compiler = Compiler()
    var (types, sysPath) = traceTemp("temp.py", source)
    var node = loadAst("temp.py")
    compiler.compile(node, types, "temp.py", sysPath)
    result = compiler.generated["temp.py"]
