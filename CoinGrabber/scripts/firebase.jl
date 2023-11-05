function firebase_signinanon(HTTP, JSON, WEB_API_KEY, returnSecureToken::Bool=true)
    http_response = HTTP.post("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$WEB_API_KEY",
    header="""{Content-Type: application/json}""",
    body="""{"returnSecureToken":"$returnSecureToken"}""")
    response_string = String(http_response.body)
    return JSON.parse(response_string)
  end

function realdb_postRealTime(HTTP, JSON, baseUrl, url, body = Dict("name" => "real_db_test"), auth = "null")
    final_url = "$baseUrl$url.json?auth=$auth"
    body = JSON.json(body)
    res = HTTP.post(final_url, "", body)
    if res.status != 200
        println("POST errored")
    end
    return JSON.parse(String(res.body))
end

function realdb_getRealTime(HTTP, JSON, baseUrl, url, auth = "null")
    final_url = "$baseUrl$url.json?auth=$auth"
    res = HTTP.get(final_url)
    if res.status != 200
        println("POST errored")
    end
    return JSON.parse(String(res.body))
end

function realdb_putRealTime(HTTP, JSON, baseUrl, url, body = Dict("name" => "real_db_test"), auth = "null")
    final_url = "$baseUrl$url.json?auth=$auth"
    body = JSON.json(body)
    res = HTTP.put(final_url, "", body)
    if res.status != 200
        println("POST errored")
    end
    JSON.parse(String(res.body))
end

function realdb_deleteRealTime(HTTP, JSON, baseUrl, url, auth = "null")
    final_url = "$baseUrl$url.json?auth=$auth"
    res = HTTP.delete(final_url, "")
    if res.status != 200
        println("POST errored")
    end
    JSON.parse(String(res.body))
end