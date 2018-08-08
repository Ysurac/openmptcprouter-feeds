-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Copyright 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.mptcp", package.seeall)

function index()
	entry({"admin", "network", "mptcp"}, alias("admin", "network", "mptcp", "settings"), _("MPTCP"))
	entry({"admin", "network", "mptcp", "settings"}, cbi("mptcp"), _("Settings"),2).leaf = true
	entry({"admin", "network", "mptcp", "bandwidth"}, template("mptcp/multipath"), _("Bandwidth"), 3).leaf = true
	entry({"admin", "network", "mptcp", "multipath_bandwidth"}, call("multipath_bandwidth")).leaf = true
	entry({"admin", "network", "mptcp", "interface_bandwidth"}, call("interface_bandwidth")).leaf = true
end

function interface_bandwidth(iface)
	luci.http.prepare_content("application/json")
	local bwc = io.popen("luci-bwc -i %q 2>/dev/null" % iface)
	if bwc then
		luci.http.write("[")
		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end
		luci.http.write("]")
		bwc:close()
	end
end

function string.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

function multipath_bandwidth()
	local result = { };
	local uci = luci.model.uci.cursor()
	local multipath="";
	local proto="";	
	local res={ };
	local str="";
    local tmpstr="";
	
	for _, dev in luci.util.vspairs(luci.sys.net.devices()) do
		if dev ~= "lo" then
		    if dev == "eth0.2"	then			
			     multipath = uci:get("network", "wan", "multipath")
			elseif dev == "4g-wwan0" then
			     multipath = uci:get("network", "wwan0", "multipath")
            else 			
			     multipath = uci:get("network", dev, "multipath")
			end
			if multipath == "on" or multipath == "master" or multipath == "backup" or multipath == "handover" then
				result[dev] = "[" .. string.gsub((luci.sys.exec("luci-bwc -i %q 2>/dev/null" % dev)), '[\r\n]', '') .. "]"			
			end
		end
	end)
	---先初始化求和数组	
	res["total"]={ };
	for i=1,60 do
		res["total"][i]={}
		for j=1,5 do
		 res["total"][i][j]=0
		end
	end	
	
	--遍历所有接口表求和
	for key,value in pairs(result) do
		  res[key]={}
		  value=(string.gsub(value, "^%[%[", ""))
		  value=(string.gsub(value, "%]%]", ""))
		  local temp1 = string.split(value, "],")
		  res[key][1]=temp1[1]
		  for i=2,60 do
			  res[key][i]={}
			  res[key][i]=(string.gsub(temp1[i], "%[", " "))			  
		  end
		  for i=1,60 do
			 res[key][i] = string.split(res[key][i], ",")
			 for j=1,5 do
			     if "string"== type(res[key][i][j]) then
				     res[key][i][j]= tonumber(res[key][i][j])
				 end
				 if "string"==type(res["total"][i][j]) then
				     res["total"][i][j]= tonumber(res["total"][i][j])
				 end	 
			     if j ==1 then
				      res["total"][i][j] = res[key][i][j]
				 else
			        res["total"][i][j] = res["total"][i][j] + res[key][i][j]
				 end				 
		     end    
		  end
	end
	---数值类型转成字符串  
	for i=1,60 do		
	   for j=1,5 do
		   if "number"== type(res["total"][i][j]) then
			   res["total"][i][j]= tostring(res["total"][i][j])
		   end
	   end    
	end
	---数组转成字符串
	for i=1,60 do
        if i == 60	then
		    tmpstr = "["..table.concat(res["total"][i], ",")
		else
            tmpstr = "["..table.concat(res["total"][i], ",").."],"
        end			
        str  = str..tmpstr
    end
	str  = "["..str.."]]"
	result["total"]=str
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(result)
end
