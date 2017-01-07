#! /bin/bash

assignProxy() {
  PROXY_ENV="http_proxy https_proxy ftp_proxy all_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY"

  for envar in $PROXY_ENV
  do
    export $envar=$1
  done
  for envar in "no_proxy NO_PROXY"
  do
    export $envar=$2
  done
}

clrProxy() {
  assignProxy "" # this is what unset does
}

# check the headers to see if http status is ok
# output the /dev/null to check exit code ($?)
# forbidden
# curl -s --head $proxy_value --connect-timeout 5 | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null

echo "looking for proxy $PROXY_WORK at port $PROXY_PORT_WORK"

ping -q -c 1 -W 4 $PROXY_WORK > /dev/null

# on success export variables
if [ "$?" = "0" ]; then
  echo "proxy found setting environment..."
  proxy_addr="http://$PROXY_WORK:$PROXY_PORT_WORK"
	no_proxy_value="localhost,127.0.0.1,localaddress,.localdomain.com"
  assignProxy $proxy_addr $no_proxy_value
  /usr/bin/git config --global http.proxy $proxy_addr
else
  echo "proxy not found unsetting environment"
  clrProxy
  /usr/bin/git config --global --unset http.proxy
fi

echo "done"
