using JulGame.MainLoop 
using Firebase

mutable struct GameManager
    blockedSpaces
    coinSpaces
    currentGamePhase
    gameId
    gamePhases
    gameState
    isLocalPlayerSpawned
    localPlayerState
    otherPlayers
    parent
    playerId
    results
    roomState
    task
    tickRate
    tickTimer
    user 

    function GameManager()
        this = new()

        this.gameState = C_NULL
        this.roomState = C_NULL
        this.tickRate = 12
        this.tickTimer = 0.0
        this.task = C_NULL
        this.otherPlayers = Dict()
        this.localPlayerState = C_NULL
        this.gameId = "null"
        this.gamePhases = [
            "LOBBY",
            "SETUP",
            "PRE",
            "GAME",
            "POST"
            ]
        this.currentGamePhase = this.gamePhases[1]
        this.blockedSpaces = Dict()
        this.coinSpaces = C_NULL
        this.isLocalPlayerSpawned = false
        
        return this
    end
end

function Base.getproperty(this::GameManager, s::Symbol)
    if s == :initialize
        function()
            MAIN.scene.camera.target = JulGame.TransformModule.Transform(JulGame.Math.Vector2f(-3,2))
            MAIN.cameraBackgroundColor = [0, 128, 128]
            name = MAIN.globals[1]
            color = MAIN.globals[2]
            Firebase.realdb_init("https://multiplayer-demo-2f287-default-rtdb.firebaseio.com")
            Firebase.set_webapikey("AIzaSyCxuzQNfmIMijosSYn8UWfQGOrQYARJ4iE")
            this.user = Firebase.firebase_signinanon()
            this.localPlayerState = Dict("name" => name, "color" => color, "x" => 0, "y" => 0, "coins" => 0, "lastUpdate" => 0, "isReady" => false, "gameId" => this.gameId)
            this.playerId = Firebase.realdb_postRealTime("/lobby/$(this.user["localId"])", this.localPlayerState, this.user["idToken"])["name"]
        end
    elseif s == :update
        function(deltaTime)
            this.tickTimer += deltaTime # RATE LIMIT FOR ALL GET REQUESTS

            # IN LOBBY
            # We will be readying up and waiting for a game id to move on to next phase
            if MAIN.input.getButtonPressed("L")
                println(Firebase.realdb_getRealTime("/games/$(this.gameId)", this.user["idToken"]))
            end
            if this.currentGamePhase == this.gamePhases[1]
                if MAIN.input.getButtonPressed("R")
                    this.readyUp()
                end
                if this.gameId == "null" && this.localPlayerState["isReady"]
                    playerData = nothing
                    try
                        @async begin
                            playerData = Firebase.realdb_getRealTime("/lobby/$(this.user["localId"])/$(this.playerId)", this.user["idToken"])
                            this.gameId = playerData["gameId"]
                        end
                            sleep(0.001)
                            this.tickTimer = 0.0
                    catch e
                        print(e)
                    end
                elseif this.gameId != "null" && this.localPlayerState["isReady"] 
                    this.currentGamePhase = this.gamePhases[2]
                end
            end

            # SETUP PHASE
            # We will be spawning other players and ourself in here
            if this.currentGamePhase == this.gamePhases[2]
                #println("test")
                if this.tickTimer >= 1/this.tickRate
                    this.task = this.get()
                    this.tickTimer = 0.0
                end

                if this.gameState == C_NULL || this.gameState === nothing
                    return
                end

                # println(this.gameState["gameState"]["coins"] != C_NULL)
                # println(this.gameState["gameState"]["coins"] !== nothing)
                # println(this.gameState["players"] != C_NULL) 
                # println(this.gameState["players"] !== nothing)
                #println(this.gameState)
                if haskey(this.gameState, "gameState") && haskey(this.gameState["gameState"], "coins") && haskey(this.gameState, "players")
                    #println(this.gameState)
                    sleep(0.001)
                    this.spawnAllCoins()
                    this.spawnAllPlayers()
                    this.currentGamePhase = this.gamePhases[3]
                end
            end
            
            # PREGAME
            # We need to wait for game state to be set here. We need to get:
            # My player position, other player positions & colors, and coin positions. 
            # Based on all of this, we spawn our player, other players, and coins
            # When "gameReady", count down from 3? Start the game
            if this.currentGamePhase == this.gamePhases[3]
                this.currentGamePhase = this.gamePhases[4]
            end

            # CURRENTLY IN GAME
            # Player should be able to move to unoccupied squares. If other players are on square, block our movement
            # If we land on a coin square, collect it
            if this.currentGamePhase == this.gamePhases[4]
                sleep(0.001)
                if this.roomState != C_NULL
                    this.processRoomState()
                    this.roomState = C_NULL
                end
                if this.tickTimer >= 1/this.tickRate
                    this.task = this.get()
                    this.tickTimer = 0.0
                end
            end

            # # GAME IS OVER
            # if this.currentGamePhase == this.gamePhases[3]

            # end

            # # IF WE ARE IN A GAME ROOM
            # if this.currentGamePhase == this.gamePhases[3] && if this.currentGamePhase == this.gamePhases[4]

            # end
        end
    elseif s == :setParent 
        function(parent)
            this.parent = parent
        end
    elseif s == :get
        function ()
            try
                @async begin
                    game = Firebase.realdb_getRealTime("/games/$(this.gameId)", this.user["idToken"])
                    this.roomState = game["players"]
                    this.gameState = game
                    this.coinSpaces = game["gameState"]["coins"]
                end
                    sleep(0.001)
            catch e
                print(e)
            end
        end
    elseif s == :updatePos
        function (position)
            this.localPlayerState["x"] = position.x
            this.localPlayerState["y"] = position.y

            @async Firebase.realdb_putRealTime("/games/$(this.gameId)/players/$(this.user["localId"])", this.localPlayerState)
        end
    elseif s == :readyUp
        function ()
            if this.localPlayerState["isReady"] == true
                return
            end
            println("ready")

            this.localPlayerState["isReady"] = true
            @async Firebase.realdb_putRealTime("/lobby/$(this.user["localId"])/$(this.playerId)", this.localPlayerState, this.user["idToken"])
        end
    elseif s == :processRoomState
        function ()
            try
                for player in this.roomState
                    playerId = player.first
                    
                    if playerId == this.user["localId"] # local player
                    elseif haskey(this.otherPlayers, playerId) # update existing other player
                        this.otherPlayers[playerId][1] = player.second
                        otherPlayerCurrentPosition = this.otherPlayers[playerId][2].getTransform().position
                        otherPlayerCurrentPositionInGrid = "$(otherPlayerCurrentPosition.x + 5)x$(otherPlayerCurrentPosition.y + 3)"
                        # Only update position if it has changed 
                        if (otherPlayerCurrentPosition.x + 5) != player.second["x"] || (otherPlayerCurrentPosition.y + 3) != player.second["y"]
                            if haskey(this.blockedSpaces, otherPlayerCurrentPositionInGrid)
                                delete!(this.blockedSpaces, otherPlayerCurrentPositionInGrid)
                            end
                            otherPlayerNextPosition = JulGame.Math.Vector2f(player.second["x"], player.second["y"])
                            this.blockedSpaces["$(Int(otherPlayerNextPosition.x) + 5)x$(Int(otherPlayerNextPosition.y) + 3)"] = true
                            this.otherPlayers[playerId][2].scripts[1].setNewPosition(otherPlayerNextPosition.x, otherPlayerNextPosition.y)
                        end
                    # todo: remove player
                    end
                end
            catch e
                println(e)
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end
    elseif s == :spawnAllCoins
        function ()
            for (key, value) in this.coinSpaces
                x, y = parse.(Int, split(key, "x"))
                sprite = JulGame.SpriteModule.Sprite(joinpath(pwd(),"..",".."), "coin.png", false)
                sprite1 = JulGame.SpriteModule.Sprite(joinpath(pwd(),"..",".."), "coin-shadow.png", false)

                sprite.injectRenderer(MAIN.renderer)
                sprite1.injectRenderer(MAIN.renderer)
                newCoin = JulGame.EntityModule.Entity("coin", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(x-5,y-3)), [sprite])
                newCoinShadow = JulGame.EntityModule.Entity("coin", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(x-5,y-3)), [sprite1])
                newCoin.addScript(Coin(newCoinShadow))

                push!(MAIN.scene.entities, newCoin)
                push!(MAIN.scene.entities, newCoinShadow)
            end
        end
    elseif s == :spawnAllPlayers
        function ()
            try
                count = 1
                println(this.gameState["players"])
                for player in this.gameState["players"]
                    println("player $(count)")
                    count += 1
                    playerId = player.first
                    
                    if playerId == this.user["localId"] # local player
                        println("spawning local player")
                        this.spawnLocalPlayer(player)
                    else # add new other player
                        println("spawning other player")
                        this.otherPlayers[playerId] = [player.second, this.spawnOtherPlayer(player)]
                    end
                end
            catch e
                println(e)
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end
    elseif s == :spawnLocalPlayer
        function (player)
            colors = ["blue", "pink", "red", "yellow", "green", "purple"]
            colorIndex = findfirst(x -> x == player.second["color"], colors) - 1

            sprite = JulGame.SpriteModule.Sprite(joinpath(pwd(),"..",".."), "characters.png", false)
            sprite.injectRenderer(MAIN.renderer)
            sprite.crop = JulGame.Math.Vector4(16,colorIndex*16,16,16)
            newPlayer = JulGame.EntityModule.Entity("$(MAIN.globals[1])", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(player.second["x"]-5, player.second["y"]-3)), [sprite])
            newPlayer.addScript(PlayerMovement())

            push!(MAIN.scene.entities, newPlayer)
            return newPlayer
        end
    elseif s == :spawnOtherPlayer
        function (player)
            colors = ["blue", "pink", "red", "yellow", "green", "purple"]
            colorIndex = findfirst(x -> x == player.second["color"], colors) - 1

            sprite = JulGame.SpriteModule.Sprite(joinpath(pwd(),"..",".."), "characters.png", false)
            sprite1 = JulGame.SpriteModule.Sprite(joinpath(pwd(),"..",".."), "shadow.png", false)
            sprite.injectRenderer(MAIN.renderer)
          #  sprite1.injectRenderer(MAIN.renderer)
            sprite.crop = JulGame.Math.Vector4(16,colorIndex*16,16,16)
            newPlayer = JulGame.EntityModule.Entity("other player", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(player.second["x"]-5, player.second["y"]-3)), [sprite])
            newPlayer.addScript(OtherPlayerMovement())
            # newPlayerShadow = JulGame.EntityModule.Entity("other player shadow", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(player.second["x"]-5, player.second["y"]-3)), [sprite1])
           # newPlayerShadow.setParent(newPlayer)

            push!(MAIN.scene.entities, newPlayer)
            return newPlayer
        end
    elseif s == :onShutDown
        function ()
            println("shut down")
            Firebase.realdb_deleteRealTime("/lobby/$(this.user["localId"])", this.user["idToken"])
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end