package cube

import "core:fmt"
import "core:c"
import "core:math"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "core:math/linalg"

GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6
PROGRAM_NAME :: "Program"

running : b32 = true
program, vao, vbo, ebo : u32
WIDTH, HEIGHT : i32 = 512, 512

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
    window := glfw.CreateWindow(WIDTH, HEIGHT, PROGRAM_NAME, nil, nil)
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
        -0.5, -0.5,  0.5, // Left Bottom
         0.5, -0.5,  0.5, // Right Bottom
         0.5,  0.5,  0.5, // Right Top
        -0.5,  0.5,  0.5, // Left Top

        // Back
        -0.5, -0.5, -0.5, // Left Bottom
         0.5, -0.5, -0.5, // Right Bottom
         0.5,  0.5, -0.5, // Right Top
        -0.5,  0.5, -0.5, // Left Top
    }

    indices := [?]u32{
        // Front
        0, 1, 2, 2, 3, 0,
        // Right
        1, 5, 6, 6, 2, 1,
        // Back
        7, 6, 5, 5, 4, 7,
        // Left
        4, 0, 3, 3, 7, 4,
        // Bottom
        4, 5, 1, 1, 0, 4,
        // Top
        3, 2, 6, 6, 7, 3,
    }

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
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), uintptr(0))
    gl.EnableVertexAttribArray(0)

    // unbind buffers
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
}

update :: proc() {
    rotation := [3]f32{0.5, 1.0, 0.0}

    camera_pos := [3]f32{0.0, 0.0, 3.0}
    look_at := [3]f32{0.0, 0.0, 0.0}
    where_up_is := [3]f32{0.0, 1.0, 0.0}

    model := linalg.matrix4_rotate_f32(0.5 * f32(glfw.GetTime()), rotation)
    view := linalg.matrix4_look_at_f32(camera_pos, look_at, where_up_is)
    proj := linalg.matrix4_perspective_f32(math.to_radians(f32(45.0)), f32(WIDTH)/f32(HEIGHT), 0.1, 100.0)

    mvp := proj * view * model

    u_mvp := gl.GetUniformLocation(program, "u_MVP")
    gl.UniformMatrix4fv(u_mvp, 1, false, &mvp[0, 0])
}

draw :: proc() {
    // clear screen
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    // draw cube
    gl.UseProgram(program)
    gl.BindVertexArray(vao)
    gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, nil)
}

exit :: proc() {

}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    if key == glfw.KEY_ESCAPE {
        running = false
    }
}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    gl.Viewport(0, 0, width, height)
    WIDTH = width
    HEIGHT = height
}
