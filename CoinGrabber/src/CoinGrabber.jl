module CoinGrabber
using JulGame
using JulGame.Math
using JulGame.SceneBuilderModule
using HTTP, JSON
const HTTP_ = HTTP
const JSON_ = JSON

    function run()
        SDL2.init()

        println("Enter your user name")
        global playerName = ""
        while true
            char_input = strip(readline(stdin))
            if char_input != "" && char_input !== nothing
                playerName = char_input # Without this being called global, it assumes this is a new local variable with the same name
                break
            end
        end


        println("Choose your color:")
        println("1: blue")
        println("2: pink")
        println("3: red")
        println("4: yellow")
        println("5: green")
        println("6: purple")

        global colorChoice = 1

        while true
            color_input = readline(stdin)
            try
                colorChoice = parse(Int, color_input)
                if 1 <= colorChoice <= 6
                    break
                else
                    println("Invalid choice. Please enter a number between 1 and 6.")
                end
            catch
                println("Invalid input. Please enter a number between 1 and 6.")
            end
        end

        # Map the color choice to the corresponding color
        colors = ["blue", "pink", "red", "yellow", "green", "purple"]
        chosenColor = colors[colorChoice]

        dir = joinpath(pwd(), "..") 
        println("Hello, $(playerName)! You chose the color $chosenColor.")

        println(dir)
        scene = Scene(dir, "scene.json")
        main = scene.init(false, Vector2(1280, 720), 1.25, [playerName, chosenColor, [HTTP,JSON]])
        return main
    end

    julia_main() = run()
end