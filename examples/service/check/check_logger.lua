local log = require "bw.log"
return function()
    log.error("test error.log")
    return true
end
