package chunks

import "core:fmt"
import "core:c"
import "core:math"
import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"
import "core:math/linalg"

GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6
PROGRAM_NAME :: "Program"

running : b32 = true

window: glfw.WindowHandle

program, vao, vbo, ebo, texture : u32
u_proj, u_view, u_model : i32
stride : i32 = 8 * size_of(f32)

WIDTH, HEIGHT : i32 = 512, 512

ATLAS_TILES_X, ATLAS_TILES_Y : i32 = 16, 16
ATLAS_TILE_U, ATLAS_TILE_V : f32 = 1.0 / f32(ATLAS_TILES_X), 1.0 / f32(ATLAS_TILES_Y)


camera_pos := [3]f32{0.0, 0.0, 3.0}
camera_front := [3]f32{0.0, 0.0, -1.0}
camera_up := [3]f32{0.0, 1.0, 0.0}
yaw   : f32 = -90.0
pitch : f32 = 0.0

last_x, last_y : f64 = 250.0, 250.0
first_mouse := true

delta_time := f64(0.0)
last_frame := f64(0.0)

Block_ID :: enum u8 {
    Air,
    Solid,
}

block_tile := [Block_ID][2]int {
    .Air = {0, 0},
    .Solid = {1, 0},
}

Face_Dir :: enum {
    PosX,
    NegX,
    PosY,
    NegY,
    PosZ,
    NegZ,
}

face_vertices := [Face_Dir][4][3]f32{
    .PosX = {
        {1,0,0}, {1,1,0}, {1,1,1}, {1,0,1},
    },
    .NegX = {
        {0,0,1}, {0,1,1}, {0,1,0}, {0,0,0},
    },
    .PosY = {
        {0,1,1}, {1,1,1}, {1,1,0}, {0,1,0},
    },
    .NegY = {
        {0,0,0}, {1,0,0}, {1,0,1}, {0,0,1},
    },
    .PosZ = {
        {0,0,1}, {1,0,1}, {1,1,1}, {0,1,1},
    },
    .NegZ = {
        {1,0,0}, {0,0,0}, {0,1,0}, {1,1,0},
    },
}

face_normals := [Face_Dir][3]f32{
    .PosX = { 1, 0, 0 },
    .NegX = { -1, 0, 0 },
    .PosY = { 0, 1, 0 },
    .NegY = { 0, -1, 0 },
    .PosZ = { 0, 0, 1 },
    .NegZ = { 0, 0, -1 },
}

emit_face :: proc(mesh : ^Chunk_Mesh, chunk_pos: [3]i32, x, y, z: i32, dir: Face_Dir, block_id: Block_ID) {
    base_index := u32(len(mesh.vertices) / 8) // 8 floats per vertex 3 pos, 3 normal, 2 uv

    tile := block_tile[block_id]
    tx, ty := tile[0], tile[1]

    u_min := f32(tx) * ATLAS_TILE_U
    v_min := f32(ty) * ATLAS_TILE_V
    u_max := u_min + ATLAS_TILE_U
    v_max := v_min + ATLAS_TILE_V

    uvs: [4][2]f32
    switch dir {
        case .PosX: // BL, TL, TR, BR
            uvs = { {u_min, v_min}, {u_min, v_max}, {u_max, v_max}, {u_max, v_min} } 
        case .NegX: // BR, TR, TL, BL
            uvs = { {u_max, v_min}, {u_max, v_max}, {u_min, v_max}, {u_min, v_min} }
        case .PosY: // TL, TR, BR, BL
            uvs = { {u_min, v_max}, {u_max, v_max}, {u_max, v_min}, {u_min, v_min} }
        case .NegY: // BL, BR, TR, TL
            uvs = { {u_min, v_min}, {u_max, v_min}, {u_max, v_max}, {u_min, v_max} }
        case .PosZ: // BL, BR, TR, TL
            uvs = { {u_min, v_min}, {u_max, v_min}, {u_max, v_max}, {u_min, v_max} }
        case .NegZ: // BR, BL, TL, TR
            uvs = { {u_max, v_min}, {u_min, v_min}, {u_min, v_max}, {u_max, v_max} }
    }

    for v in 0..<4 { // 4 vertices per face
        pos := face_vertices[dir][v] // get vertex position

        wx := f32(chunk_pos[0] * CHUNK_SIZE + x) + pos[0]
        wy := f32(chunk_pos[1] * CHUNK_SIZE + y) + pos[1]
        wz := f32(chunk_pos[2] * CHUNK_SIZE + z) + pos[2]

        // position
        append(&mesh.vertices, wx)
        append(&mesh.vertices, wy)
        append(&mesh.vertices, wz)

        // normal
        append(&mesh.vertices, face_normals[dir][0])
        append(&mesh.vertices, face_normals[dir][1])
        append(&mesh.vertices, face_normals[dir][2])

        // UV
        append(&mesh.vertices, uvs[v][0])
        append(&mesh.vertices, uvs[v][1])
    }

    append(&mesh.indices, base_index + 0)
    append(&mesh.indices, base_index + 1)
    append(&mesh.indices, base_index + 2)

    append(&mesh.indices, base_index + 2)
    append(&mesh.indices, base_index + 3)
    append(&mesh.indices, base_index + 0)
}


CHUNK_SIZE :: 16
CHUNK_AREA :: CHUNK_SIZE * CHUNK_SIZE
CHUNK_VOLUME :: CHUNK_AREA * CHUNK_SIZE

Chunk :: struct {
    blocks : [CHUNK_VOLUME]Block_ID,
    position : [3]i32,
    // if chunk changed since last update 
    dirty : bool
}

Chunk_Mesh :: struct {
    vertices : [dynamic]f32,
    indices  : [dynamic]u32,

    vao, vbo, ebo : u32
}

chunk_index :: proc(x, y, z: int) -> int {
    return x + CHUNK_SIZE * (y + CHUNK_SIZE * z)
}

chunk_build_mesh :: proc(chunk : ^Chunk, mesh : ^Chunk_Mesh) {
    clear(&mesh.vertices)
    clear(&mesh.indices)

    for z in 0..<CHUNK_SIZE {
        for y in 0..<CHUNK_SIZE {
            for x in 0..<CHUNK_SIZE {
                idx := chunk_index(x, y, z)
                if chunk.blocks[idx] == .Air {
                    continue
                }
                
                // +X
                if !in_bounds(x + 1, y, z) || chunk.blocks[chunk_index(x + 1, y, z)] == .Air {
                    emit_face(mesh, chunk.position, i32(x), i32(y), i32(z), Face_Dir.PosX, chunk.blocks[idx])
                }
                // -X
                if !in_bounds(x - 1, y, z) || chunk.blocks[chunk_index(x - 1, y, z)] == .Air {
                    emit_face(mesh, chunk.position, i32(x), i32(y), i32(z), Face_Dir.NegX, chunk.blocks[idx])
                }
                // +Y    
                if !in_bounds(x, y + 1, z) || chunk.blocks[chunk_index(x, y + 1, z)] == .Air {
                    emit_face(mesh, chunk.position, i32(x), i32(y), i32(z), Face_Dir.PosY, chunk.blocks[idx])
                }
                // -Y
                if !in_bounds(x, y - 1, z) || chunk.blocks[chunk_index(x, y - 1, z)] == .Air {
                    emit_face(mesh, chunk.position, i32(x), i32(y), i32(z), Face_Dir.NegY, chunk.blocks[idx])
                }
                // +Z
                if !in_bounds(x, y, z + 1) || chunk.blocks[chunk_index(x, y, z + 1)] == .Air {
                    emit_face(mesh, chunk.position, i32(x), i32(y), i32(z), Face_Dir.PosZ, chunk.blocks[idx])
                }
                // -Z
                if !in_bounds(x, y, z - 1) || chunk.blocks[chunk_index(x, y, z - 1)] == .Air {
                    emit_face(mesh, chunk.position, i32(x), i32(y), i32(z), Face_Dir.NegZ, chunk.blocks[idx])
                }
            }
        }
    }
}

upload_chunk_mesh :: proc(mesh : ^Chunk_Mesh) {
    if mesh.vao == 0 {
        gl.GenVertexArrays(1, &mesh.vao)
        gl.GenBuffers(1, &mesh.vbo)
        gl.GenBuffers(1, &mesh.ebo)
    }

    gl.BindVertexArray(mesh.vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)
    gl.BufferData(
        gl.ARRAY_BUFFER,
        len(mesh.vertices) * size_of(f32),
        &mesh.vertices[0],
        gl.STATIC_DRAW
    )

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo)
    gl.BufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        len(mesh.indices) * size_of(u32),
        &mesh.indices[0],
        gl.STATIC_DRAW
    )

    // vertex layout (same as your cube)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, stride, uintptr(0))
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, stride, uintptr(3 * size_of(f32)))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, stride, uintptr(6 * size_of(f32)))
    gl.EnableVertexAttribArray(2)

    gl.BindVertexArray(0)
}


draw_chunk_mesh :: proc(chunk_mesh : ^Chunk_Mesh) {
    gl.BindVertexArray(chunk_mesh.vao)
    gl.DrawElements(gl.TRIANGLES, i32(len(chunk_mesh.indices)), gl.UNSIGNED_INT, nil)
}

in_bounds :: proc(x, y, z: int) -> bool {
    return  x >= 0 && x < CHUNK_SIZE && 
            y >= 0 && y < CHUNK_SIZE && 
            z >= 0 && z < CHUNK_SIZE
}

World :: struct {
    chunks      : [dynamic]Chunk,
    chunk_meshes: [dynamic]Chunk_Mesh,
}

WORLD_SIZE_X :: 4
WORLD_SIZE_Z :: 4
WORLD_SIZE_Y :: 1

world : World

init_world :: proc() {
    clear(&world.chunks)
    clear(&world.chunk_meshes)

    for cz in 0..<WORLD_SIZE_Z {
        for cy in 0..<WORLD_SIZE_Y {
            for cx in 0..<WORLD_SIZE_X {
                chunk := Chunk{}
                chunk.position = {i32(cx), i32(cy), i32(cz)}
                chunk.dirty = true

                for z in 0..<CHUNK_SIZE {
                    for y in 0..<CHUNK_SIZE {
                        for x in 0..<CHUNK_SIZE {
                            idx := chunk_index(x, y, z)

                            if y < 5 {
                                chunk.blocks[idx] = .Solid
                            } else {
                                chunk.blocks[idx] = .Air
                            }
                        }
                    }
                }

                append(&world.chunks, chunk)
                append(&world.chunk_meshes, Chunk_Mesh{})
            }
        }
    }
}


main :: proc() {
    // init glfw
    glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
    glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)

    // stop if glfw failed to initialize
    if (glfw.Init() != true) {
        fmt.println("Failed to initialize glfw")
        return
    }
    // terminate if program exits
    defer glfw.Terminate()

    // create window
    window = glfw.CreateWindow(WIDTH, HEIGHT, PROGRAM_NAME, nil, nil)
    // destroy window if program exits
    defer glfw.DestroyWindow(window)

    // stop if window failed to create
    if (window == nil) {
        fmt.println("Unable to create window")
        return
    }

    // set window context
    glfw.MakeContextCurrent(window)
    // set vsync
    glfw.SwapInterval(0)
    // set callbacks
    glfw.SetKeyCallback(window, key_callback)
    glfw.SetFramebufferSizeCallback(window, size_callback)
    glfw.SetCursorPosCallback(window, mouse_callback)
    glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
    // load gl functions
    gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

    init()

    // main loop
    for (!glfw.WindowShouldClose(window) && running) {
        glfw.PollEvents()

        update()
        draw()

        glfw.SwapBuffers(window)
    }

    exit()

}

init :: proc() {
    // load shader
    shader_success : bool
    program, shader_success = gl.load_shaders("shaders/shader.vs", "shaders/shader.fs")
    if !shader_success {
        fmt.println("Failed to load shaders")
        running = false
        return
    }

    // load texture
    width, height, channels: i32
    image_data := stbi.load("textures/atlas.png", &width, &height, &channels, 4)
    fmt.printf("atlas loaded: %dx%d channels=%d\n", width, height, channels)

    if image_data == nil {
        fmt.println("Failed to load texture")
    }
    defer stbi.image_free(image_data)

    // generate texture
    gl.GenTextures(1, &texture)

    // bind texture
    gl.BindTexture(gl.TEXTURE_2D, texture)

    // set texture parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    // load texture data (use i32 for width/height as gl.TexImage2D expects GLsizei)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image_data)

    // enable depth testing
    gl.Enable(gl.DEPTH_TEST)

    u_proj  = gl.GetUniformLocation(program, "u_Projection")
    u_view  = gl.GetUniformLocation(program, "u_View")
    u_model = gl.GetUniformLocation(program, "u_Model")

    init_world()
}

update :: proc() {
    // calculate delta time
    current_frame := glfw.GetTime()
    delta_time = current_frame - last_frame
    last_frame = current_frame
    
    print_fps()

    // update camera
    movement()
}

movement :: proc() {
    CAMERA_SPEED :: 2.5

    // forward / backward
    if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
        camera_pos += camera_front * f32(CAMERA_SPEED * delta_time)
    }
    if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
        camera_pos -= camera_front * f32(CAMERA_SPEED * delta_time)
    }

    // right / left (strafe)
    right := linalg.normalize(linalg.cross(camera_front, camera_up))

    if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
        camera_pos += right * f32(CAMERA_SPEED * delta_time)
    }
    if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
        camera_pos -= right * f32(CAMERA_SPEED * delta_time)
    }

    // up / down (fly cam)
    if glfw.GetKey(window, glfw.KEY_SPACE) == glfw.PRESS {
        camera_pos[1] += f32(CAMERA_SPEED * delta_time)
    }
    if glfw.GetKey(window, glfw.KEY_LEFT_SHIFT) == glfw.PRESS {
        camera_pos[1] -= f32(CAMERA_SPEED * delta_time)
    }
}

draw :: proc() {
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    u_tex := gl.GetUniformLocation(program, "u_Texture")
    gl.UseProgram(program)
    gl.Uniform1i(u_tex, 0)

    // camera direction
    front : [3]f32
    front[0] = math.cos(math.to_radians(yaw)) * math.cos(math.to_radians(pitch))
    front[1] = math.sin(math.to_radians(pitch))
    front[2] = math.sin(math.to_radians(yaw)) * math.cos(math.to_radians(pitch))
    camera_front = linalg.normalize(front)

    view := linalg.matrix4_look_at_f32(camera_pos, camera_pos + camera_front, camera_up)
    proj := linalg.matrix4_perspective_f32(
        math.to_radians_f32(45.0),
        f32(WIDTH)/f32(HEIGHT),
        0.1, 100.0
    )
    model := linalg.MATRIX4F32_IDENTITY
    gl.UniformMatrix4fv(u_model, 1, false, &model[0,0])

    // upload once per frame
    gl.UniformMatrix4fv(u_view, 1, false, &view[0,0])
    gl.UniformMatrix4fv(u_proj, 1, false, &proj[0,0])

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, texture)

    // draw objects
    for i in 0..<len(world.chunks) {
        chunk := &world.chunks[i]
        chunk_mesh := &world.chunk_meshes[i]

        if chunk.dirty {
            chunk_build_mesh(chunk, chunk_mesh)
            chunk.dirty = false
            upload_chunk_mesh(chunk_mesh)
        }
        
        draw_chunk_mesh(chunk_mesh)
    }

}

exit :: proc() {

}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    if key == glfw.KEY_F11 {
        if glfw.GetPrimaryMonitor() != nil {
            glfw.SetWindowMonitor(window, nil, 0, 0, 1920, 1080, 0)
        }
    }

    if key == glfw.KEY_ESCAPE {
        running = false
    }
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
    if first_mouse {
        last_x = xpos
        last_y = ypos
        first_mouse = false
    }

    x_offset := xpos - last_x
    y_offset := last_y - ypos
    last_x = xpos
    last_y = ypos

    MOUSE_SENS :: 0.1
    x_offset *= MOUSE_SENS
    y_offset *= MOUSE_SENS

    yaw   += f32(x_offset)
    pitch += f32(y_offset)

    if pitch >  89.0 { pitch =  89.0 }
    if pitch < -89.0 { pitch = -89.0 }
}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    gl.Viewport(0, 0, width, height)
    WIDTH = width
    HEIGHT = height
}

print_fps :: proc() {
    // print fps to console
    if delta_time > 0.0 {
        fps := 1.0 / delta_time
        fmt.printf("FPS: %.2f\n", fps)
    }
}
