import numpy as np
import matplotlib.pyplot as plt

#Used Constants

N = 15
t = 2
m = 4

XY = 0
XZ = 1
YZ = 2
MAX = 1000

#orientation display

def display_orientation(o):
    if(o == XY):
        return "XY"
    elif(o == XZ):
        return "XZ"
    elif(o == YZ):
        return "YZ"
    raise ValueError(f"bad orientation {o}")

#Spatial definitions in 3D

def to_xyz(r, c, i, o):
    if(o == XY):
        return (r,c,i)
    elif(o == XZ):
        return (r,i,c)
    elif(o == YZ):
        return (i,r,c)
    raise ValueError(f"bad orientation {o}")

class Store:

    def __init__(self, cube):
        cube = np.asarray(cube, dtype = np.uint8)
        if cube.shape != (N, N, N):
            raise ValueError(f"cube must be {(N, N, N)}, got {cube.shape}")

        self.v = [cube.transpose(2, 0, 1).copy(), cube.transpose(1, 0, 2).copy(), cube.copy()]

    def read(self, o, i):
        return self.v[o][i].copy()

    def flip(self, o, i, r, c):
        x,y,z = to_xyz(r, c, i, o)
        self.v[XY][z,x,y] ^= 1
        self.v[XZ][y,x,z] ^= 1
        self.v[YZ][x,y,z] ^= 1

    def to_cube(self, view):
        if(view == XY):
            return self.v[XY].transpose(1,2,0).copy()
        elif(view == XZ):
            return self.v[XZ].transpose(1,0,2).copy()
        elif(view == YZ):
            return self.v[YZ].copy()
        raise ValueError(f"bad view {view}")

    def consistent(self):
        ref = self.to_cube(XY)
        return np.array_equal(self.to_cube(XZ), ref) and np.array_equal(self.to_cube(YZ), ref)

# Test block to verify master_3d function

# Let's create an error cube with known correctable errors
# and verify if master_3d successfully decodes and corrects it.
test_cube = np.zeros((N, N, N), dtype=np.uint8)

# Introduce sparse errors (up to t=2 errors per plane)

test_cube[1, 8, 5] = 1
test_cube[1, 12, 5] = 1
test_cube[2, 8, 5] = 1
test_cube[2, 10, 5] = 1
test_cube[2, 12, 5] = 1
test_cube[4, 8, 5] = 1
test_cube[4, 12, 5] = 1
test_cube[5, 8, 5] = 1
test_cube[5, 12, 5] = 1

test_cube[1, 8, 10] = 1
test_cube[1, 12, 10] = 1
test_cube[2, 8, 10] = 1
test_cube[2, 10, 10] = 1
test_cube[2, 12, 10] = 1
test_cube[4, 8, 10] = 1
test_cube[4, 12, 10] = 1
test_cube[5, 8, 10] = 1
test_cube[5, 12, 10] = 1

test_cube[8, 8, 5] = 1
test_cube[8, 12, 5] = 1
test_cube[9, 8, 5] = 1
test_cube[9, 10, 5] = 1
test_cube[9, 12, 5] = 1
test_cube[11, 8, 5] = 1
test_cube[11, 12, 5] = 1
test_cube[12, 8, 5] = 1
test_cube[12, 12, 5] = 1

test_cube[8, 8, 10] = 1
test_cube[8, 12, 10] = 1
test_cube[9, 8, 10] = 1
test_cube[9, 10, 10] = 1
test_cube[9, 12, 10] = 1
test_cube[11, 8, 10] = 1
test_cube[11, 12, 10] = 1
test_cube[12, 8, 10] = 1
test_cube[12, 12, 10] = 1

# Instantiate the store
test_store = Store(test_cube)