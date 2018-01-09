import json, ast_parser, python_ast, nim_types, core, tables, tracer, strformat, strutils, sequtils

type
  DeducktDb* = ref object
    root:         JsonNode
    modules*:     seq[string]
    types*:       Table[string, Type]
    sysPath*:     seq[string]
    projectDir*:  string
    package*:     string

proc load*(dbfile: string): DeducktDb =
  new(result)
  result.root = parseJson(readFile(dbfile))
  result.types = initTable[string, Type]()
  result.sysPath = @[]
  result.modules = @[]
  result.projectDir = result.root{"@projectDir"}.getStr()
  result.package = result.projectDir.rsplit("/", 1)[1]
  for label, trace in result.root:
    if label == "@types":
      for childLabel, child in trace:
        if childLabel != "@path":
          # echo childLabel
          var typ = toType(importType(child))
          typ.fullLabel = childLabel
          if typ.kind == N.Overloads:
            for overload in typ.overloads.mitems:
              overload.fullLabel = childLabel
          result.types[childLabel] = typ
        else:
          result.sysPath = child.mapIt(($it)[1..^2])
    else:
      result.modules.add(label)


proc loadAst*(db: DeducktDb, filename: string): Node =
  # XXX: Perhaps, this could be cached
  # echo filename
  result = importAst(db.root[filename]["ast"])

proc startPath*(db: DeducktDb): string =
  # TODO: smarter
  result = ""
  var maybeResult = ""
  for module in db.modules:
    if module.startsWith(db.projectDir):
      if module.endsWith("constants.py"):
        result = module
        break
      elif maybeResult == "":
        maybeResult = module
  if result == "":
    result = maybeResult
