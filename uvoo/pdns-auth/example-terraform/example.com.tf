resource "powerdns_zone" "example_com" {
  name        = "example.com."
  kind        = "Native"
  nameservers = ["ns1.example.com.", "ns2.example.com."]
}

resource "powerdns_record" "www_example_com" {
  zone    = "example.com."
  name    = "www.example.com."
  type    = "A"
  ttl     = 300
  records = ["192.168.0.11"]
}

resource "powerdns_record" "test_example_com" {
  zone    = "example.com."
  name    = "test.example.com."
  type    = "A"
  ttl     = 300
  records = ["192.168.0.11"]
}

resource "powerdns_record" "foobar_txt_spf_and_dkim" {
  zone    = "example.com."
  name    = "example.com."
  type    = "TXT"
  ttl     = 60
  records = ["\"v=spf1 mx -all\"", "\"v=DKIM1 ;k=rsa; s=email; p=Msdsdfsdfsdfsdfsdfsdfsdfsdfsdfsfdfsdfsdfsdfds\""]
}

resource "powerdns_record" "mx_example_com" {
  zone    = "example.com."
  name    = "example.com."
  type    = "MX"
  ttl     = 300
  records = ["10 mail1.example.com.", "20 mail2.example.com."]
}

resource "powerdns_record" "random_example_com" {
  zone = "example.com."
  name = "random.example.com."
  type = "LUA"
  ttl = 60
  records = [ "A \"pickrandom({'192.168.0.111','192.168.0.222'})\"" ]
}

resource "powerdns_record" "luaurl_example_com" {
  zone = "example.com."
  name = "luaurl.example.com."
  type = "LUA"
  ttl = 60
  records = [ "A \"ifurlup('https://www.uvoo.io/', {'192.168.1.1', '192.168.1.2'})\"" ]
}

resource "powerdns_record" "luaport_example_com" {
  zone = "example.com."
  name = "luaport.example.com."
  type = "LUA"
  ttl = 60
  records = [ "A \"ifportup(443, {'10.64.10.111', '10.64.7.62'})\"" ]
  # records = [ "A \"ifportup(443, {'10.64.10.111', '10.64.7.62'})\"" ]
  # records = [ "A \"ifportup(443, {'204.15.86.209', '204.15.86.210'})\"" ]
}

resource "powerdns_record" "luaurl2_example_com" {
  zone = "example.com."
  name = "luaurl2.example.com."
  type = "LUA"
  ttl = 60
  records = [ "A \"ifurlup('https://www.example.com/', {{'10.64.7.62', '10.64.227.227'}, {'93.184.216.34'}}, {stringmatch='for use'})\"" ]
  # records = [ "A \"ifurlup('https://www.example.com/', {{'10.64.7.62', '10.64.227.227'}, {'93.184.216.34'}}, {stringmatch='for u'})\"" ]
# for using or for use
}

resource "powerdns_record" "luaurl1_example_com" {
  zone = "example.com."
  name = "luaurl1.example.com."
  type = "LUA"
  ttl = 60
  records = [ "A \"ifurlup('https://www.uvoo.io/', {{'192.168.2.1', '192.168.2.2'}, {'10.100.1.1'}}, {stringmatch='xPoop'})\"" ]
  # records = [ "A \"ifurlup('https://www.uvoo.io/', {{'192.0.2.1', '192.0.2.2'}, {'10.100.1.1'}}, {stringmatch='Security Audit and Consultation'})\"" ]
  # records = [ "A \"ifurlup('https://www.lua.go/', {{'192.0.2.1', '192.0.2.2'}, {'10.100.1.1'}}, {stringmatch='Programming in Lua'})\"" ]
}

# west    IN    LUA    A    ( "ifurlup('https://www.lua.org/',                  "
#                             "{{'192.0.2.1', '192.0.2.2'}, {'198.51.100.1'}},  "
#                             "{stringmatch='Programming in Lua'})              
