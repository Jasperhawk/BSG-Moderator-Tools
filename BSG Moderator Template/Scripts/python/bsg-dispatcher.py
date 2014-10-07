# /usr/bin/env python2.7
# -*- coding: utf-8 -*-

# BSG Moderator Tools (JasperHawk) Dispatcher

#from __future__ import unicode_literals

import os
import sys
import urllib
import urllib2
import md5
from cookielib import CookieJar
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

    #available msg types
    MsgTypes = ("messbox", "infobox", "errorbox", "warningbox", "querybox")

    if not ( MsgType in MsgTypes ):
    	MsgType = "messbox"

    #describe window properties.
    aDescriptor = WindowDescriptor()
    aDescriptor.Type = MODALTOP
    aDescriptor.WindowServiceName = MsgType
    aDescriptor.ParentIndex = -1
    aDescriptor.Parent = ParentWin
    #aDescriptor.Bounds = Rectangle()
    aDescriptor.WindowAttributes = MsgButtons

    tk = ParentWin.getToolkit()
    msgbox = tk.createWindow(aDescriptor)

    msgbox.MessageText = MsgText
    if MsgTitle:
        msgbox.CaptionText = MsgTitle

    return msgbox.execute()

class GeekMail(object):
    def __init__(self, username=None, password=None, workdir=None):
        
        if username and password: # We can work with that...
            self.username = username
            self.password = password
        elif not workdir: # We can't work with that
            raise Exception('We need credentials to work with!')
        else:
            try:
                self.username, self.password = open(os.path.join(workdir, 'bgguser.txt')).read().strip().split(':', 1)
            except:
                raise Exception('Invalid credential file - check bgguser.txt')
        
        self.loginurl = "http://www.boardgamegeek.com/login"
        self.msgurl = "http://boardgamegeek.com/geekmail_controller.php"
        self.cj = CookieJar()
        self.opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(self.cj))
        
        self.authenticate()
    
    def authenticate(self):
        data = urllib.urlencode({'username': self.username, 'password': self.password})
        response = self.opener.open(self.loginurl, data)
        # We don't actually need to get te response... But meh
        content = response.read()
        if 'bggusername' not in response.headers['set-cookie']: # invalid user
            raise Exception('Invalid user or password! Please check')
    
    def dispatch(self, bgguser, filename):
        with open(filename, 'r') as f:
            # first line is our subject
            subject = f.readline().strip()
            # the rest is the body
            body = f.read().strip()
        # For now, I'll use my bgguser and append the correct one to the subject. Just remove the lines below for "production"
        #subject = bgguser + ' ' + subject
        #bgguser = 'mawkee'
        
        data = urllib.urlencode({
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

        response = self.opener.open(self.msgurl, data)
        content = response.read()
        

def get_md5(playerfile):
    # Calculate the MD5 so we don't re-send a file if nothing has changed
    pmd5 = md5.md5()
    with open(playerfile, 'r') as fsock:
        subject, body = fsock.read().split('\n', 1)
        pmd5.update(body)
    return pmd5.hexdigest()

def dispatch_selected(*args):
    """BGG BSG Function to dispatch a single user hand"""
    
    document = XSCRIPTCONTEXT.getDocument()
    maindir = urllib2.url2pathname(os.path.dirname(document.Location.replace("file://","")))
    logfile = os.path.join(maindir, 'bsg-dispatcher-debug.log')
    sys.stdout = open(logfile, "w", 0) # unbuffered

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
    if old_md5 == current_md5: # We DID send this already!!!
        confirm = MessageBox(document, "It seems we've already sent this file. Send again?", "File already sent", "querybox", YES_NO)
        if confirm == 3:  # Pressed "No"
            return False
    
    # Now we finally try to send our files
    try:
        gm = GeekMail(workdir=maindir)
        gm.dispatch(selected_player, playerfile)
        # Set the current MD5 on the spreadsheet (so that we only send it again after something is changed)
        dispatcherinfo.getCellByPosition(player_id+4, 31).setString(current_md5)
    except Exception as e:
        MessageBox(document, e.message, "Alert!", "warningbox")
        return False
    
    MessageBox(document, "Successfully sent file to %s" % selected_player, "Success!", "infobox")
    

def dispatch_all(*args):
    """BGG BSG Function to dispatch all player hands"""
    
    document = XSCRIPTCONTEXT.getDocument()
    maindir = urllib2.url2pathname(os.path.dirname(document.Location.replace("file://","")))
    logfile = os.path.join(maindir, 'bsg-dispatcher-debug.log')
    sys.stdout = open(logfile, "w", 0) # unbuffered

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
        if old_md5 != current_md5: # File was modified. Set up to send it
            to_send.append({'player': playername, 'character': charname, 'playerfile': playerfile, 'md5': current_md5, 'player_id': i})
    
    if not to_send:
        MessageBox(document, "Nothing new to send. Maybe you forgot to use Create Hand Lists?", "No files modified!", "infobox")
    else:
        for p in to_send:
            # Now we finally try to send our files
            try:
                gm = GeekMail(workdir=maindir)
                gm.dispatch(p['player'], p['playerfile'])
                # Set the current MD5 on the spreadsheet (so that we only send it again after something is changed)
                dispatcherinfo.getCellByPosition(p['player_id']+4, 31).setString(p['md5'])
            except Exception as e:
                MessageBox(document, e.message, "Alert!", "warningbox")
            
        MessageBox(document, "Successfully sent the updated hands to: %s" % (", ".join([e['player'] for e in to_send])), "Success!", "infobox")

g_exportedScripts = dispatch_all, dispatch_selected
