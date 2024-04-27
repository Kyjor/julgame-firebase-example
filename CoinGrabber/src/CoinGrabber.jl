module CoinGrabber
    using JulGame
    using JulGame.Math
    using JulGame.SceneBuilderModule
    using HTTP, JSON
    const HTTP_ = HTTP
    const JSON_ = JSON

    function run()
        # Map the color choice to the corresponding color
        colors = ["blue", "pink", "red", "yellow", "green", "purple"]
        chosenColor = colors[rand(1:length(colors))]

        scene = Scene("scene.json")
        main = scene.init("Coin Grabber", false, Vector2(), Vector2(1280, 720), false, 1.0, true, 60.0, ["player", chosenColor, [HTTP,JSON]])
        return main
    end

    julia_main() = run()
end
# comment when building
CoinGrabber.run()