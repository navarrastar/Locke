package math2

import "core:math/linalg"

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32
Mat4 :: linalg.Matrix4x4f32
Quat :: linalg.Quaternionf32

IDENTITY_MAT :: linalg.MATRIX4F32_IDENTITY
IDENTITY_QUAT :: linalg.QUATERNIONF32_IDENTITY

PI :: 3.14159265359

DEFAULT_TRANSFORM :: Transform {
    pos = Vec3{0, 0, 0},
    rot = Vec3{0, 0, 0},
    scale = 1,
}



Transform :: struct {
    pos: Vec3,
    rot: Vec3,
    scale: f32,
}

Ray :: struct {
    dir: Vec3,
    pos: Vec3
}

quat :: proc{ quat_from_euler, quat_from_4f32 }

@(require_results)
quat_from_euler :: proc(euler: Vec3) -> Quat {
    return linalg.quaternion_from_euler_angles_f32(euler.x, euler.y, euler.z, linalg.Euler_Angle_Order.XYZ)
}

@(require_results)
quat_from_4f32 :: proc(q: [4]f32) -> (quat: Quat) {
    quat.x = q[0]
    quat.y = q[1]
    quat.z = q[2]
    quat.w = q[3]
    return quat
}

@(require_results)
euler :: proc(quat: Quat) -> Vec3 {
    x, y, z := linalg.euler_angles_from_quaternion_f32(quat, linalg.Euler_Angle_Order.XYZ)
    return Vec3{x, y, z}
}

@(require_results)
cross :: proc(a: Vec3, b: Vec3) -> Vec3 {
    return linalg.vector_cross3(a, b)
}

@(require_results)
dot :: proc(a: Vec3, b: Vec3) -> f32 {
    return linalg.vector_dot(a, b)
}

@(require_results)
normalize :: proc(v: Vec3) -> Vec3 {
    return linalg.vector_normalize(v)
}

@(require_results)
length :: proc(v: Vec3) -> f32 {
    return linalg.vector_length(v)
}

@(require_results)
look_at :: proc(position: Vec3, target: Vec3, up: Vec3) -> Mat4 {
    return linalg.matrix4_look_at_f32(position, target, up)
}

@(require_results)
perspective :: proc(fovy: f32, aspect: f32, near: f32, far: f32) -> Mat4 {
    return linalg.matrix4_perspective_f32(fovy, aspect, near, far)
}

@(require_results)
ortho :: proc(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Mat4 {
    return linalg.matrix_ortho3d_f32(left, right, bottom, top, near, far)
}

@(require_results)
to_radians :: proc(degrees: f32) -> f32 {
    return linalg.to_radians(degrees)
}

@(require_results)
to_degrees :: proc(radians: f32) -> f32 {
    return linalg.to_degrees(radians)
}

to_matrix :: proc {to_matrix_from_scratch, to_matrix_from_transform, to_matrix_from_deformed}

@(require_results)
to_matrix_from_scratch :: proc(pos: Vec3, rot: Vec3, scale: f32) -> Mat4 {
    quaternion := quat_from_euler(rot)
    
    translation := linalg.matrix4_translate_f32(pos)
    rotation := linalg.matrix4_from_quaternion_f32(quaternion)
    scaling := linalg.matrix4_scale_f32(Vec3{scale, scale, scale})

    return translation * rotation * scaling
}

@(require_results)
to_matrix_from_transform :: proc(transform: Transform) -> Mat4 {
    return to_matrix(transform.pos, transform.rot, transform.scale)
}

@(require_results)
to_matrix_from_deformed :: proc(pos: Vec3, rot: Quat, scale: Vec3) -> Mat4 {
    translation := linalg.matrix4_translate_f32(pos)
    rotation := linalg.matrix4_from_quaternion_f32(rot)
    scaling := linalg.matrix4_scale_f32(scale)
    return translation * rotation * scaling
}

@(require_results)
mvp :: proc(pos: Vec3, rot: Vec3, scale: f32, view: Mat4, proj: Mat4) -> Mat4 {
    return linalg.matrix_mul(view, linalg.matrix_mul(proj, to_matrix(pos, rot, scale)))
}

@(require_results)
matrix_rotate :: proc(angle_radians: f32, v: Vec3) -> Mat4 {
    return linalg.matrix4_rotate_f32(angle_radians, v)
}

@(require_results)
cos :: proc(x: f32) -> f32 {
    return linalg.cos(x)
}

@(require_results)
sin :: proc(x: f32) -> f32 {
    return linalg.sin(x)
}

@(require_results)
tan :: proc(x: f32) -> f32 {
    return linalg.tan(x)
}

@(require_results)
acos :: proc(x: f32) -> f32 {
    return linalg.acos(x)
}

@(require_results)
asin :: proc(x: f32) -> f32 {
    return linalg.asin(x)
}

@(require_results)
atan :: proc(x: f32) -> f32 {
    return linalg.atan(x)
}

@(require_results)
atan2 :: proc(y, x: f32) -> f32 {
    return linalg.atan2(y, x)
}

@(require_results)
sqrt :: proc(x: f32) -> f32 {
    return linalg.sqrt(x)
}

@(require_results)
abs :: proc(x: f32) -> f32 {
    return linalg.abs(x)
}

@(require_results)
same_dir :: proc(dir1, dir2: Vec3) -> bool {
    return dot(dir1, dir2) > 0
}

@(require_results)
inverse :: proc(m: Mat4) -> Mat4 {
    return linalg.matrix4_inverse(m)
}

@(require_results)
lerp :: proc(a, b, t: $T) -> T {
    return linalg.lerp(a, b, t)
}

@(require_results)
quaternion_slerp :: proc(q1, q2: Quat, t: f32) -> Quat {
    return linalg.quaternion_slerp(q1, q2, t)
}

@(require_results)
matrix4_from_trs :: proc(translation: Vec3, rotation: Quat, scale: Vec3) -> Mat4 {
    translate_mat := linalg.matrix4_translate_f32(translation)
    rotation_mat := linalg.matrix4_from_quaternion_f32(rotation)
    scale_mat := linalg.matrix4_scale_f32(scale)
    
    return linalg.matrix_mul(translate_mat, linalg.matrix_mul(rotation_mat, scale_mat))
}

@(require_results)
decompose_transform :: proc(mat: Mat4) -> (position: Vec3, rotation: Quat, scale: Vec3) {
    // Extract translation from the last column
    position = {mat[3][0], mat[3][1], mat[3][2]}
    
    // Extract rotation mat (3x3 upper-left portion)
    rot_mat: Mat4 = mat
    
    // Extract scale by calculating the length of each basis vector
    scale.x = length({rot_mat[0][0], rot_mat[0][1], rot_mat[0][2]})
    scale.y = length({rot_mat[1][0], rot_mat[1][1], rot_mat[1][2]})
    scale.z = length({rot_mat[2][0], rot_mat[2][1], rot_mat[2][2]})
    
    // Remove scale from rotation matrix
    if scale.x != 0 {
        rot_mat[0][0] /= scale.x
        rot_mat[0][1] /= scale.x
        rot_mat[0][2] /= scale.x
    }
    if scale.y != 0 {
        rot_mat[1][0] /= scale.y
        rot_mat[1][1] /= scale.y
        rot_mat[1][2] /= scale.y
    }
    if scale.z != 0 {
        rot_mat[2][0] /= scale.z
        rot_mat[2][1] /= scale.z
        rot_mat[2][2] /= scale.z
    }
    
    // Convert rotation matrix to quaternion
    rotation = linalg.quaternion_from_matrix4_f32(rot_mat)
    
    return position, rotation, scale
}

between :: proc(a, b, c: $T) -> bool {
    return a > b && a < c
}