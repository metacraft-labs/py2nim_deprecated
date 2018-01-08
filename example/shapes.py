class Shape:
    pass

PI = 3.14


class Square(Shape):

    def __init__(self, a):
        self.a = a

    def area(self):
        return self.a ** 2

    def perimeter(self):
        return self.a * 4


class Circle(Shape):

    def __init__(self, r):
        self.r = r

    def area(self):
        return PI * self.r ** 2

    def perimeter(self):
        return 2 * PI * self.r


class Rectangle(Shape):

    def __init__(self, a, b):
        self.a = a
        self.b = b

    def area(self):
        return self.a * self.b

    def perimeter(self):
        return 2 * (self.a + self.b)


class Triangle(Shape):
    # 90

    def __init__(self, a, b, c):
        self.a = a
        self.b = b
        self.c = c

    def area(self):
        return (self.a * self.b) / 2

    def perimeter(self):
        return self.a + self.b + self.c


def test():
    square = Square(2)
    circle = Circle(4)
    rectangle = Rectangle(3.2, 2.1)
    triangle = Triangle(5, 2, 4)

    shapes = [square, circle, rectangle, triangle]

    for shape in shapes:
        print('area: ', shape.area())
        print('perimeter: ', shape.perimeter())

if __name__ == '__main__':
    test()
