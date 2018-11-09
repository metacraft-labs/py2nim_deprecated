import
  tables, py2nim_helpers, sequtils

var
  a = {2: 4}.newTable()
  b = @[2, 4]
echo a.filterTable(k == 0).mapTable((k + 2, v - 2))
echo b.filterIt(it > 2).mapTable((it, 2))
