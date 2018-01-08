import
  tables, py2nim_helpers

var a = {2: 4}.toTable()
var b = @ [2, 4]
echo a.mapTable(k + 2: v - 2)
echo b.mapTable(it: 2)
