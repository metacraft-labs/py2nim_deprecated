# those type nodes are closer to nim's type system
# they are easily mappable to PNode

import sequtils, strutils, strformat, tables, future, hashes, errors

type
  N* {.pure.} = enum Atom, Function, Overloads, Compound, Generic, Record, Tuple, GenericVar, Any

  Type* = ref object
    label*:     string
    fullLabel*: string # with namespace
    isVar*:     bool
    isRef*:     bool
    case kind*: N:
    of N.Atom:
      # Types of atom values and types for which we only know the name, not the structure
      extra*: string
    of N.Function:
      # Function type
      functionArgs*: seq[Type]
      returnType*:   Type
      # effects
    of N.Overloads:
      # Overloads
      overloads*: seq[Type]
    of N.Compound:
      # Instantiation of a generic type
      args*:     seq[Type]
      original*: Type
    of N.Generic:
      # Generic type
      genericArgs*: seq[string]
    of N.Record:
      # The fields of an object type
      base*:    Type
      init*:    string # if empty, :
      members*: Table[string, Type]
    of N.Tuple:
      # A tuple
      elements*: seq[Type]
    of N.GenericVar:
      # A generic
      discard
    of N.Any:
      # Universal
      discard

let endl = "\n"
proc `$`*(t: Type): string

proc hash*(t: Type): Hash =
  var h: Hash = 0
  h = h !& hash(t.kind)
  h = h !& hash(t.label)
  result = !$h

proc `==`*(t: Type, u: Type): bool =
  # structural equivalence for some, nominal for objects
  let tptr = cast[pointer](t)
  let uptr = cast[pointer](u)

  if tptr == nil:
    return uptr == nil
  if uptr == nil or t.kind != u.kind:
    return false

  case t.kind:
  of N.Atom:
    result = t.label == u.label
  of N.Function:
    result = len(t.functionArgs) == len(u.functionArgs) and zip(t.functionArgs, u.functionArgs).allIt(it[0] == it[1]) and t.returnType == u.returnType
  of N.Overloads:
    result = t.fullLabel == u.fullLabel
  of N.Compound:
    result = t.original == u.original and len(t.args) == len(u.args) and zip(t.args, u.args).allIt(it[0] == it[1])
  of N.Generic:
    result = t.label == u.label and len(t.genericArgs) == len(u.genericArgs)
  of N.Record:
    result = t.fullLabel == u.fullLabel
  of N.Tuple:
    result = len(t.elements) == len(u.elements) and zip(t.elements, u.elements).allIt(it[0] == it[1])
  of N.GenericVar:
    result = t.label == u.label
  of N.Any:
    result = true

proc dump*(t: Type, depth: int): string =
  var offset = repeat("  ", depth)
  var left = if t.isNil: "nil" else: ""
  if left == "":
    left = case t.kind:
      of N.Atom:
        fmt"type {$t.label}"
      of N.Function:
        let args = t.functionArgs.mapIt(dump(it, 0)).join(" ")
        fmt"({args}) -> {dump(t.returnType, 0)}"
      of N.Overloads:
        let overloads = t.overloads.mapIt(dump(it, depth + 1)).join("\n")
        fmt"{t.fullLabel}:{endl}{overloads}"
      of N.Compound:
        "$1[$2]" % [if t.original.label.isNil: "?" else: t.original.label, t.args.mapIt(dump(it, 0)).join(" ")]
      of N.Generic:
        "$1[$2]" % [t.label, t.genericArgs.join(" ")]
      of N.Record:
        var members = ""
        for label, member in t.members:
          members.add("$1$2: $3\n" % [repeat("  ", depth + 1), label, dump(member, 0)])
        echo t.label
        "$1:\n$2" % [t.label, members]
      of N.Tuple:
        let elements = t.elements.mapIt(dump(it, 0)).join(", ")
        fmt"({elements})"
      of N.GenericVar:
        fmt"generic {t.label}"
      of N.Any:
        fmt"any"
  result = "$1$2" % [offset, left]

iterator items*(t: Type): Type =
  case t.kind:
  of N.Atom:
    discard
  of N.Function:
    for arg in t.functionArgs:
      yield arg
    yield t.returnType
  of N.Overloads:
    for overload in t.overloads:
      yield overload
  of N.Compound:
    for arg in t.args:
      yield arg
  of N.Generic:
    discard
  of N.Record:
    for label, member in t.members:
      yield member
  of N.Tuple:
    for element in t.elements:
      yield element
  of N.GenericVar:
    discard
  of N.Any:
    discard

proc `$`*(t: Type): string =
  result = dump(t, 0)

proc `[]`*(t: Type, args: varargs[Type]): Type =
  if t.kind != N.Generic:
    raise newException(Python2NimError, fmt"{$t.kind} []")
  else:
    result = Type(kind: N.Compound, args: @args, original: t)

proc unify*(a: Type, b: Type, genericMap: var Table[string, Type]): bool =
  # resolves generic vars
  if a.isNil or b.isNil:
    return false
  elif a.kind == N.GenericVar:
    if genericMap.hasKey(a.label):
      return genericMap[a.label] == b:
    else:
      genericMap[a.label] = b
      return true
  elif a.kind == N.Overloads and b.kind == N.Function:
    return a.overloads.anyIt(it.unify(b, genericMap))
  elif a.kind == N.Function and b.kind == N.Overloads:
    return b.overloads.anyIt(a.unify(it, genericMap))
  elif a.kind != b.kind:
    return false
  else:
    case a.kind:
    of N.Atom:
      return a.label == b.label
    of N.Function:
      return len(a.functionArgs) == len(b.functionArgs) and zip(a.functionArgs, b.functionArgs).allIt(it[0].unify(it[1], genericMap)) and a.returnType.unify(b.returnType, genericMap)
    of N.Overloads:
      for aOverload in a.overloads:
        for bOverload in b.overloads:
          if aOverload.unify(bOverload, genericMap):
            return true
      return false
    of N.Compound:
      return a.original == b.original and zip(a.args, b.args).allIt(it[0].unify(it[1], genericMap))
    of N.Generic:
      return a.label == b.label and len(a.genericArgs) == len(b.genericArgs)
    of N.Record:
      return a.label == b.label
    of N.Tuple:
      return len(a.elements) == len(b.elements) and zip(a.elements, b.elements).allIt(it[0].unify(it[1], genericMap))
    of N.GenericVar:
      return a.label == b.label
    of N.Any:
      return true
