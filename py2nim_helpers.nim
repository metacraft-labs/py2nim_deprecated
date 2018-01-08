import macros, tables

template mapTable*(sequence: untyped, op: untyped): untyped =
  @[]
 #  type returnType = type((
 #  	block:
 #  	  var it{.inject.}: type(items(sequence));
 #  	  op))
 
 # var result: seq[return]

macro with*(a: untyped, b: untyped): untyped =
  result = quote:
    var tmp = `a`
    var e: ref Exception
    var t = ""
    try:
      tmp.enter()
      `b`
    except:
      e = getCurrentException()
      t = getStackTrace()
    tmp.exit(e, e, t)
    if not e.isNil:
      raise e
