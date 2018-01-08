import unittest
import helpers
import ../compiler, ../core, ../python_ast, ../ast_dsl

suite "py2nim float ast":
  examples:
    a "2.0 + 2.0",    binop(2.0, add(), 2.0, typ=FloatType)
    a "2.0 - 2.0",    binop(2.0, sub(), 2.0, typ=FloatType)
    a "2.0 * 2.0",    binop(2.0, mult(), 2.0, typ=FloatType)
    a "2.0 / 2.0",    binop(2.0, pdiv(), 2.0, typ=FloatType)
    a "2.0 ** 2.0",   call(label("pow"), @[2.0, 2.0]), libs=@["math"]

# suite "pytnon2nim float code":
#   examples:
#     e "2.0 + 2.0",    "2.0 + 2.0"
#     e "2.0 - 2.0",    "2.0 - 2.0"
#     e "2.0 * 2.0",    "2.0 * 2.0"
#     e "2.0 / 2.0",    "2.0 / 2.0"
#     e "2.0 ** 2.0",   "pow(2.0, 2.0)", libs=@["math"]
