import strformat, terminal, os

type
  Textable* = concept a
    $a is string

proc warn*(a: Textable) =
  styledWriteLine(stderr, fgYellow, fmt"warn: {$a}", resetStyle)

proc fail*(a: Textable) =
  styledWriteLine(stderr, fgRed, fmt"error: {$a}", resetStyle)
  writeStackTrace()
  quit(1)

proc success*(a: Textable) =
  styledWriteLine(stdout, fgGreen, a, resetStyle)

echo string is Textable