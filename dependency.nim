import sequtils, tables

type
  TypeDependency* = object
    methods*: Table[string, seq[string]]
    ignore*:  seq[string]
    all*:     seq[string]
