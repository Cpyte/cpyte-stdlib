import stdlib
import "vector2.cpy"
import "vector3.cpy"
import "vector4.cpy"
import "matrix2.cpy"
import "matrix3.cpy"
import "matrix4.cpy"
import "complex.cpy"
import "interpolate.cpy"
import "transforms.cpy"
import "numeric.cpy"
import "scalar.cpy"
import "statistics.cpy"

def main():
    Vector2 a = vector2(1.0, 2.0)
    Vector2 b = vector2(3.0, 4.0)
    Vector2 s2 = vector2_add(a, b)
    print("v2", (int)s2.x, (int)s2.y)
    Vector3 c = vector3(1.0, 2.0, 3.0)
    Vector3 d = vector3(4.0, 5.0, 6.0)
    Vector3 cr = vector3_cross(c, d)
    print("v3x", (int)cr.x, (int)cr.y, (int)cr.z)
    Vector4 e = vector4(1.0, 2.0, 3.0, 4.0)
    print("v4dot", (int)vector4_dot(e, e))

    Matrix2 m2a = matrix2_identity()
    Matrix2 m2 = matrix2_mul(m2a, m2a)
    print("m2det", (int)matrix2_det(m2))
    Matrix3 m3 = matrix3_identity()
    print("m3det", (int)matrix3_det(m3))

    Matrix4 mk = matrix4_identity()
    Matrix4 mi = matrix4_inverse(mk)
    print("m4det", (int)matrix4_det(mi))

    Complex z = complex_make(3.0, 4.0)
    Complex z2 = complex_mul(z, z)
    print("cplx", (int)complex_abs(z2))

    print("lerp", (int)interp_lerp(0.0, 10.0, 0.5))

    double[] out = new double[2]
    out[0] = 0.0
    out[1] = 0.0
    polar_to_cartesian(2.0, 0.0, (double*)out)
    print("polar", (int)out[0])

    print("ctz", (int)ctz((uint64)8), "popcnt", (int)numeric_popcount((uint64)15))
    print("clamp", (int)scalar_clamp(9.0, 0.0, 5.0))
    print("m2 PASS")
