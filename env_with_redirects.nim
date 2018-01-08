import strutils, sequtils, tables, future
import nim_types, errors

type
  Env* = ref object
    values*:      Table[string, Type]
    args*:        Table[string, bool]
    # redirects*:   Table[string, string] mapping aliases for names: overloaded name / invalid name?
    label*:       string
    parent*:      Env
    top*:         Env

proc get*(e: Env, name: string): Type

proc `[]`*(e: Env, name: string): Type =
  var realName: string
  if e.redirects.hasKey(name):
    realName = e.redirects[name]
  else:
    realName = name
  result = get(e, realName)
  if result.isNil:
    raise newException(Python2NimError, "undefined $1" % name)

proc `[]=`*(e: var Env, name: string, operand: Type) =
  e.values[name] = operand

proc hasKey*(e: Env, name: string): bool =
  not e.get(name).isNil or e.redirects.hasKey(name)

proc get*(e: Env, name: string): Type =
  var last = e
  while not last.isNil:
    if last.values.hasKey(name):
      return last.values[name]
    last = last.parent
  result = nil

proc child*(e: Env, label: string, args: Table[string, Type]): Env =
  var argsChild = initTable[string, bool]()
  for arg, typ in args:
    argsChild[arg] = false
  var redirects = initTable[string, string]()
  result = Env(values: args, args: argsChild, label: label, redirects: redirects, parent: e)
  result.top = if e.isNil: result else: e.top
