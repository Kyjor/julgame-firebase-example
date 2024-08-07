using JulGame.Macros
using JulGame.MainLoop
using JulGame.SoundSourceModule

mutable struct PlayerMovement
    arrow
    blockedSpaces
    canMove
    elapsedTime
    frozen
    gameManager
    input
    isFacingRight
    parent
    positionBeforeMoving
    shadow
    soundBank
    startingY
    targetPosition
    timeBetweenMoves
    timer
    moveTimer

    function PlayerMovement(followers)
        this = new()

        this.canMove = false
        this.elapsedTime = 0.0
        this.input = C_NULL
        this.isFacingRight = true
        this.parent = C_NULL
        this.gameManager = MAIN.scene.entities[1].scripts[1]
        this.shadow = followers[1]
        this.arrow = followers[2]
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

        # this.soundBank = Dict(
        #     "move"=> SoundSource("player_move.wav", 1, 50),
        #     "can_not_move"=> SoundSource("player_can_not_move.wav", 1, 50),
        # )
        this.frozen = false

        return this
    end
end

function Base.getproperty(this::PlayerMovement, s::Symbol)
    if s == :initialize
        function()
            this.targetPosition = JulGame.Math.Vector2f(this.parent.transform.position.x, this.parent.transform.position.y)
            this.startingY = this.parent.sprite.offset.y

        end
    elseif s == :update
        function(deltaTime)
            currentPosition = this.parent.transform.position
            if this.gameManager.positionUpdate != C_NULL
                this.canMove = false
                this.timer = 0.0

                currentPosition = this.gameManager.positionUpdate
                this.targetPosition = this.gameManager.positionUpdate
                this.parent.transform.position = this.gameManager.positionUpdate
                this.shadow.transform.position = this.gameManager.positionUpdate
                this.arrow.transform.position = JulGame.Math.Vector2f(this.gameManager.positionUpdate.x + 0.30, this.gameManager.positionUpdate.y - 0.9)
                this.frozen = false
                this.gameManager.positionUpdate = C_NULL
                return
            end
            if this.frozen
                return
            end

            input = MAIN.input
           
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
                if JulGame.InputModule.get_button_held_down(input, direction) && this.canMove
                    if JulGame.InputModule.get_button_pressed(input, direction)
                        new_position = JulGame.Math.Vector2f(currentPosition.x + dx, currentPosition.y + dy)
                        if this.canPlayerMoveHere(new_position)
                            this.positionBeforeMoving = currentPosition
                            this.targetPosition = new_position
                        else
                            # this.soundBank["can_not_move"].toggleSound()
                        end
                    end
                    
                    if dx != 0
                        if (dx < 0 && this.isFacingRight) || (dx > 0 && !this.isFacingRight)
                            this.isFacingRight = !this.isFacingRight
                            JulGame.Component.flip(this.parent.sprite)
                        end
                    end
                end
            end

            this.timer += deltaTime
            if this.timer >= this.timeBetweenMoves
                this.canMove = true
            end

            if this.targetPosition.x != this.parent.transform.position.x || this.targetPosition.y != this.parent.transform.position.y
                this.moveTimer += deltaTime
                this.movePlayerSmoothly()
            end 
            
            this.bob()
            this.elapsedTime += deltaTime
        end
    elseif s == :movePlayerSmoothly
        function()
            if this.canMove
                # this.soundBank["move"].toggleSound()
            end

            this.canMove = false
            nextPos = JulGame.Math.Vector2f(JulGame.Math.SmoothLerp(this.positionBeforeMoving.x, this.targetPosition.x, this.moveTimer/this.timeBetweenMoves), JulGame.Math.SmoothLerp(this.positionBeforeMoving.y, this.targetPosition.y, this.moveTimer/this.timeBetweenMoves))
            this.parent.transform.position = nextPos
            this.shadow.transform.position = nextPos
            this.arrow.transform.position = JulGame.Math.Vector2f(nextPos.x + 0.30, nextPos.y - 0.9)
            if (this.moveTimer/this.timeBetweenMoves) >= 1
                this.moveTimer = 0.0
                this.parent.transform.position = this.targetPosition
                this.canMove = true
            end 
        end
    elseif s == :canPlayerMoveHere
        function(nextPosition)
            if nextPosition.x > 0 && nextPosition.x < 14 && nextPosition.y > 3 && nextPosition.y < 12 && !(haskey(this.blockedSpaces, "$(Int(nextPosition.x))x$(Int(nextPosition.y))")) && !(haskey(this.gameManager.blockedSpaces, "$(Int(nextPosition.x))x$(Int(nextPosition.y))"))
                this.canMove = false
                this.timer = 0.0
                this.gameManager.updatePos(nextPosition)
                return true
            end

            return false
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
            this.parent.sprite.offset = JulGame.Math.Vector2f(this.parent.sprite.offset.x, this.startingY + bobOffset)
            this.arrow.sprite.offset = JulGame.Math.Vector2f(this.parent.sprite.offset.x, this.startingY - bobOffset)
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