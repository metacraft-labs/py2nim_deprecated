import unittest
import helpers
import ../compiler, ../core, ../python_ast, ../nim_types, ../ast_dsl

suite "py2nim list ast":
  examples:
    pre "a = [2]"
    a "a.append(2)",    call(attribute("a.add"), @[2])
    a "a.extend([2])",  assign(label("a"), call(attribute("a.concat"), @[list(2)], T.List[T.Int]))
    # a "b = a.pop()",    pyVarDef(label("b"), call(attribute("a.pop")))
    # a "b = len(a)",     pyVarDef(label("b"), call(label("len"), sequence(label("a"))))
  
# suite "py2nim list code":
#   examples:
#     pre "a = [2]"

#     e "a.append(2)", "a.add(2)"
#     e "a.extend([2])", "a = a.concat(@[2])"
#     e "b = a.pop()", "var b = a.pop()"
#     e "b = len(a)", "var b = len(a)"
