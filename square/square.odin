package triangle

import "core:fmt"
import "core:c"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6
PROGRAM_NAME :: "Program"

running : b32 = true

program, vao, vbo, ebo : u32

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
    window := glfw.CreateWindow(512, 512, PROGRAM_NAME, nil, nil)
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
         0.5,  0.5, 0.0, // Top Right
         0.5, -0.5, 0.0, // Bottom Right
        -0.5, -0.5, 0.0, // Bottom Left
        -0.5,  0.5, 0.0, // Top Left
    }

    indices := [?]u32{
        0, 1, 3, // First Triangle
        1, 2, 3, // Second Triangle
    }

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

}

draw :: proc() {
    // clear screen
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    // draw triangle
    gl.UseProgram(program)
    gl.BindVertexArray(vao)
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
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
}
