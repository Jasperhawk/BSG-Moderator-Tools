# /usr/bin/env python
# -*- coding: utf-8 -*-

# BSG Moderator Tools (JasperHawk) Dispatcher

#from __future__ import unicode_literals

import os
import sys
import threading
if sys.version_info.major >= 3:
    import urllib.request as urllib2
    from urllib.parse import urlencode
    import hashlib as md5  # may be just define md5 function here?
    from http.cookiejar import CookieJar
else:  # python2
    import urllib2
    import md5
    from cookielib import CookieJar
    from urllib import urlencode
    reload(sys)
    sys.setdefaultencoding("UTF-8")

from pprint import pprint as pp

from com.sun.star.awt import Rectangle
from com.sun.star.awt import WindowDescriptor
from com.sun.star.awt.WindowClass import MODALTOP
from com.sun.star.awt.VclWindowPeerAttribute import OK, OK_CANCEL, YES_NO, YES_NO_CANCEL, RETRY_CANCEL, DEF_OK, DEF_CANCEL, DEF_RETRY, DEF_YES, DEF_NO

if sys.version_info < (2, 7):
    raise Exception('We need python 2.7, sorry')

def MessageBox(Document, MsgText, MsgTitle, MsgType="messbox", MsgButtons=OK):
    ParentWin = Document.CurrentController.Frame.ContainerWindow

    MsgType = MsgType.lower()

    # available msg types
    MsgTypes = ("messbox", "infobox", "errorbox", "warningbox", "querybox")

    if not (MsgType in MsgTypes):
        MsgType = "messbox"

    # describe window properties.
    aDescriptor = WindowDescriptor()
    aDescriptor.Type = MODALTOP
    aDescriptor.WindowServiceName = MsgType
    aDescriptor.ParentIndex = -1
    aDescriptor.Parent = ParentWin
    # aDescriptor.Bounds = Rectangle()
    aDescriptor.WindowAttributes = MsgButtons

    tk = ParentWin.getToolkit()
    msgbox = tk.createWindow(aDescriptor)

    msgbox.MessageText = MsgText
    if MsgTitle:
        msgbox.CaptionText = MsgTitle

    return msgbox.execute()

class GeekMail(object):
    def __init__(self, username=None, password=None, workdir=None):

        if username and password:  # We can work with that...
            self.username = username
            self.password = password
        elif not workdir:  # We can't work with that
            raise Exception('We need credentials to work with!')
        else:
            try:
                self.username, self.password = open(os.path.join(workdir, 'bgguser.txt')).read().strip().split(':', 1)
            except:
                raise Exception('Invalid credential file - check bgguser.txt')

        self.loginurl = "https://www.boardgamegeek.com/login"
        self.msgurl = "https://boardgamegeek.com/geekmail_controller.php"
        self.cj = CookieJar()
        self.opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(self.cj))
        self.opener.addheaders = [('User-agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/602.4.2 (KHTML, like Gecko) Version/10.0.3 Safari/602.4.2')]
        urllib2.install_opener(self.opener)

        self.authenticate()

    def authenticate(self):
        data = urlencode({'lasturl': '/', 'username': self.username, 'password': self.password, 'B1': 'Submit'})
        response = self.opener.open(self.loginurl, data.encode())
        content = response.read()
        if "Invalid Username" in content:
            raise Exception('Invalid user or password! Please check')
        # if 'bggusername' not in response.headers['set-cookie']:  # invalid user
        #     raise Exception('Invalid user or password! Please check')

    def dispatch_text(self, bgguser, subject, body):
        subject = clean_str(subject)
        body = clean_str(body)
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
            'body': body })

        response = self.opener.open(self.msgurl, data.encode())
        content = response.read()

    def dispatch_file(self, bgguser, filename):
        f = clean_str(open(filename, 'r').read())
        subject, body = f.split('\n', 1)

        self.dispatch_text(bgguser, subject, body)

def clean_str(fs):
    # fs = fs.replace('→', '->')
    fs = fs.replace('\r\n', '\n').strip()
    # fs = fs.decode('utf-8').encode('ascii', 'ignore')
    return fs

def calculate_md5(contents):
    pmd5 = md5.md5()
    pmd5.update(contents.encode('utf-8'))
    return pmd5.hexdigest()

def get_md5(playerfile):
    # Calculate the MD5 so we don't re-send a file if nothing has changed
    subject, body = clean_str(open(playerfile, 'r').read()).split('\n', 1)
    return calculate_md5(body)

def dispatch_selected(*args):
    """BGG BSG Function to dispatch a single user hand"""

    document = XSCRIPTCONTEXT.getDocument()
    maindir = urllib2.url2pathname(os.path.dirname(document.Location.replace("file://", "")))
    logfile = os.path.join(maindir, 'bsg-dispatcher-debug.log')
    sys.stdout = open(logfile, "ab", 0)  # unbuffered

    # Useful variables so we don't need to do a lot of typing
    worksheet = document.getSheets().getByName('Game State')
    dispatcherinfo = document.getSheets().getByName('Posting Templates')

    # Find the selected char
    selected_char = worksheet.DrawPage.Forms.getByName('formGameState').getByName('lstPlayers').CurrentValue
    selected_player = ''
    if not selected_char:
        MessageBox(document, "Error: no player selected", "Invalid player", "warningbox")
        return False

    # Find out which player we're looking at
    for i in range(7):
        charname = worksheet.getCellByPosition(4, 2+i).getString()    # Character name on Game State
        if charname == selected_char:
            selected_player = worksheet.getCellByPosition(1, 2+i).getString()  # Player name on Game State
            player_id = i
            break
    else:
        MessageBox(document, "Error: player not found, maybe a bug?", "Invalid player", "warningbox")
        return False

    # Verify if file exists
    playerfile = os.path.join(maindir, selected_char + '.txt')
    if not os.path.exists(playerfile):
        MessageBox(document, "Error: file '%s' not found (use the 'Create Hand Lists' first)" % (selected_char + '.txt'), "File not found", "warningbox")
        return False

    # Verify if we already sent this file
    old_md5 = dispatcherinfo.getCellByPosition(player_id+4, 31).getString()
    current_md5 = get_md5(playerfile)
    if old_md5 == current_md5:  # We DID send this already!!!
        confirm = MessageBox(document, "It seems we've already sent this file. Send again?", "File already sent", "querybox", YES_NO)
        if confirm == 3:  # Pressed "No"
            return False

    # Now we finally try to send our files
    try:
        gm = GeekMail(workdir=maindir)
        gm.dispatch_file(selected_player, playerfile)
        # Set the current MD5 on the spreadsheet (so that we only send it again after something is changed)
        dispatcherinfo.getCellByPosition(player_id+4, 31).setString(current_md5)
    except Exception as e:
        MessageBox(document, str(e), "Alert!", "warningbox")
        return False

    MessageBox(document, "Successfully sent file to %s" % selected_player, "Success!", "infobox")


def dispatch_all(*args):
    """BGG BSG Function to dispatch all player hands"""

    document = XSCRIPTCONTEXT.getDocument()
    maindir = urllib2.url2pathname(os.path.dirname(document.Location.replace("file://", "")))
    logfile = os.path.join(maindir, 'bsg-dispatcher-debug.log')
    sys.stdout = open(logfile, "ab", 0)  # unbuffered

    # Useful variables so we don't need to do a lot of typing
    worksheet = document.getSheets().getByName('Game State')
    dispatcherinfo = document.getSheets().getByName('Posting Templates')

    to_send = []
    # Maximum of 7 players
    for i in range(7):
        playername = worksheet.getCellByPosition(1, 2+i).getString()  # Player name on Game State
        charname = worksheet.getCellByPosition(4, 2+i).getString()    # Character name on Game State
        if not playername:         # If there isn't a player for this number, skip it
            continue

        # Verify if file exists
        playerfile = os.path.join(maindir, charname + '.txt')
        if not os.path.exists(playerfile):
            MessageBox(document, "Error: file '%s' not found (use the 'Create Hand Lists' first)" % (charname + '.txt'), "File not found", "warningbox")
            return False

        # Let's see if this file was modified
        old_md5 = dispatcherinfo.getCellByPosition(i+4, 31).getString()
        current_md5 = get_md5(playerfile)
        if old_md5 != current_md5:  # File was modified. Set up to send it
            to_send.append({'player': playername, 'character': charname, 'playerfile': playerfile, 'md5': current_md5, 'player_id': i})

    if not to_send:
        MessageBox(document, "Nothing new to send. Maybe you forgot to use Create Hand Lists?", "No files modified!", "infobox")
    else:
        def send(p):
            # Now we finally try to send our files
            try:
                gm = GeekMail(workdir=maindir)
                gm.dispatch_file(p['player'], p['playerfile'])
                # Set the current MD5 on the spreadsheet (so that we only send it again after something is changed)
                dispatcherinfo.getCellByPosition(p['player_id']+4, 31).setString(p['md5'])
            except Exception as e:
                MessageBox(document, e.message, "Alert!", "warningbox")
        processes = []
        n = 0
        for player in to_send:
            n += 1
            processes.append(threading.Thread(target=send, args=(player, )))
            processes[-1].start()

        for process in processes:
            # They all run in parallel (ok, GIL-parallel, but since we're waiting on I/O...)
            # So we need to check if each of them has ended
            process.join()

        MessageBox(document, "Successfully sent the updated hands to: %s" % (", ".join([e['player'] for e in to_send])), "Success!", "infobox")

def dispatcher_call(*args):
    """BGG BSG Function to dispatch a generic message via GeekMail"""
    document = XSCRIPTCONTEXT.getDocument()
    maindir = urllib2.url2pathname(os.path.dirname(document.Location.replace("file://","")))
    logfile = os.path.join(maindir, 'bsg-dispatcher-debug.log')
    sys.stdout = open(logfile, "a", 0)  # unbuffered

    # Useful variables so we don't need to do a lot of typing
    worksheet = document.getSheets().getByName('Game State')
    dispatcherinfo = document.getSheets().getByName('Posting Templates')
    dispatchersheet = document.getSheets().getByName('Dispatcher')

    playername = dispatchersheet.getCellByPosition(2, 1).getString()
    subject = dispatchersheet.getCellByPosition(2, 3).getString()
    body = dispatchersheet.getCellByPosition(2, 4).getString()
    oldhash = dispatchersheet.getCellByPosition(2, 5).getString()

    if not playername:
        MessageBox(document, "Error: Username can't be empty", "No username!", 'warningbox')
        return False
    if not subject:
        MessageBox(document, "Error: Subject not defined", "Subject not defined!", 'warningbox')
        return False
    if not body:
        MessageBox(document, "Error: Body is empty", "Empty body!", 'warningbox')
        return False

    hashish = calculate_md5("%s%s%s" % (playername, subject, body))
    if oldhash == hashish:
        confirm = MessageBox(document, "It seems we've already sent this data. Send again?", "Data already sent", "querybox", YES_NO)
        if confirm == 3:  # Pressed "No"
            return False

    try:
        gm = GeekMail(workdir=maindir)
        gm.dispatch_text(playername, subject, body)
        # Set the current MD5 on the spreadsheet (so that we only send it again after something is changed)
        dispatchersheet.getCellByPosition(2, 5).setString(hashish)
    except Exception as e:
        MessageBox(document, str(e), "Alert!", "warningbox")
        return False

    MessageBox(document, "Successfully sent the following message:\n\n%s" % (subject), "Success!", "infobox")


g_exportedScripts = dispatch_all, dispatch_selected, dispatcher_call
