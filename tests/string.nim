import unittest
import helpers
import ../compiler, ../core, ../python_ast, ../ast_dsl

suite "py2nim string ast":
  examples:
    pre "a = 'wow such sequence'"
    a "a.capitalize()",    call(attribute("a.capitalizeAscii"), @[], T.String)
    a "a.center(2)",       call(attribute("a.center"), @[2], T.String)
    a "a.count('z')",      call(attribute("a.count"), @[pyString("z")], T.String)
    a "a.count('z', 2)",   call(attribute("a.count"), @[pyString("z"), 2], T.String)
    a "a.count('z', 2, 4)", call(attribute("a.count"), @[pyString("z"), 2, 4], T.String)
    a "a.endswith('z')",   call(attribute("a.endsWith"), @[pyString("z")], T.String)
    a "a.endswith('z', 2)", call(attribute(subscript(label("a"), slice(2)), "endsWith"), @[pyString("z")], T.String)
    a "a.endswith('z', 2, 4)", call(attribute(subscript(label("a"), slice(2, 4)), "endsWith"), @[pyString("z")], T.String)
    a "a.expandTabs()",    call(attribute("a.expandTabs"), @[], T.String)
    a "a.expandTabs(4)",   call(attribute("a.expandTabs"), @[4], T.String)
    a "a.find('z')",       call(attribute("a.find"), @[pyString("z")], T.String)
    a "a.find('z', 2)",    call(attribute("a.find"), @[pyString("z"), 2], T.String)
    a "a.find('z', 2, 4)", call(attribute("a.find"), @[pyString("z"), 2, 4], T.String)

# suite "py2nim string code":
#   examples:
#     pre "a = 'wow such sequence'"

    # e "a.capitalize()",   "a.capitalizeAscii()"
    # e "a.center(2)",      "a.center(2)"
    # e "a.count('z')",      "a.count(\"z\")"
    # e "a.count('z', 2)",   "a.count(\"z\", 2)"
    # a "a.count('z', 2, 4)", "a.count(\"z\", 2, 4)"
    # a "a.endswith('z')",   "a.endsWith(\"z\")"
    # a "a.endswith('z', 2)", "a[2..^1].endsWith(\"z\")"
    # a "a.endswith('z', 2, 4)", "a[2..3].endsWith(\"z\")"
    # a "a.expandTabs()",    "a.expandTabs()"
    # a "a.expandTabs(4)",   "a.expandTabs(4)"
    # a "a.find('z')",       "a.find(\"z\")"
    # a "a.find('z', 2)",    "a.find(\"z\", 2)"
    # a "a.find('z', 2, 4)", "a.find(\"z\", 2, 4)"
