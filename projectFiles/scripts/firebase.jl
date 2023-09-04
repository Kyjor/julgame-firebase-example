using HTTP, JSON

function firebase_signinanon(WEB_API_KEY, returnSecureToken::Bool=true)
    http_response = HTTP.post("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$WEB_API_KEY",
    header="""{Content-Type: application/json}""",
    body="""{"returnSecureToken":"$returnSecureToken"}""")
    response_string = String(http_response.body)
    return JSON.parse(response_string)
  end

function realdb_postRealTime(baseUrl, url, body = Dict("name" => "real_db_test"), auth = "null")
    final_url = "$baseUrl$url.json?auth=$auth"
    #println("FINAL URL:", final_url)
    body = JSON.json(body)
    println("Body:", body)
    res = HTTP.post(final_url, "", body)
    if res.status == 200
        println("POST successful")
    else
        println("POST errored")
    end
    return JSON.parse(String(res.body))
end

function realdb_getRealTime(baseUrl, url, auth = "null")
    final_url = "$baseUrl$url.json?auth=$auth"
    #print("FINAL URL:", final_url)
    res = HTTP.get(final_url)
    if res.status == 200
        #println("GET successful")
    else
        println("GET errored")
    end
    return JSON.parse(String(res.body))
end

function realdb_putRealTime(baseUrl, url, body = Dict("name" => "real_db_test"), auth = "null")
    final_url = "$baseUrl$url.json?auth=$auth"
    #println("FINAL URL:", final_url)
    body = JSON.json(body)
    #println("Body:", body)
    res = HTTP.put(final_url, "", body)
    if res.status == 200
        #println("PUT successful")
    else
        println("PUT errored")
    end
    JSON.parse(String(res.body))
end

function realdb_deleteRealTime(baseUrl, url, auth = "null")
    final_url = "$baseUrl$url.json?auth=$auth"
    #println("FINAL URL:", final_url)
    res = HTTP.delete(final_url, "")
    if res.status == 200
        println("DELETE successful")
    else
        println("DELETE errored")
    end
    JSON.parse(String(res.body))
end