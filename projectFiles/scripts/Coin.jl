using JulGame.Macros
using JulGame.MainLoop
using JulGame.SoundSourceModule

mutable struct Coin
    elapsedTime
    parent
    shadow
    startingY
    
    function Coin(shadow)
        this = new()

        this.elapsedTime = 0.0
        this.shadow = shadow

        return this
    end
end

function Base.getproperty(this::Coin, s::Symbol)
    if s == :initialize
        function()
        this.startingY = this.parent.getTransform().position.y

        end
    elseif s == :update
        function(deltaTime)
            this.bob(deltaTime)
            this.elapsedTime += deltaTime
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :bob
        function(deltaTime)
            # Define bobbing parameters
            bobHeight = 0.250  # The maximum height the item will bob
            bobSpeed = 2.0   # The speed at which the item bobs up and down
        
            # Calculate a sine wave for bobbing motion
            bobOffset = bobHeight * sin(bobSpeed * this.elapsedTime)
        
            # Update the item's Y-coordinate
            this.parent.getTransform().position = JulGame.Math.Vector2f(this.parent.getTransform().position.x, this.startingY + bobOffset)
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end