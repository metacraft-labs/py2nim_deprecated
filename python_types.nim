import strutils, sequtils, strformat

type
  PyTypeKind* = enum PyTypeObject, PyTypeTuple, PyTypeFunction, PyTypeFunctionOverloads, PyTypeAtom, PyTypeConcrete, PyTypeUnion, PyTypeOptional, PyTypeGeneric, PyTypeNone

  PyType* = ref object
    label*: string # empty for some kinds, but otherwise we need <kind>label which sucks a lot
    case kind*: PyTypeKind
    of PyTypeObject:
      fields*: seq[PyVariable]
      base*: PyType
      inherited*: bool
    of PyTypeTuple:
      elements*: seq[PyType]
    of PyTypeFunction:
      args*:      seq[PyVariable]
      variables*: seq[PyVariable]
      returnType*: PyType
    of PyTypeFunctionOverloads:
      overloads*: seq[PyType]
    of PyTypeConcrete, PyTypeUnion:
      types*: seq[PyType]
    of PyTypeOptional:
      typ*: PyType
    of PyTypeGeneric:
      klass*:  string
      length*: int
    else:
      discard

  PyVariable* = object
    name*:    string
    typ*:     PyType
    isArg*:   bool

proc `$`*(t: PyType): string

proc `$`*(v: PyVariable): string =
  result = fmt"{v.name}: {$v.typ}"

proc dump*(t: PyType, depth: int): string =
  let offset = repeat("  ", depth)
  let endl = "\n"
  let value = case t.kind:
    of PyTypeObject:
      var fieldList: seq[string] = @[]
      for f in t.fields:
        fieldList.add(fmt("{repeat(\" \", depth + 1)}{$f}"))
      let fields = fieldList.join("\n")
      fmt"{t.label}:[{endl}{fields}{endl}]"
    of PyTypeTuple:
      let elements = t.elements.mapIt($it).join(", ")
      fmt"({elements})"
    of PyTypeFunction:
      var argsList: seq[string] = @[]
      var ret: string = "void"
      for v in t.variables:
        if v.isArg:
          argsList.add($v)
        elif v.name == "@return":
          ret = $v.typ
          if ret == "":
            ret = "void"
      let args = argsList.join(", ")
      fmt"({args}) -> {ret}"
    of PyTypeFunctionOverloads:
      var overloads = t.overloads.mapIt(dump(it, depth + 1)).join("\n")
      fmt"{t.label}:{endl}{overloads}"
    of PyTypeConcrete:
      let types = t.types.mapIt($it).join(", ")
      fmt"{t.label}[{types}]"
    of PyTypeUnion:
      t.types.mapIt($it).join(" | ")
    of PyTypeOptional:
      fmt"{$t.typ}?"
    of PyTypeGeneric:
      fmt"{t.klass}"
    else:
      t.label
  result = fmt"{offset}{value}"

proc `$`*(t: PyType): string =
  if t.isNil:
    result = "nil"
  else:
    result = dump(t, 0)
