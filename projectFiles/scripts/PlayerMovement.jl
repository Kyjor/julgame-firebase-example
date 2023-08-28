using JulGame.Macros
using JulGame.MainLoop
using JulGame.SoundSourceModule

mutable struct PlayerMovement
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

    function PlayerMovement()
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
        this.blockedSpaces = Dict(
            "7x4"=> true,
            "1x11"=> true,
            "12x10"=> true,
            "4x7"=> true,
            "5x7"=> true,
            "6x7"=> true,
            "8x6"=> true,
            "9x6"=> true,
            "10x6"=> true,
            "7x9"=> true,
            "8x9"=> true,
            "9x9"=> true)
        
        return this
    end
end

function Base.getproperty(this::PlayerMovement, s::Symbol)
    if s == :initialize
        function()
            this.targetPosition = JulGame.Math.Vector2f(this.parent.getTransform().position.x, this.parent.getTransform().position.y)
        end
    elseif s == :update
        function(deltaTime)
            input = MAIN.input
            currentPosition = this.parent.getTransform().position
            # Inputs match SDL2 scancodes after "SDL_SCANCODE_"
            # https://wiki.libsdl.org/SDL2/SDL_Scancode
            # Spaces full scancode is "SDL_SCANCODE_SPACE" so we use "SPACE". Every other key is the same.
            directions = Dict(
                "A" => (-1, 0),  # Move left
                "D" => (1, 0),   # Move right
                "W" => (0, -1),  # Move up
                "S" => (0, 1)    # Move down
            )

            # Loop through the directions
            for (direction, (dx, dy)) in directions
                if input.getButtonHeldDown(direction) && this.canMove
                    if input.getButtonPressed(direction)
                        new_position = JulGame.Math.Vector2f(currentPosition.x + dx, currentPosition.y + dy)
                        if this.canPlayerMoveHere(new_position)
                            this.positionBeforeMoving = currentPosition
                            this.targetPosition = new_position
                        end
                    end
                    
                    if dx != 0
                        if (dx < 0 && this.isFacingRight) || (dx > 0 && !this.isFacingRight)
                            this.isFacingRight = !this.isFacingRight
                            this.parent.getSprite().flip()
                        end
                    end
                end
            end

            this.timer += deltaTime
            if this.timer >= this.timeBetweenMoves
                this.canMove = true
            end

            if this.targetPosition.x != this.parent.getTransform().position.x || this.targetPosition.y != this.parent.getTransform().position.y
                this.moveTimer += deltaTime
                this.movePlayerSmoothly()
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
    elseif s == :canPlayerMoveHere
        function(nextPosition)
            println(this.gameManager.blockedSpaces)
            if nextPosition.x > -5 && nextPosition.x < 9 && nextPosition.y > 0 && nextPosition.y < 9 && !(haskey(this.blockedSpaces, "$(Int(nextPosition.x) + 5)x$(Int(nextPosition.y) + 3)")) && !(haskey(this.gameManager.blockedSpaces, "$(Int(nextPosition.x) + 5)x$(Int(nextPosition.y) + 3)"))
                this.canMove = false
                this.timer = 0.0
                this.gameManager.updatePos(nextPosition)
                return true
            end

            return false
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