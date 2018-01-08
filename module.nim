import strformat, strutils, sequtils, python_ast

type
  Module* = object
    name*: string
    imports*: seq[PythonNode] # probably Import and Assign
    types*: seq[PythonNode] # probably ClassDef
    functions*: seq[PythonNode] # probably FunctionDef
    init*: seq[PythonNode] # other top level stuff

proc `$`*(module: Module): string =
  let endl = "\n"
  result = fmt"{module.name}\nImports:\n{dumpList(module.imports, 1)}\nTypes:\n{dumpList(module.types, 1)}\nFunctions:\n{dumpList(module.functions, 1)}\nInit:\n{dumpList(module.init, 1)}\n"
