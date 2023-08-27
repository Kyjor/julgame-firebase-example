using JulGame.MainLoop 
using Firebase

mutable struct GameManager
    currentGamePhase
    gameId
    gamePhases
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

        this.roomState = C_NULL
        this.tickRate = 12
        this.tickTimer = 0.0
        this.task = C_NULL
        this.otherPlayers = Dict()
        this.localPlayerState = C_NULL
        this.gameId = "null"
        this.gamePhases = [
            "LOBBY",
            "PRE",
            "GAME",
            "POST"
            ]
        this.currentGamePhase = this.gamePhases[1]

        return this
    end
end

function Base.getproperty(this::GameManager, s::Symbol)
    if s == :initialize
        function()
            MAIN.scene.camera.target = JulGame.TransformModule.Transform(JulGame.Math.Vector2f(-3,2))
            MAIN.cameraBackgroundColor = [0, 128, 128]
            name = MAIN.globals[1]
            Firebase.realdb_init("https://multiplayer-demo-2f287-default-rtdb.firebaseio.com")
            Firebase.set_webapikey("AIzaSyCxuzQNfmIMijosSYn8UWfQGOrQYARJ4iE")
            this.user = Firebase.firebase_signinanon()
            this.localPlayerState = Dict("name" => name, "color" => "blue", "x" => 0, "y" => 0, "coins" => 0, "lastUpdate" => 0, "isReady" => false, "gameId" => this.gameId)
            this.playerId = Firebase.realdb_postRealTime("/lobby/$(this.user["localId"])", this.localPlayerState, this.user["idToken"])["name"]
        end
    elseif s == :update
        function(deltaTime)
            this.tickTimer += deltaTime # RATE LIMIT FOR ALL GET REQUESTS

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
                            playerData = Firebase.realdb_getRealTime("/lobby/$(this.user["localId"])/$(this.playerId)", this.user["idToken"])
                            this.gameId = playerData["gameId"]
                        end
                            sleep(0.001)
                            this.tickTimer = 0.0
                    catch e
                        print(e)
                    end
                elseif this.gameId != "null" && this.localPlayerState["isReady"] 
                    this.currentGamePhase = this.gamePhases[3]
                end
            end

            # PREGAME, OUT OF LOBBY
            # We need to wait for game state to be set here. We need to get:
            # My player position, other player positions & colors, and coin positions. 
            # Based on all of this, we spawn our player, other players, and coins
            # When "gameReady", count down from 3? Start the game
            if this.currentGamePhase == this.gamePhases[2]
                println("test")
            end

            # CURRENTLY IN GAME
            # Player should be able to move to unoccupied squares. If other players are on square, block our movement
            # If we land on a coin square, collect it
            if this.currentGamePhase == this.gamePhases[3]
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

            # # if this.roomState !== nothing && this.roomState != C_NULL # Not sure why this is needed, but it doesn't work without it
            # #     try
            # #         this.roomState = C_NULL
            # #     catch e
            # #         this.task = C_NULL
            # #         println(e)
            # #         Base.show_backtrace(stderr, catch_backtrace())
            # #     end
            # # end
        end
    elseif s == :setParent 
        function(parent)
            this.parent = parent
        end
    elseif s == :get
        function ()
            res = nothing
            try
                @async begin
                    this.roomState = Firebase.realdb_getRealTime("/games/$(this.gameId)/players", this.user["idToken"])
                end
                    sleep(0.001)
            catch e
                print(e)
            end
            this.roomState = res
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
                        this.otherPlayers[playerId][2].getTransform().position = JulGame.Math.Vector2f(player.second["x"], player.second["y"])
                    elseif !haskey(this.otherPlayers, playerId) # add new other player
                        this.otherPlayers[playerId] = [player.second, this.spawnOtherPlayer()]
                    # todo: remove player
                    end
                end
            catch
            end
        end
    elseif s == :spawnOtherPlayer
        function ()
            sprite = JulGame.SpriteModule.Sprite(joinpath(pwd(),"..",".."), "characters.png", false)
            sprite.injectRenderer(MAIN.renderer)
            sprite.crop = JulGame.Math.Vector4(16,0,16,16)
            newPlayer = JulGame.EntityModule.Entity("other player", JulGame.TransformModule.Transform(JulGame.Math.Vector2f(-2,7)), [sprite])

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