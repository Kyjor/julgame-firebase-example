using JulGame.Macros
using JulGame.MainLoop
using JulGame.SoundSourceModule

mutable struct OtherPlayerMovement
    #animator
    blockedSpaces
    canMove
    gameManager
    input
    isFacingRight
    parent
    positionBeforeMoving
    targetPosition
    timeBetweenMoves
    timer
    moveTimer

    function OtherPlayerMovement()
        this = new()

        this.canMove = false
        this.input = C_NULL
        this.isFacingRight = true
        this.parent = C_NULL
        this.gameManager = MAIN.scene.entities[1].scripts[1]
        this.timeBetweenMoves = 0.2
        this.timer = 0.0
        this.moveTimer = 0.0
        this.targetPosition = JulGame.Math.Vector2f()
        this.positionBeforeMoving = JulGame.Math.Vector2f()
        
        return this
    end
end

function Base.getproperty(this::OtherPlayerMovement, s::Symbol)
    if s == :initialize
        function()
            this.targetPosition = JulGame.Math.Vector2f(this.parent.getTransform().position.x, this.parent.getTransform().position.y)
        end
    elseif s == :update
        function(deltaTime)
        # if (dx < 0 && this.isFacingRight) || (dx > 0 && !this.isFacingRight)
        #     this.isFacingRight = !this.isFacingRight
        #     this.parent.getSprite().flip()
        # end

            this.timer += deltaTime

            if this.targetPosition.x != this.parent.getTransform().position.x || this.targetPosition.y != this.parent.getTransform().position.y
                this.moveTimer += deltaTime
                this.movePlayerSmoothly()
            end  
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
            this.canMove = false
            this.parent.getTransform().position = JulGame.Math.Vector2f(JulGame.Math.SmoothLerp(this.positionBeforeMoving.x, this.targetPosition.x, this.moveTimer/this.timeBetweenMoves), JulGame.Math.SmoothLerp(this.positionBeforeMoving.y, this.targetPosition.y, this.moveTimer/this.timeBetweenMoves))
            if (this.moveTimer/this.timeBetweenMoves) >= 1
                this.moveTimer = 0.0
                this.parent.getTransform().position = this.targetPosition
                this.canMove = true
            end 
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