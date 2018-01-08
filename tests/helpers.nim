import macros, strformat, strutils, sequtils
import ../python_ast, ../python_types, ../ast_dsl

# The DSL for testing
# can be `e` or `a`
# `e` is an example (you pass the original nim code and the python code)
# `s` is an ast example (you pass the expected ast)
# you can also add `pre` which sets a default initial line for the next examples
# libs is a optional parameter for modules that need to be imported

macro examples*(tests: untyped): untyped =
  result = nnkStmtList.newTree()
  var pre = ""
  for test in tests:
    expectKind(test, nnkCommand)
    expectKind(test[0], nnkIdent)
    let kind = $test[0]
    var newTest: NimNode = nil
    var testNode = ident("test")
    if kind == "pre":
      expectKind(test[1], nnkStrLit)
      pre = $test[1] & "\n"
    elif kind == "e" or kind == "a":
      expectKind(test[1], nnkStrLit)
      let code = newLit(fmt"{pre}{test[1]}")
      let a = test[2]

      if kind == "e":
        newTest = quote:
          `testNode` "example":
            check(compile(`code`) == `a`)
      elif kind == "a":
        newTest = quote:
          `testNode` "example":
            var ast = compileToAst(`code`).children[0].children[0].children[2].children[^1]
            echo "got", ast
            echo "expected", `a`
            check(ast.testEq(`a`))
    else:
      error("expected e or a")

    if not newTest.isNil:
      result.add(newTest)
