import unittest
import helpers
import ../compiler, ../core, ../python_ast, ../ast_dsl

suite "py2nim int ast":
  examples:
    a "2 + 2",    binop(2, add(), 2,  typ=IntType)
    a "2 - 2",    binop(2, sub(), 2,  typ=IntType)
    a "2 * 2",    binop(2, mult(), 2, typ=IntType)
    a "2 / 2",    binop(2, pdiv(), 2, typ=IntType)
    a "2 // 2",   binop(2, operator("div"), 2, typ=IntType)
    a "2 ** 2",   binop(2, operator("^"), 2, typ=IntType), libs=@["math"]
    a "2 << 2",   binop(2, operator("shl"), 2, typ=IntType)
    a "2 >> 2",   binop(2, operator("shr"), 2, typ=IntType)
    a "2 & 2",    binop(2, operator("and"), 2, typ=IntType)
    a "2 | 2",    binop(2, operator("or"), 2, typ=IntType)

# TODO: zahary works on this
# suite "pytnon2nim int code":
#   examples:
#     e "2 + 2",    "2 + 2"
#     e "2 - 2",    "2 - 2"
#     e "2 * 2",    "2 * 2"
#     e "2 / 2",    "2 / 2"
#     e "2 // 2",   "2 div 2"
#     e "2 ** 2",   "2 ^ 2", libs=@["math"]
#     e "2 << 2",   "2 shl 2"
#     e "2 >> 2",   "2 shr 2"
#     e "2 & 2",    "2 and 2"
#     e "2 | 2",    "2 or 2"
