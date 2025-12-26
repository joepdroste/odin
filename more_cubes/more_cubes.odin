package more_cubes

import "core:math/rand"
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

WIDTH, HEIGHT : i32 = 512, 512
block_positions : [dynamic][3]f32

camera_pos := [3]f32{0.0, 0.0, 3.0}
camera_front := [3]f32{0.0, 0.0, -1.0}
camera_up := [3]f32{0.0, 1.0, 0.0}
yaw   : f32 = -90.0
pitch : f32 = 0.0

last_x, last_y : f64 = 250.0, 250.0
first_mouse := true

delta_time := f64(0.0)
last_frame := f64(0.0)

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
    glfw.SwapInterval(1)
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

    // define vertex data
    vertices := [?]f32{
        // Front
        -0.5, -0.5,  0.5,  0.0, 0.0, // Left Bottom
        0.5, -0.5,  0.5,  1.0, 0.0, // Right Bottom
        0.5,  0.5,  0.5,  1.0, 1.0, // Right Top
        -0.5,  0.5,  0.5,  0.0, 1.0, // Left Top

        // Right
        0.5, -0.5,  0.5,  0.0, 0.0, // Left Bottom
        0.5, -0.5, -0.5,  1.0, 0.0, // Right Bottom
        0.5,  0.5, -0.5,  1.0, 1.0, // Right Top
        0.5,  0.5,  0.5,  0.0, 1.0, // Left Top

        // Back
        0.5, -0.5, -0.5,  0.0, 0.0, // Left Bottom
        -0.5, -0.5, -0.5,  1.0, 0.0, // Right Bottom
        -0.5,  0.5, -0.5,  1.0, 1.0, // Right Top
        0.5,  0.5, -0.5,  0.0, 1.0, // Left Top

        // Left
        -0.5, -0.5, -0.5,  0.0, 0.0, // Left Bottom
        -0.5, -0.5,  0.5,  1.0, 0.0, // Right Bottom
        -0.5,  0.5,  0.5,  1.0, 1.0, // Right Top
        -0.5,  0.5, -0.5,  0.0, 1.0, // Left Top

        // Bottom
        -0.5, -0.5, -0.5,  0.0, 0.0, // Left Bottom
        0.5, -0.5, -0.5,  1.0, 0.0, // Right Bottom
        0.5, -0.5,  0.5,  1.0, 1.0, // Right Top
        -0.5, -0.5,  0.5,  0.0, 1.0, // Left Top

        // Top
        -0.5,  0.5,  0.5,  0.0, 0.0, // Left Bottom
        0.5,  0.5,  0.5,  1.0, 0.0, // Right Bottom
        0.5,  0.5, -0.5,  1.0, 1.0, // Right Top
        -0.5,  0.5, -0.5,  0.0, 1.0, // Left Top
    }



    indices := [?]u32{
        // Front
        0,  1,  2,  2,  3,  0,

        // Right
        4,  5,  6,  6,  7,  4,

        // Back
        8,  9, 10, 10, 11,  8,

        // Left
        12, 13, 14, 14, 15, 12,

        // Bottom
        16, 17, 18, 18, 19, 16,

        // Top
        20, 21, 22, 22, 23, 20,
    }

    // load texture
    // flip y axis (because opengl is upside down)
    stbi.set_flip_vertically_on_load(1)
    width, height, channels: c.int
    image_data := stbi.load("textures/cobble_16x16.png", &width, &height, &channels, 4)
    if image_data == nil {
        fmt.println("Failed to load texture")
    }
    defer stbi.image_free(image_data)

    // generate texture
    gl.GenTextures(1, &texture)

    // bind texture
    gl.BindTexture(gl.TEXTURE_2D, texture)

    // set texture parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    // load texture data
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image_data)

    // enable depth testing
    gl.Enable(gl.DEPTH_TEST)

    // generate buffers
    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.GenBuffers(1, &ebo)

    // bind buffers
    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)

    // load buffer data
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

    // set vertex attributes
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(0))
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(3 * size_of(f32)))
    gl.EnableVertexAttribArray(1)

    // unbind buffers
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    // generate world data once
    for x := 0; x < 10; x += 1 {
        for y := 0; y < 10; y += 1 {
            for z := 0; z < 10; z += 1 {
                if rand.float32() > 0.5 {
                    append(&block_positions, [3]f32{f32(x), f32(y), f32(z)})
                }
            }
        }
    }
}

update :: proc() {
    // calculate delta time
    current_frame := glfw.GetTime()
    delta_time = current_frame - last_frame
    last_frame = current_frame

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
    // clear screen
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    gl.UseProgram(program)
    gl.BindVertexArray(vao)
    gl.BindTexture(gl.TEXTURE_2D, texture)

    // 1. Calculate View and Projection once per frame
    // calculate look direction
    front : [3]f32
    front[0] = math.cos(math.to_radians(yaw)) * math.cos(math.to_radians(pitch))
    front[1] = math.sin(math.to_radians(pitch))
    front[2] = math.sin(math.to_radians(yaw)) * math.cos(math.to_radians(pitch))
    camera_front = linalg.normalize(front)

    view := linalg.matrix4_look_at_f32(camera_pos, camera_pos + camera_front, camera_up)
    proj := linalg.matrix4_perspective_f32(math.to_radians(f32(45.0)), f32(WIDTH)/f32(HEIGHT), 0.1, 100.0)

    for pos in block_positions {
        draw_block(pos, view, proj)
    }
}

draw_block :: proc(pos: [3]f32, view, proj: matrix[4, 4]f32) {
    // Create model matrix for this specific position
    model := linalg.matrix4_translate_f32(pos)
    mvp := proj * view * model

    u_mvp := gl.GetUniformLocation(program, "u_MVP")
    gl.UniformMatrix4fv(u_mvp, 1, false, &mvp[0, 0])
    gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, nil)
}

exit :: proc() {
    delete(block_positions)
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
