# commented out to allow for direct execution of this file. If you want to build this project with PackageCompiler, uncomment all of the lines below
#module Entry 
using JulGame.Math
using JulGame.SceneBuilderModule

println("Enter your user name")
playerName = ""
while true
    char_input = strip(readline(stdin))
    if char_input != "" && char_input !== nothing
        global playerName = char_input # Without this being called global, it assumes this is a new local variable with the same name
        break
    end
end
#function run()
    dir = @__DIR__
    #dir = pwd()
    scene = Scene(joinpath(dir, "..", ".."), "scene.json")
    main = scene.init(false, Vector2(1280, 720), 1.25, [playerName])
    return main
#end
    #julia_main() = run()
#end