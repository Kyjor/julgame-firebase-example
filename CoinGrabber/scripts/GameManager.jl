using JulGame.MainLoop 

include("firebase.jl")

mutable struct GameManager
    baseUrl
    blockedSpaces
    coinMap
    coinSpaces
    currentGamePhase
    deps
    gameId
    gamePhases
    gameState
    heartbeatCounter
    heartbeatTimer
    isLocalPlayerSpawned
    localPlayerState
    otherPlayers
    parent
    playerId
    results
    roomState
    soundBank
    task
    tickRate
    tickTimer
    timeBetweenHeartbeats
    user 

    function GameManager()
        this = new()

        this.gameState = C_NULL
        this.coinMap = Dict()
        this.roomState = C_NULL
        this.tickRate = 10
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
        this.soundBank = Dict(
            "pickup_coin0"=> SoundSource(joinpath(pwd(),".."), "pickup_coin0.wav", 2, 50),
            "pickup_coin1"=> SoundSource(joinpath(pwd(),".."), "pickup_coin1.wav", 2, 50),
            "pickup_coin2"=> SoundSource(joinpath(pwd(),".."), "pickup_coin2.wav", 2, 50),
            "power_up"=> SoundSource(joinpath(pwd(),".."), "power_up.wav", 2, 50)
        )
        this.heartbeatCounter = 0
        this.heartbeatTimer = 0.0
        this.timeBetweenHeartbeats = 10.0 
        
        return this
    end
end

function Base.getproperty(this::GameManager, s::Symbol)
    if s == :initialize
        function()
            MAIN.scene.camera.target = JulGame.TransformModule.Transform(JulGame.Math.Vector2f(2.5,5))
            MAIN.cameraBackgroundColor = [0, 128, 128]
            name = MAIN.globals[1]
            color = MAIN.globals[2]
            this.deps = MAIN.globals[3]
            #this.parent.getSoundSource().toggleSound(-1)

            this.baseUrl = "https://multiplayer-demo-2f287-default-rtdb.firebaseio.com"
            this.user = firebase_signinanon(this.deps[1], this.deps[2], "AIzaSyCxuzQNfmIMijosSYn8UWfQGOrQYARJ4iE")

            this.localPlayerState = Dict("name" => name, "color" => color, "position" => Dict("x" => 0, "y" => 0,), "coins" => 0, "lastUpdate" => 0, "isReady" => false, "gameId" => this.gameId, "heartbeat" => 0)
            this.playerId = realdb_postRealTime(this.deps[1], this.deps[2], this.baseUrl, "/lobby/$(this.user["localId"])", this.localPlayerState, this.user["idToken"])["name"]
        end
    elseif s == :update
        function(deltaTime)
            this.tickTimer += deltaTime # RATE LIMIT FOR ALL GET REQUESTS
            this.heartbeatTimer += deltaTime

            # IN LOBBY
            # We will be readying up and waiting for a game id to move on to next phase
            if this.currentGamePhase == this.gamePhases[1]
                if MAIN.input.getButtonPressed("R")
                    this.readyUp()
                end
                if this.gameId == "null" && this.localPlayerState["isReady"]
                    playerData = nothing
                    try
                        @async begin
                            playerData = realdb_getRealTime(this.deps[1], this.deps[2], this.baseUrl, "/lobby/$(this.user["localId"])/$(this.playerId)", this.user["idToken"])
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
                if this.tickTimer >= 1/this.tickRate
                    this.task = this.get()
                    this.tickTimer = 0.0
                end

                if this.gameState == C_NULL || this.gameState === nothing
                    return
                end

                if haskey(this.gameState, "gameState") && haskey(this.gameState["gameState"], "coins") && haskey(this.gameState, "players")
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
                MAIN.scene.textBoxes[1].updateText("Coins: 0")
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
                if this.gameState === nothing || this.gameState == C_NULL
                    this.currentGamePhase = this.gamePhases[5]
                end

                this.checkAndRemoveCoins()
            end

            if this.currentGamePhase == this.gamePhases[5]
                MAIN.scene.textBoxes[1].updateText("Game Over")
                return
            end

            if this.heartbeatTimer > this.timeBetweenHeartbeats
                this.sendHeartbeat()
                this.heartbeatTimer = 0.0
            end
        end
    elseif s == :setParent 
        function(parent)
            this.parent = parent
        end
    elseif s == :get
        function ()
            try
                @async begin
                    game = realdb_getRealTime(this.deps[1], this.deps[2], this.baseUrl, "/games/$(this.gameId)", this.user["idToken"])
                    oldGameState = deepcopy(this.gameState)
                    this.gameState = game
                    if oldGameState != C_NULL && oldGameState !== nothing && haskey(oldGameState, "gameState") && haskey(oldGameState["gameState"], "coins") && haskey(oldGameState, "players")
                        if oldGameState["players"][this.user["localId"]]["coins"] < game["players"][this.user["localId"]]["coins"]
                            this.soundBank["pickup_coin$((game["players"][this.user["localId"]]["coins"]-1)%3)"].toggleSound()
                            MAIN.scene.textBoxes[1].updateText("Coins: $(game["players"][this.user["localId"]]["coins"])")
                        end
                    end
                    this.roomState = game["players"]
                    this.coinSpaces = game["gameState"]["coins"]
                end
                    sleep(0.001)
            catch e
                print(e)
            end
        end
    elseif s == :updatePos
        function (position)
            newPos = Dict()
            newPos["x"] = position.x
            newPos["y"] = position.y

            @async realdb_putRealTime(this.deps[1], this.deps[2], this.baseUrl, "/games/$(this.gameId)/players/$(this.user["localId"])/position", newPos)
        end
    elseif s == :sendHeartbeat
        function ()
            this.heartbeatCounter += 1
            if this.currentGamePhase == this.gamePhases[1]
                realdb_putRealTime(this.deps[1], this.deps[2], this.baseUrl, "/lobby/$(this.user["localId"])/$(this.playerId)/heartbeat", this.heartbeatCounter)
            else
                @async realdb_putRealTime(this.deps[1], this.deps[2], this.baseUrl, "/games/$(this.gameId)/players/$(this.user["localId"])/heartbeat", this.heartbeatCounter)
            end
        end
    elseif s == :readyUp
        function ()
            if this.localPlayerState["isReady"] == true
                return
            end

            MAIN.scene.textBoxes[1].updateText("Waiting for other players")
            this.soundBank["power_up"].toggleSound()

            this.localPlayerState["isReady"] = true
            @async realdb_putRealTime(this.deps[1], this.deps[2], this.baseUrl, "/lobby/$(this.user["localId"])/$(this.playerId)", this.localPlayerState, this.user["idToken"])
        end
    elseif s == :processRoomState
        function ()
            try
                this.blockedSpaces = Dict()
                for player in this.roomState
                    playerId = player.first
                    
                    if playerId == this.user["localId"] # local player
                    elseif haskey(this.otherPlayers, playerId) # update existing other player
                        this.otherPlayers[playerId][1] = player.second
                        otherPlayerCurrentTargetPosition = this.otherPlayers[playerId][2].scripts[1].targetPosition
                        #otherPlayerCurrentPositionInGrid = "$(otherPlayerCurrentPosition.x)x$(otherPlayerCurrentPosition.y)"
                        # Only update position if it has changed 
                        this.blockedSpaces["$(Int(player.second["position"]["x"]))x$(Int(player.second["position"]["y"]))"] = true
                        if (otherPlayerCurrentTargetPosition.x) != player.second["position"]["x"] || (otherPlayerCurrentTargetPosition.y) != player.second["position"]["y"]
                            otherPlayerNextPosition = JulGame.Math.Vector2f(player.second["position"]["x"], player.second["position"]["y"])
                            this.blockedSpaces["$(Int(otherPlayerNextPosition.x))x$(Int(otherPlayerNextPosition.y))"] = true
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
                sprite = JulGame.SpriteModule.Sprite(joinpath(pwd(),".."), "coin.png")
                sprite1 = JulGame.SpriteModule.Sprite(joinpath(pwd(),".."), "coin-shadow.png")

                sprite.injectRenderer(MAIN.renderer)
                sprite1.injectRenderer(MAIN.renderer)
                newCoin = JulGame.EntityModule.Entity("coin", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(x,y)), [sprite])
                newCoinShadow = JulGame.EntityModule.Entity("coin", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(x,y)), [sprite1])
                newCoin.addScript(Coin(newCoinShadow))
                
                push!(MAIN.scene.entities, newCoin)
                push!(MAIN.scene.entities, newCoinShadow)
                
                this.coinMap[key] = [newCoin, newCoinShadow]
            end
        end
    elseif s == :checkAndRemoveCoins
        function ()

            if this.gameState !== nothing && haskey(this.gameState["gameState"], "coins") && length(this.gameState["gameState"]["coins"]) != length(this.coinMap)
                for (key, value) in this.coinMap
                    if haskey(this.gameState["gameState"]["coins"], key)
                        continue
                    end

                    coinIndex = findfirst(x -> x == this.coinMap[key][1], MAIN.scene.entities)
                    deleteat!(MAIN.scene.entities, coinIndex)
                    coinShadowIndex = findfirst(x -> x == this.coinMap[key][2], MAIN.scene.entities)
                    deleteat!(MAIN.scene.entities, coinShadowIndex)
                    delete!(this.coinMap, key)
                end
            elseif this.gameState !== nothing && !haskey(this.gameState["gameState"], "coins") && length(this.coinMap) == 1
                for (key, value) in this.coinMap
                    coinIndex = findfirst(x -> x == this.coinMap[key][1], MAIN.scene.entities)
                    deleteat!(MAIN.scene.entities, coinIndex)
                    coinShadowIndex = findfirst(x -> x == this.coinMap[key][2], MAIN.scene.entities)
                    deleteat!(MAIN.scene.entities, coinShadowIndex)
                    delete!(this.coinMap, key)
                end
            end

        end
    elseif s == :spawnAllPlayers
        function ()
            try
                count = 1
                for player in this.gameState["players"]
                    count += 1
                    playerId = player.first
                    
                    if playerId == this.user["localId"] # local player
                        this.spawnLocalPlayer(player)
                    else # add new other player
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

            sprite = JulGame.SpriteModule.Sprite(joinpath(pwd(),".."), "characters.png")
            sprite1 = JulGame.SpriteModule.Sprite(joinpath(pwd(),".."), "shadow.png")
            sprite2 = JulGame.SpriteModule.Sprite(joinpath(pwd(),".."), "arrow.png")
            sprite.injectRenderer(MAIN.renderer)
            sprite1.injectRenderer(MAIN.renderer)
            sprite2.injectRenderer(MAIN.renderer)
            sprite.crop = JulGame.Math.Vector4(16,colorIndex*16,16,16)
            newPlayer = JulGame.EntityModule.Entity("$(MAIN.globals[1])", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(player.second["position"]["x"], player.second["position"]["y"])), [sprite])
            newPlayerShadow = JulGame.EntityModule.Entity("$(MAIN.globals[1]) shadow", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(player.second["position"]["x"], player.second["position"]["y"])), [sprite1])
            newPlayerArrow = JulGame.EntityModule.Entity("$(MAIN.globals[1]) arrow", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(player.second["position"]["x"] + 0.30, player.second["position"]["y"] - 0.9), JulGame.Math.Vector2f(0.5, 0.25)), [sprite2])
            newPlayer.addScript(PlayerMovement([newPlayerShadow, newPlayerArrow]))

            push!(MAIN.scene.entities, newPlayerShadow)
            push!(MAIN.scene.entities, newPlayer)
            push!(MAIN.scene.entities, newPlayerArrow)
            return newPlayer
        end
    elseif s == :spawnOtherPlayer
        function (player)
            colors = ["blue", "pink", "red", "yellow", "green", "purple"]
            colorIndex = findfirst(x -> x == player.second["color"], colors) - 1

            sprite = JulGame.SpriteModule.Sprite(joinpath(pwd(),".."), "characters.png")
            sprite1 = JulGame.SpriteModule.Sprite(joinpath(pwd(),".."), "shadow.png")
            sprite.injectRenderer(MAIN.renderer)
            sprite1.injectRenderer(MAIN.renderer)
            sprite.crop = JulGame.Math.Vector4(16,colorIndex*16,16,16)
            newPlayer = JulGame.EntityModule.Entity("other player", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(player.second["position"]["x"], player.second["position"]["y"])), [sprite])
            newPlayerShadow = JulGame.EntityModule.Entity("other player shadow", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(player.second["position"]["x"], player.second["position"]["y"])), [sprite1])
            newPlayer.addScript(OtherPlayerMovement(newPlayerShadow))

            push!(MAIN.scene.entities, newPlayerShadow)
            push!(MAIN.scene.entities, newPlayer)
            return newPlayer
        end
    elseif s == :onShutDown
        function ()
            realdb_deleteRealTime(this.deps[1], this.deps[2], this.baseUrl, "/lobby/$(this.user["localId"])", this.user["idToken"])
            if this.currentGamePhase == this.gamePhases[4] || this.currentGamePhase == this.gamePhases[5]
                realdb_deleteRealTime(this.deps[1], this.deps[2], this.baseUrl, "/games/$(this.gameId)/players/$(this.user["localId"])", this.user["idToken"])
            end
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end