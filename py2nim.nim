import os, strformat, strutils, sequtils, tables, json, macros, parseopt2
import tracer, python_ast, compiler, ast_parser, generator, deduckt_db

proc writeHelp =
  echo "py2nim [-o --output <outputdir>] [-a --ast] [-h --help] <test.py> args"
  quit(0)

proc save(compiler: Compiler, output: string, untilPass: Pass) =
  discard existsOrCreateDir(output)
  if untilPass == Pass.AST:
    # save a repr of ast
    for file, module in compiler.modules:
      let filename = file.rsplit("/", 1)[1].split(".")[0]
      writeFile(fmt"{output}/{filename}.nim", $module)
  else:
    for file, generated in compiler.generated:
      let filename = file.rsplit("/", 1)[1].split(".")[0]
      writeFile(fmt"{output}/{filename}.nim", generated)

proc translate =
  var command = ""
  var untilPass = Pass.Generation
  var output = "output"
  var nimArgs: seq[string] = @[]
  var pythonArgs: seq[string] = @[]
  var inPython = false
  for z in 1..paramCount():
    var arg = paramStr(z)
    if not inPython and not arg.endsWith(".py"):
      nimArgs.add(arg)
    else:
      inPython = true
      pythonArgs.add(arg)
  pythonArgs[0] = expandFilename(pythonArgs[0])
  command = pythonArgs.join(" ")
  var parser = initOptParser(nimArgs.join(" "))
  for kind, key, arg in parser.getopt():
    case kind:
    of cmdLongOption, cmdShortOption:
      case key:
      of "output", "o": output = arg
      of "ast", "a": untilPass = Pass.AST
      of "help", "h": writeHelp()
    else:
      discard

  if command == "":
    writeHelp()


  # trace it and collect types
  tracePython(command)
  var db = deduckt_db.load("python-deduckt.json")

  # load ast
  # var node = db.loadAst(path)

  # convert to idiomatic nim
  var compiler = newCompiler(db, command)
  compiler.compile(untilPass)

  save(compiler, output, untilPass)
  
translate()
