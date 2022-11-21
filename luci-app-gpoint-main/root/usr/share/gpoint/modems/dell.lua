common_path = '/usr/share/gpoint/lib/?.lua;'
package.path = common_path .. package.path


local nmea = require("nmea")
local serial = require("serial")
local nixio   = require("nixio.fs")

local dell = {}

local DELL_BEGIN_GPS  = "AT+GPS=1"
local DELL_END_GPS    = "AT+GPS=0"

-- automatic activation of the NMEA port for data transmission
function dell.start(port)
	local p = tonumber(string.sub(port, #port)) + 1
	p = string.gsub(port, '%d', tostring(p))
	local error, resp = true, {
		warning = {
			app = {true, "Port is unavailable. Check the modem connections!"},
			locator = {}, 
			server = {}
		}
	}
	-- DELL DW5821 series default NMEA /dev/ttyUSB2
	local fport = nixio.glob("/dev/tty[A-Z][A-Z]*")
	for name in fport do
		if string.find(name, p) then
			error, resp = serial.write(p, DELL_BEGIN_GPS)
		end
	end
	return error, resp
end
-- stop send data to NMEA port
function dell.stop(port)
	error, resp = serial.write(port, DELL_END_GPS)
	return error, resp
end
-- get GNSS data for application
function dell.getGNSSdata(port)
	return nmea.getAllData(port)
end

return dell
