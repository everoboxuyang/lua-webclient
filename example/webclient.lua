local Skynet = require "skynet";
local Lib = {};
local WebClientLib = require("luna.webclient");
local Requests = {};
local WebClient = WebClientLib.Create(function (index, data)
    local reqest = Requests[index];
    reqest.data = reqest.data .. data;
end);

function Lib.Request(session, source, url, get, post)
    if get then
        local i = 0;
        for k, v in pairs(get) do
            k = WebClient:UrlEncoding(k);
            v = WebClient:UrlEncoding(v);

            url = string.format("%s%s%s=%s", url, i == 0 and "?" or "&", k, v);
            i = i + 1;
        end        
    end

    if post and type(post) == "table" then
        local data = {}
        for k,v in pairs(post) do
            k = WebClient:UrlEncoding(k);
            v = WebClient:UrlEncoding(v);

            table.insert(data, string.format("%s=%s", k, v));
        end   
        post = table.concat(data , "&");
    end

    local index = WebClient:Request(url, post);
    if not index then
        return Skynet.ret();
    end

    Requests[index] = {
        url = url, 
        data = "",
        session = session,
        address = source,
    };
end

function Lib.Query()
    for i = 1, 10000 do
        local index, errmsg = WebClient:Query();
        if not index then
            break;
        end


        local reqest = Requests[index];
        if reqest then
            local param, size;
            if errmsg == nil or errmsg == "" then
                param, size = Skynet.pack(true, reqest.data);
            else
                param, size = Skynet.pack(false, errmsg);
            end 

            Skynet.redirect(reqest.address, 0, Skynet.PTYPE_RESPONSE, reqest.session, param, size);
            Requests[index] = nil;
        end    
        WebClient:RemoveRequest(index);
    end
end

local function Query()
    while true do
        Lib.Query();
        Skynet.sleep(1);
    end
end

Skynet.start(function()
    Skynet.dispatch("lua", function(session, source, command, ...)
        local f = Lib[command];
        if f then
            f(session, source, ...);
        else
            print("webclient unknown cmd ", command);
        end
    end)

    Skynet.fork(Query);
    Skynet.fork(function ()
        while true do
            local a = require("lib").CountTB(Requests);
            print("Requests Count:" .. a)
            Skynet.sleep(1000);
        end        
    end);
end)