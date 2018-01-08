import strutils, sequtils, tables, future
import nim_types, errors

type
  Env* = ref object
    types*:       Table[string, Type]
    args*:        Table[string, bool]
    returnType*:  Type
    label*:       string
    parent*:      Env
    top*:         Env
    hasYield*:    bool

proc get*(e: Env, name: string): Type

proc `[]`*(e: Env, name: string): Type =
  result = get(e, name)
  if result.isNil:
    raise newException(Python2NimError, "undefined $1" % name)

proc `[]=`*(e: var Env, name: string, typ: Type) =
  e.types[name] = typ

proc hasKey*(e: Env, name: string): bool =
  not e.get(name).isNil

proc get*(e: Env, name: string): Type =
  var last = e
  while not last.isNil:
    if last.types.hasKey(name):
      return last.types[name]
    last = last.parent
  result = nil

proc childEnv*(e: Env, label: string, args: Table[string, Type], returnType: Type): Env =
  var argsChild = initTable[string, bool]()
  for arg, typ in args:
    argsChild[arg] = false
  result = Env(types: args, args: argsChild, returnType: returnType, label: label, parent: e)
  result.top = if e.isNil: result else: e.top
