
a=Map("zerotier",translate("ZeroTier"),translate("Zerotier is an open source, cross-platform and easy to use virtual LAN"))
a:section(SimpleSection).template  = "zerotier/zerotier_status"

t=a:section(NamedSection,"sample_config","zerotier")
t.anonymous=true
t.addremove=false

e=t:option(Flag,"enabled",translate("Enable"))
e.default=0
e.rmempty=false

e=t:option(DynamicList,"join",translate('ZeroTier Network ID'))
e.password=true
e.rmempty=false

e=t:option(Flag,"nat",translate("Auto NAT Clients"))
e.default=0
e.rmempty=false

e = t:option(MultiValue, "access", translate("Zerotier access control"))
e.default="lanfwzt ztfwwan ztfwlan"
e.rmempty=false
e:value("lanfwzt",translate("lan access zerotier"))
e:value("wanfwzt",translate("wan access zerotier"))
e:value("ztfwwan",translate("remote access wan"))
e:value("ztfwlan",translate("remote access lan"))
e.widget = "checkbox"

e=t:option(DummyValue,"opennewwindow" , 
	translate("<input type=\"button\" class=\"cbi-button cbi-button-apply\" value=\"Zerotier.com\" onclick=\"window.open('https://my.zerotier.com/network')\" />"))
e.description = translate("Create or manage your zerotier network, and auth clients who could access")

return a
