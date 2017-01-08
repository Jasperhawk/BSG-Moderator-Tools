#!python

import sys
if sys.version_info.major >= 3:
    import urllib.request as urllib2
    from urllib.parse import urlencode
    from http.cookiejar import CookieJar
else:  # python2
    import urllib2
    from cookielib import CookieJar
    from urllib import urlencode

dispatch_data_file = sys.argv[1]

with open(dispatch_data_file, 'rb') as dispatch_data:
    encdata = dispatch_data.read().decode()
    bgguser, bggpass, target, subject, body = encdata.split('\n', 4)
    loginurl = "https://www.boardgamegeek.com/login"
    msgurl = "https://boardgamegeek.com/geekmail_controller.php"
    cj = CookieJar()
    opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cj))
    opener.addheaders = [('User-agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/602.4.2 (KHTML, like Gecko) Version/10.0.3 Safari/602.4.2')]
    urllib2.install_opener(opener)
    data = urlencode({'location': '/', 'username': bgguser, 'password': bggpass})
    response = opener.open(loginurl, data.encode())
    content = response.read()
    if b"Invalid Username" in content:
        sys.exit(10)  # Invalid user or password
    data = urlencode({
        'action': 'save',
        'B1': "Send",
        'savecopy': '1',
        'sizesel': '10',
        'folder': 'inbox',
        'ajax': '1',
        'searchid': '0',
        'pageID': '0',
        'messageid': '',
        'touser': bgguser,
        'subject': subject,
        'body': body})

    response = opener.open(msgurl, data.encode())
    content = response.read()
