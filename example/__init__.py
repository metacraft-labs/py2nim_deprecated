import example.shapes

def test():    
    square = example.shapes.Square(2)
    circle = example.shapes.Circle(4)
    rectangle = example.shapes.Rectangle(3.2, 2.1)
    triangle = example.shapes.Triangle(5, 2, 4)

    shapes = [square, circle, rectangle, triangle]

    for shape in shapes:
        print('area: ', shape.area())
        print('perimeter: ', shape.perimeter())


if __name__ == '__main__':
    test()
