
class MyError(Exception):
    pass

try:
    raise MyError("z")
except MyError as e:
    print(e)

try:
    raise "z"
except Exception as e:
    print(e)
