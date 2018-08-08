-- Copyright 2018 Jo-Philipp Wich <jo@mein.io>
-- Licensed to the public under the Apache License 2.0.

local fs = require "nixio.fs"
local utl = require "luci.util"
local tpl = require "luci.template"
local ntm = require "luci.model.network"

local has_iwinfo = pcall(require, "iwinfo")

function guess_wifi_hw(dev)
	local bands = ""
	local ifname = dev:name()
	local name, idx = ifname:match("^([a-z]+)(%d+)")
	idx = tonumber(idx)

	if has_iwinfo then
		local bl = dev.iwinfo.hwmodelist
		if bl and next(bl) then
			if bl.a then bands = bands .. "a" end
			if bl.b then bands = bands .. "b" end
			if bl.g then bands = bands .. "g" end
			if bl.n then bands = bands .. "n" end
			if bl.ac then bands = bands .. "ac" end
		end

		local hw = dev.iwinfo.hardware_name
		if hw then
			return "%s 802.11%s" %{ hw, bands }
		end
	end

	-- wl.o
	if name == "wl" then
		local name = translatef("Broadcom 802.11%s Wireless Controller", bands)
		local nm   = 0

		local fd = nixio.open("/proc/bus/pci/devices", "r")
		if fd then
			local ln
			for ln in fd:linesource() do
				if ln:match("wl$") then
					if nm == idx then
						local version = ln:match("^%S+%s+%S%S%S%S([0-9a-f]+)")
						name = translatef(
							"Broadcom BCM%04x 802.11 Wireless Controller",
							tonumber(version, 16)
						)

						break
					else
						nm = nm + 1
					end
				end
			end
			fd:close()
		end

		return name

	-- dunno yet
	else
		return translatef("Generic 802.11%s Wireless Controller", bands)
	end
end

local tpl_radio = tpl.Template(nil, [[
	<div class="cbi-section-node">
		<div class="table">
			<!-- physical device -->
			<div class="tr cbi-rowstyle-2">
				<div class="td col-2 center middle">
					<span class="ifacebadge"><img src="<%=resource%>/icons/wifi_disabled.png" id="<%=dev:name()%>-iw-upstate" /> <%=dev:name()%></span>
				</div>
				<div class="td col-7 left middle">
					<big><strong><%=hw%></strong></big><br />
					<span id="<%=dev:name()%>-iw-devinfo"></span>
				</div>
				<div class="td middle cbi-section-actions">
					<div>
						<input type="button" class="cbi-button cbi-button-neutral" title="<%:Restart radio interface%>" value="<%:Restart%>" data-radio="<%=dev:name()%>" onclick="wifi_restart(event)" />
						<input type="button" class="cbi-button cbi-button-action important" title="<%:Find and join network%>" value="<%:Scan%>" onclick="cbi_submit(this, 'device', '<%=dev:name()%>', '<%=url('admin/network/wireless_join')%>')" />
						<input type="button" class="cbi-button cbi-button-add" title="<%:Provide new network%>" value="<%:Add%>" onclick="cbi_submit(this, 'device', '<%=dev:name()%>', '<%=url('admin/network/wireless_add')%>')" />
					</div>
				</div>
			</div>
			<!-- /physical device -->

			<!-- network list -->
			<% if #wnets > 0 then %>
				<% for i, net in ipairs(wnets) do local disabled = (dev:get("disabled") == "1" or net:get("disabled") == "1") %>
				<div class="tr cbi-rowstyle-<%=1 + ((i-1) % 2)%>">
					<div class="td col-2 center middle" id="<%=net:id()%>-iw-signal">
						<span class="ifacebadge" title="<%:Not associated%>"><img src="<%=resource%>/icons/signal-<%= disabled and "none" or "0" %>.png" /> 0%</span>
					</div>
					<div class="td col-7 left middle" id="<%=net:id()%>-iw-status" data-network="<%=net:id()%>" data-disabled="<%= disabled and "true" or "false" %>">
						<em><%= disabled and translate("Wireless is disabled") or translate("Collecting data...") %></em>
					</div>
					<div class="td middle cbi-section-actions">
						<div>
							<% if disabled then %>
								<input name="cbid.wireless.<%=net:name()%>.__disable__" type="hidden" value="1" />
								<input name="cbi.apply" type="submit" class="cbi-button cbi-button-neutral" title="<%:Enable this network%>" value="<%:Enable%>" onclick="this.previousElementSibling.value='0'" />
							<% else %>
								<input name="cbid.wireless.<%=net:name()%>.__disable__" type="hidden" value="0" />
								<input name="cbi.apply" type="submit" class="cbi-button cbi-button-neutral" title="<%:Disable this network%>" value="<%:Disable%>" onclick="this.previousElementSibling.value='1'" />
							<% end %>

							<input type="button" class="cbi-button cbi-button-action important" onclick="location.href='<%=net:adminlink()%>'" title="<%:Edit this network%>" value="<%:Edit%>" />

							<input name="cbid.wireless.<%=net:name()%>.__delete__" type="hidden" value="" />
							<input name="cbi.apply" type="submit" class="cbi-button cbi-button-negative" title="<%:Delete this network%>" value="<%:Remove%>" onclick="wifi_delete(event)" />
						</div>
					</div>
				</div>
				<% end %>
			<% else %>
				<div class="tr placeholder">
					<div class="td">
						<em><%:No network configured on this device%></em>
					</div>
				</div>
			<% end %>
			<!-- /network list -->
		</div>
	</div>
]])


m = Map("wireless", translate("Wireless Overview"))
m:chain("network")
m.pageaction = false

if not has_iwinfo then
	s = m:section(NamedSection, "__warning__")

	function s.render(self)
		tpl.render_string([[
			<div class="alert-message warning">
				<h4><%:Package libiwinfo required!%></h4>
				<p><%_The <em>libiwinfo-lua</em> package is not installed. You must install this component for working wireless configuration!%></p>
			</div>
		]])
	end
end

local _, dev, net
for _, dev in ipairs(ntm:get_wifidevs()) do
	s = m:section(TypedSection)
	s.wnets = dev:get_wifinets()

	function s.render(self, sid)
		tpl_radio:render({
			hw = guess_wifi_hw(dev),
			dev = dev,
			wnets = self.wnets
		})
	end

	function s.cfgsections(self)
		local _, net, sl = nil, nil, { }
		for _, net in ipairs(self.wnets) do
			sl[#sl+1] = net:name()
			self.wnets[net:name()] = net
		end
		return sl
	end

	o = s:option(Value, "__disable__")

	function o.cfgvalue(self, sid)
		local wnet = self.section.wnets[sid]
		local wdev = wnet:get_device()

		return ((wnet and wnet:get("disabled") == "1") or
			    (wdev and wdev:get("disabled") == "1")) and "1" or "0"
	end

	function o.write(self, sid, value)
		local wnet = self.section.wnets[sid]
		local wdev = wnet:get_device()

		if value ~= "1" then
			wnet:set("disabled", nil)
			wdev:set("disabled", nil)
		else
			wnet:set("disabled", "1")
		end
	end

	o.remove = o.write


	o = s:option(Value, "__delete__")

	function o.write(self, sid, value)
		local wnet = self.section.wnets[sid]
		local nets = wnet:get_networks()

		ntm:del_wifinet(wnet:id())

		local _, net
		for _, net in ipairs(nets) do
			if net:is_empty() then
				ntm:del_network(net:name())
			end
		end
	end
end

s = m:section(NamedSection, "__script__")
s.template = "admin_network/wifi_overview_status"

s = m:section(NamedSection, "__assoclist__")

function s.render(self, sid)
	tpl.render_string([[
		<h2><%:Associated Stations%></h2>
		<%+admin_network/wifi_assoclist%>
	]])
end

return m
