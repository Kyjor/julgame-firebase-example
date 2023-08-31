using JulGame.Macros
using JulGame.MainLoop
using JulGame.SoundSourceModule

mutable struct OtherPlayerMovement
    elapsedTime
    gameManager
    isFacingRight
    parent
    positionBeforeMoving
    shadow
    startingY
    targetPosition
    timeBetweenMoves
    moveTimer

    function OtherPlayerMovement(shadow)
        this = new()

        this.elapsedTime = 0.0
        this.isFacingRight = true
        this.parent = C_NULL
        this.gameManager = MAIN.scene.entities[1].scripts[1]
        this.moveTimer = 0.0
        this.shadow = shadow
        this.targetPosition = JulGame.Math.Vector2f()
        this.timeBetweenMoves = 0.1
        this.positionBeforeMoving = JulGame.Math.Vector2f()
        
        return this
    end
end

function Base.getproperty(this::OtherPlayerMovement, s::Symbol)
    if s == :initialize
        function()
            this.targetPosition = JulGame.Math.Vector2f(this.parent.getTransform().position.x, this.parent.getTransform().position.y)
            this.startingY = this.parent.getSprite().offset.y
        end
    elseif s == :update
        function(deltaTime)
            if this.targetPosition.x != this.parent.getTransform().position.x || this.targetPosition.y != this.parent.getTransform().position.y
                this.moveTimer += deltaTime
                this.movePlayerSmoothly()
            end  

            this.bob()
            this.elapsedTime += deltaTime
        end
    elseif s == :setNewPosition
        function(x,y)
            this.positionBeforeMoving = this.parent.getTransform().position
            this.targetPosition = JulGame.Math.Vector2f(x, y)
            if this.positionBeforeMoving.x < this.targetPosition.x && !this.isFacingRight
                this.isFacingRight = true
                this.parent.getSprite().flip()
            elseif this.positionBeforeMoving.x > this.targetPosition.x && this.isFacingRight
                this.isFacingRight = false
                this.parent.getSprite().flip()
            end

        end
    elseif s == :movePlayerSmoothly
        function()
            nextPos = JulGame.Math.Vector2f(JulGame.Math.SmoothLerp(this.positionBeforeMoving.x, this.targetPosition.x, this.moveTimer/this.timeBetweenMoves), JulGame.Math.SmoothLerp(this.positionBeforeMoving.y, this.targetPosition.y, this.moveTimer/this.timeBetweenMoves))
            this.parent.getTransform().position = nextPos
            this.shadow.getTransform().position = nextPos
            if (this.moveTimer/this.timeBetweenMoves) >= 1
                this.moveTimer = 0.0
                this.parent.getTransform().position = this.targetPosition
            end 
        end
    elseif s == :bob
        function()
            # Define bobbing parameters
            bobHeight = -0.20  # The maximum height the item will bob
            bobSpeed = 2.0   # The speed at which the item bobs up and down
            minBobHeight = -0.10

            # Calculate a sine wave for bobbing motion
            bobOffset = minBobHeight + bobHeight * (1.0 - cos(bobSpeed * this.elapsedTime)) / 2.0
        
            # Update the item's Y-coordinate
            this.parent.getSprite().offset = JulGame.Math.Vector2f(this.parent.getSprite().offset.x, this.startingY + bobOffset)
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end