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
            this.startingY = this.parent.transform.position.y

        end
    elseif s == :update
        function(deltaTime)
            this.bob()
            this.elapsedTime += deltaTime
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :bob
        function()
            # Define bobbing parameters
            bobHeight = 0.250  # The maximum height the item will bob
            bobSpeed = 2.0   # The speed at which the item bobs up and down
            scaleRange = 0.2
            minBobHeight = -0.20  # The minimum height for bobbing

            # Calculate a sine wave for bobbing motion
            bobOffset = minBobHeight + bobHeight * (1.0 - cos(bobSpeed * this.elapsedTime)) / 2.0
            scaleOffset = scaleRange * (1.0 - cos(bobSpeed * this.elapsedTime)) / 2.0
        
            # Update the item's Y-coordinate
            this.parent.transform.position = JulGame.Math.Vector2f(this.parent.transform.position.x, this.startingY + bobOffset)
            this.shadow.transform.scale = JulGame.Math.Vector2f(1.0 + scaleOffset, 1.0 - scaleOffset)
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end