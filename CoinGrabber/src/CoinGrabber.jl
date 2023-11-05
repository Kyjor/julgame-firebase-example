module CoinGrabber
    using JulGame
    using JulGame.Math
    using JulGame.SceneBuilderModule
    using HTTP, JSON
    const HTTP_ = HTTP
    const JSON_ = JSON

    function run()
        SDL2.init()

        global playerName = "toto"

        # Map the color choice to the corresponding color
        colors = ["blue", "pink", "red", "yellow", "green", "purple"]
        chosenColor = colors[rand(1:length(colors))]

        dir = joinpath(pwd(), "..") 
        scene = Scene(dir, "scene.json")
        main = scene.init(false, Vector2(1280, 720), 1.25, 60.0, [playerName, chosenColor, [HTTP,JSON]])
        return main
    end

    julia_main() = run()
end
# comment when building
CoinGrabber.run()