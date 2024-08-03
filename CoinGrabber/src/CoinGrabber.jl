module CoinGrabber
    using JulGame
    using JulGame.Math
    using JulGame.SceneBuilderModule
    using HTTP, JSON

    function run()
        JulGame.MAIN = JulGame.Main(Float64(1.0))
        JulGame.PIXELS_PER_UNIT = 16
        # Map the color choice to the corresponding color
        colors = ["blue", "pink", "red", "yellow", "green", "purple"]
        chosenColor = colors[rand(1:length(colors))]

        scene = SceneBuilderModule.Scene("scene.json")
        return SceneBuilderModule.load_and_prepare_scene(scene, "Coin Grabber", false, Vector2(),Vector2(1920,1080), true, 1.0, true, 60, ["player", chosenColor, [HTTP,JSON]])

        return main
    end

    julia_main() = run()
end
# comment when building
CoinGrabber.run()