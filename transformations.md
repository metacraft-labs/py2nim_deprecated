# transformations

A very incomplete doc

## Builtin types

py2nim maps the most important python builtin types to nim ones.
Even if they are not fully equivalent, it's assumed that the user will know
and act accordingly if there are any edge case differences which matter for his case

| python           | nim                                    |
|------------------|----------------------------------------|
| list             | seq                            	    |
| dict             | Table                                  |
| tuple            | tuple                                  |
| int              | int                                    |
| float            | float                                  |
| str              | string or char                         |
| bytes            | cstring                                |
| bool             | bool                                   |
| class            | object type                            |
| function         | proc                                   |
| lambda 		   | anon proc 								|
| type             | typedesc 								|

## Bultin methods

We have a dsl for mapping Python methods and operators to Nim idioms (methods or AST).

Currently a part of string, list, dict and number methods and operators are mapped.
Also, print, isinstance, int, str and len builtin functions (this list should expand quickly)

## Functions

A Python function can be translated to many Nim overloads of the same function.
We might try to detect generic Python functions and translate them as such.


## Classes

They are translated to an object type and functions working on it.
If a class is inherited, methods are created, otherwise proc.

## Python constructs

Various python constructs are translated to the Nim equivalent, e.g. different `for` patterns, comprehensions etc

## Iterators

py2nim can recognize some `__iter__` and `__next__` based classes and also `yield` generators and create iterators for them

## Context managers

we can translate some classes with `__enter__` and `__exit__` to types which implement a similar interface and a `with` macro in Nim

## Other magic methods

`__init__`, `__str__`, `__len__`, `__getitem__`, `__setitem__`, `__call__`

## `@property` and `@classmethod`

There is some support for them


