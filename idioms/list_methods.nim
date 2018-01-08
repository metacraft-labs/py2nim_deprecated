import tables, strutils, sequtils, strformat
import idioms_dsl, ../python_types, ../nim_types, ../python_ast, ../ast_dsl, ../core, ../dependency

# methods: we have magical variables
# receiver which is equivalent to the python object that receives the method
# (bit smalltalk naming)
# pymethod(argName: ArgType <Type>*) => methodName: <Type> we assume it's receiver.methodName(argName*)
# pymethod(argName: ArgType <Type>*) => nimfunction(argName*): <Type>
# pymethod(argName: ArgType <Type>*): handler
# nimfunction can be <stuff>.<method>(<args>) or <function>(<args>)
# dependencies = <a table> method: seq[lib]
# dependenciesAll = seq[lib] when all methods need a lib
# dependenciesIgnore = seq[lib] blacklist methods that doesnt need a lib

builtin(T.List[E]):
  # https://docs.python.org/3.6/tutorial/datastructures.html#more-on-lists

  append(e: E) =>                           add: T.Void
  
  extend(iterable: T.List[E]):
    assign(receiver, call(attribute(receiver, "concat"), @[iterable], T.List[E]))

  # insert(i: T.Int, e: E):
  #   call(attribute(receiver, "insert"), @[list(@[e]), i], T.Void)

  # remove(e: E):
  #   pyLambda(@[label("e")], @[E], @[compare(notEq(), label("e"), e, T.Bool)])
    # call(
    #   attribute(receiver, "keepIf"),
    #   @[pyLambda(@[label("e")], @[E], @[compare(notEq(), label("e"), e, T.Bool)])],
    #   typ=T.Void)

  #dependenciesAll = @["sequtils"]

  #dependenciesIgnore = @["append"]

# echo builtinMethods

