#!/bin/sh

apt install sqlite3

printf "Adding hosts file to /etc/pihole/gravity.db:\n"
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/tsukudani0412/block-nintendo-for-pihole/main/nintendo-hosts.txt', 1, 'block nintendo servers');"
printf "https://raw.githubusercontent.com/tsukudani0412/block-nintendo-for-pihole/main/nintendo-hosts.txt\n"

printf "\nAdding regEx black list to *.nintendo.net\n"
pihole --regex '(\.|^)nintendo\.net$'

printf "\nAdding exact white list to ctest.cdn.nintendo.net\n"
pihole -w 'ctest.cdn.nintendo.net'

printf "\nAdding adlist to /etc/pihole/custom.list:\n"
LOCALIP=`ip route get 8.8.8.8 | head -1 | awk '{print $7}'`
printf "${LOCALIP} conntest.nintendowifi.net\n" | tee -a /etc/pihole/custom.list
printf "${LOCALIP} ctest.cdn.nintendo.net\n" | tee -a /etc/pihole/custom.list

printf "\nUpdating gravity..."
systemctl restart pihole-FTL.service > /dev/null
pihole -g > /dev/null
printf "done\n"


printf "\nSetting up lighttpd server\n"
mkdir /var/www/html/90dns/ && cd /var/www/html/90dns/
printf '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><html><head><title>HTML Page</title></head><body bgcolor="#FFFFFF">This is test.html page</body></html>' | tee conntest.nintendowifi.net.html
printf 'ok' | tee ctest.cdn.nintendo.net.txt

# modify lighttpd configuration, Pihole recommands to modify settings through external.conf
cat <<-'EOF' | tee /etc/lighttpd/conf-available/90dns.conf 
server.modules += (
        "mod_rewrite"
        )

# https://redmine.lighttpd.net/boards/2/topics/6541
var.90dns-response-headers = (
    "X-Organization" => "Nintendo"
)

# https://stackoverflow.com/a/32128324/1043209
$HTTP["host"] == "conntest.nintendowifi.net" {
    url.rewrite-once = ( ".*" => "/90dns/conntest.nintendowifi.net.html" )
    setenv.add-response-header = var.90dns-response-headers
}

$HTTP["host"] == "ctest.cdn.nintendo.net" {
    url.rewrite-once = ( ".*" => "/90dns/ctest.cdn.nintendo.net.txt" )
    setenv.add-response-header = var.90dns-response-headers
    setenv.add-response-header += ( "Content-Type" => "text/plain" )
}
EOF
ln -s /etc/lighttpd/conf-available/90dns.conf /etc/lighttpd/conf-enabled/90dns.conf
systemctl restart lighttpd.service
  
