;/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\
; Description
;\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/
; A simple IRC client written in AutoHotkey focused on connecting to a single channel.
;
The_ProjectName = LoneIRC
The_VersionName = v1.10.0

;~~~~~~~~~~~~~~~~~~~~~
;Compile Options
;~~~~~~~~~~~~~~~~~~~~~
SetBatchLines -1 ;Go as fast as CPU will allow
Startup()

#Include %A_LineFile%\..\lib
#Include Socket.ahk
#Include IRCClass.ahk
#Include Class_RichEdit.ahk
#Include Json.ahk
#Include Utils.ahk
#Include TTS.ahk
#Include util_misc.ahk
#Include Chatlogs.ahk


;#Include %A_ScriptDir%

;/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\
;Prep and StartUp
;\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/--\--/
ComObjError(False) ; Ignore http timeouts
Sb_InstallFiles()
Fn_EnableMultiVoice(True)
StaticOption_Voices = 12
StaticOption_MultiLHCP = 3

LastScrollPos = 0
LastScrollMax = 0
LastScrollPage = 0

FileCreateDir, %A_ScriptDir%\Data
SettingsFile = %A_ScriptDir%\Data\Settings.ini
If !(Settings := Ini_Read(SettingsFile))
{
	
	Settings =
	( LTrim
	ShowHex = 0`n`r

	[Server]`n`r
	Addr = irc.synirc.net`n`r
	Port = 6660`n`r
	Nicks =`n`r
	User =`n`r
	Pass =`n`r
	Channels = #%The_ProjectName%`n`r

	[Settings]`n`r
	TTSVoice =`n`r
	TTSFlag = 1`n`r
	Volume = 50`n`r
	TimeStampsFlag = 0`n`r
	CheckforUpdates = 1`n`r
	)
	
	File := FileOpen(SettingsFile, "w")
	File.Write(Settings), File.Close()
	
	Msgbox, There was a problem reading your Settings.ini file.`n`nA new one has been generated. It can be found at ...\Data\Settings.ini`nPlease review it and confirm that your server and channel are correct before pressing "OK"`n`n`n%The_ProjectName% will restart.
	Reload
}

;;Check for updates via API
If (Settings.Settings.CheckforUpdates != 0) {
	;API call to check for latest version
	
	Endpoint := "https://api.github.com/gists/4e75bf4b588bf0762a34"
	LatestAPI := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	LatestAPI.Open("GET", Endpoint, False)
	LatestAPI.Send()
	Response := LatestAPI.ResponseText
	The_LatestVersion := Json_ToObj(Response).files.LoneIRC_LatestVersion.content
	
	;;Try to update if there is a new version detected. This will involve moving the executable 
	If (The_LatestVersion != "") {
		If (The_VersionName != The_LatestVersion && A_IsCompiled) {
			Msgbox, Updating to latest version: %The_LatestVersion%`n`nCheck your ...\Data\Settings.ini if you do not want to update automatically.
			FileMove, %A_ScriptFullPath%, %A_ScriptDir%\Data\%A_ScriptName%, 1
			Sleep 1000
			UrlDownloadToFile, http://downloadmob.com/files/public_exe/%The_ProjectName%.exe, %A_ScriptFullPath%
			Sleep 1000
			Run, %A_ScriptFullPath%
			ExitApp
		}
	}	
}


;;Create Trayicon Menu
TrayTipText := The_ProjectName
Sb_Menu(TrayTipText)

;;Create TTS Voices and Options
Loop, % StaticOption_Voices {
	obj_TTSVoice%A_Index% := ComObjCreate("SAPI.SPVoice")
	Fn_TTS(obj_TTSVoice%A_Index%, "SetVoice", Settings.Settings.TTSVoice)
}

If (Settings.Server.Addr = "") {
	MsgBox, Server address could not be understood. Check Settings.ini before running again.
	ExitApp
}

;Nick Settings
While (Settings.Server.Nicks = "") {
	InputBox, Raw_UserInput, %The_ProjectName%, % A_Space . "       " . "Choose UserName",, 200, 120,
	NickNames := Raw_UserInput . ", " . Raw_UserInput . "-"
	Settings.Server.Nicks := NickNames
	Settings.Server.User := Raw_UserInput
	If (Settings.Server.Nicks != "") {
		IniWrite, % Settings.Server.Nicks, Data\Settings.ini, Server, Nicks
		IniWrite, % Settings.Server.User, Data\Settings.ini, Server, User
	}
}

;Settings and Nick(s) to global simple vars
Server := Settings.Server
Nicks := StrSplit(Server.Nicks, ",", " `t")


Gui, Margin, 5, 5
Gui, Font, s9, Lucida Console
Gui, +HWNDhWnd +Resize

;Gui, Add, Edit, w1000 h300 ReadOnly vLog HWNDhLog ;Former raw view
;Gui, Add, Edit, xm y310 w1000 h299 ReadOnly vChat HWNDhChat

Chat := new RichEdit(1, "xm y310 w1000 h299 vChat")
;Chat.SetBkgndColor(0x3F3F3F)
Chat.SetOptions(["READONLY"], "Set")
Font := {"Name":"Courier New","Color":000000ff,"Size":9}
Colors := ["000000ff", "262626"
, "6C6C9C", "4CF3F2"
, "E8930B", "BC6C4C"
, "BC6C9C", "361A56"
, "368093", "CB130F"
, "80D4AA", "8CD0D3"
, "C0BED1", "ECBCBC"
, "8F8F8F", "DFDFDF"]
Chat.SetFont(Font)
Chat.AutoUrl(True)
Chat.HideSelection(False)
Chat.SetEventMask(["LINK"])
Chat.ID := DllCall("GetWindowLong", "UPtr", Chat.hWnd, "Int", -12) ; GWL_ID

Gui, Add, ListView, ym x1010 w130 h610 vListView -hdr, Hide
LV_ModifyCol(1, 130)
Gui, Add, DropDownList, xm w145 h20 vChannel r20 gDropDown, % Nicks[1] "||"
Gui, Add, Edit, w935 h20 x155 yp vMessage
Gui, Add, Button, yp-1 xp940 w45 h22 vSend gSend Default, SEND
Gui, Show, w800 h400, %The_ProjectName%

OnMessage(0x4E, "WM_NOTIFY")

IRC := new Bot(Settings.Trigger, Settings.Greetings, Settings.Aliases, Nicks, Settings.ShowHex)
IRC.Connect(Server.Addr, Server.Port, Nicks[1], Server.User, Server.Nick, Server.Pass)
IRC.SendJOIN(StrSplit(Server.Channels, ",", " `t")*)
;If user has a LHCP-Backchannel in settings
If (Server.LHCP_Channel != "") {
	IRC.SendJOIN(StrSplit(Server.LHCP_Channel, ",", " `t")*)
	LHCP_ON = 1
	Sb_CreateLHCP_WMPs(StaticOption_MultiLHCP)
	
	DataBase_Loc = %A_ScriptDir%\Data\LHCP_DataBase.json
	If (FileExist(DataBase_Loc)) {
		FileRead, MemoryFile, % DataBase_Loc
		LHCP_Array := json_toobj(MemoryFile)
		MemoryFile := ;BLANK
	} Else {
		LHCP_Array := Fn_GenerateDB()
	}
}


myTcp := new SocketTCP()
myTcp.bind("addr_any", 26656)
myTcp.listen()
myTcp.onAccept := Func("OnTCPAccept")
return

WM_NOTIFY(wParam, lParam, Msg, hWnd)
{
	static WM_LBUTTONDBLCLK := 0x203
	global Chat
	
	if (wParam == Chat.ID)
	{
		Msg := NumGet(lParam+A_PtrSize*2+4, "UInt")
		if (Msg == WM_LBUTTONDBLCLK)
		{
			Min := NumGet(lParam+A_PtrSize*4+8, "Int")
			Max := NumGet(lParam+A_PtrSize*4+12, "Int")
			Run, % Chat.GetTextRange(Min, Max)
		}
	}
}

OnTCPAccept()
{
	global myTcp
	newTcp := myTcp.accept()
	Text := newTcp.recvText()
	Comma := InStr(Text, ",")
	Channel := Trim(SubStr(Text, 1, Comma-1))
	Message := Trim(SubStr(Text, Comma+1))
	IRC.Chat(Channel, Message)
	newTcp.__Delete()
}

GuiSize:
EditH := Floor((A_GuiHeight-40)) ;Main Window
EditW := A_GuiWidth - (15 + 150)
ChatY := 6 + 0 ; Old view?
ListViewX := A_GuiWidth - 155 ;Users List
ListViewH := A_GuiHeight - 35

BarY := A_GuiHeight - 25 ;Text Input
TextW := A_GuiWidth - (20 + 145 + 45) ; Margin + DDL + Send
SendX := A_GuiWidth - 50 ;Send Button
SendY := BarY - 1

;GuiControl, Move, Log, x5 y5 w%EditW% h%EditH%
GuiControl, Move, Chat, x5 y%ChatY% w%EditW% h%EditH%
GuiControl, Move, ListView, x%ListViewX% y5 w150 h%ListViewH%
GuiControl, Move, Channel, x5 y%BarY% w145 h20
GuiControl, Move, Message, x155 y%BarY% w%TextW% h20
GuiControl, Move, Send, x%SendX% y%SendY% w45 h22
return

DropDown:
IRC.UpdateListView()
return

Send:
GuiControlGet, Message
GuiControl,, Message ; Clear input box

GuiControlGet, Channel

If RegexMatch(Message, "^/([^ ]+)(?: (.+))?$", Match)
{
	If (Match1 = "join")
		IRC._SendRAW("JOIN " Match2)
	Else If (Match1 = "me")
	{
		IRC.SendACTION(Channel, Match2)
		AppendChat("* " NickColor(IRC.Nick) " " Match2 " *")
	} Else If (Match1 = "part") {
		IRC.SendPART(Channel, Match2)
	} Else If (Match1 = "reload") {
		Reload
	} Else If (Match1 = "w") {
		IRC.SendPRIVMSG(Channel, Match2)
	} Else If (Match1 = "raw") {
		IRC._SendRaw(Match2)
	} Else If (Match1 = "nick") {
		IRC.SendNICK(Match2)
	} Else If (Match1 = "stop") {
		Fn_StopAllSounds(StaticOption_MultiLHCP)
	} Else If (Match1 = "lhcp") {
		Sb_InstallLHCP()
	} Else If (Match1 = "quit") {
		IRC.SendQUIT("LoneIRC")
		ExitApp
	} Else { ;Anything else may be considered an LHCP Command
		If (LHCP_ON = 1) {
			;Is it a // one? Convert to a random selection
			If (InStr(Match1,"/")) {
				;Remove all "/" as they overcomplicate things
				StringReplace, Match1, Match1, `/,, All
				LHCP_Command := LHCP Fn_GetRandomLHCP(Match1)
				If (LHCP_Command = "null") {
					Return ;No command found
				} Else {
					Match1 := LHCP_Command
				}
			}
			IRC.SendPRIVMSG(Settings.Server.LHCP_Channel, "/" . Match1)
			IRC.onPRIVMSG(IRC.Nick,IRC.User,IRC.Host,"PRIVMSG",[Settings.Server.LHCP_Channel],"/" . Match1,"")
		}
		;IRC.Log("ERROR: Unknown command " Match1)
	}
	Return
}

;If it matches custom plugin trigger
;Msgbox, 
If (RegexMatch(Msg, "^" this.Trigger "\K(\S+)(?:\s+(.+?))?\s*$", Match) && InStr(FileExist(A_ScriptDir "\Plugins"), "D"))
{
	Match1 := RegExReplace(Match1, "i)[^a-z0-9]")
	File := "plugins\" Match1 ".ahk"
	Param := Json_FromObj({"PRIVMSG":{"Nick":Nick,"User":User,"Host":Host
	,"Cmd":Cmd,"Params":Params,"Msg":Msg,"Data":Data}
	,"Plugin":{"Name":Match1,"Param":Match2,"Match":Match},"Channel":Params[1]})
	
	
	;Run or run default if not found
	If !FileExist(File) {
		Msgbox, % Param
		File := "plugins\Default.ahk"
	} Else {
		Run(A_AhkPath, File, Param)
	}
}


; Send chat and handle it
Messages := IRC.SendPRIVMSG(Channel, Message)
for each, Message in Messages
	IRC.onPRIVMSG(IRC.Nick,IRC.User,IRC.Host,"PRIVMSG",[Channel],Message,"")
return



GuiClose:
Fn_EnableMultiVoice(False)
IRC.SendQUIT("")
ExitApp
return

class Bot extends IRC
{
	__New(Trigger, Greetings, Aliases, DefaultNicks, ShowHex=false)
	{
		;default command triggers to "!" if not specified in settings (normal)
		If (Trigger = "") {
			Trigger = !
		}
		this.Trigger := Trigger
		this.Greetings := Greetings
		this.Aliases := Aliases
		this.DefaultNicks := DefaultNicks
		return base.__New(ShowHex)
	}
	
	onMODE(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		this.UpdateListView()
	}
	
	onJOIN(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		global Settings
		
		;Do nothing for LHCP-channel
		If (InStr(Settings.Server.LHCP_Channel,Msg) && Msg != "") {
			Return
		}
		
		If (Nick == this.Nick) { ;Self joining
			AppendChat("Connected")
			Fn_TTS_Go("Connected")
			this.UpdateDropDown(Params[1])
		} Else { ;Others joining
			AppendChat(NickColor(Nick) . " has joined")
			Fn_TTS_Go(Nick . " has joined")
		}
		this.UpdateListView()
	}
	
	; RPL_ENDOFNAMES
	on366(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		global Settings
		;Give up if LHCP channel
		If (Params[1] = Settings.Server.LHCP_Channel) {
			Return
		}
		
		this.UpdateListView()
	}
	
	onPART(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		If (Nick == this.Nick) {
			this.UpdateDropDown()
		}
		AppendChat(NickColor(Nick) . " has left " . Params[1] . "   " . (Msg ? " (" Msg ")" : ""))
		this.UpdateListView()
	}
	
	onNICK(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		; Can't use nick, was already handled by class
		If (User == this.User)
			this.UpdateDropDown()
		AppendChat(NickColor(Nick) " changed their name to " NickColor(Msg))
		this.UpdateListView()
	}
	
	onKICK(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		If (Params[2] == this.Nick)
			this.UpdateDropDown()
		AppendChat(NickColor(Params[2]) " was kicked by " NickColor(Nick) " (" Msg ")")
		Fn_TTS_Go("double rip " . Nick)
		this.UpdateListView()
	}
	
	onQUIT(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		If (Message != "") {
			AppendChat(NickColor(Nick) " has quit (" Msg ")")
		} Else {
			AppendChat(NickColor(Nick) " has quit")
			Fn_TTS_Go("rip " . Nick)
		}
		this.UpdateListView()
	}
	
	UpdateDropDown(Default="")
	{
		global Settings
		DropDL := "|"
		If (!Default) {
			GuiControlGet, Default,, Channel
		}
		for Channel in this.Channels {
			If (Settings.Server.LHCP_Channel = Channel) {
				Continue
			}
			DropDL .= Channel "|" (Channel==Default ? "|" : "")
		}
		If (!this.Channels.hasKey(Default)) {
			DropDL .= "|"
		}
		GuiControl,, Channel, % DropDL
	}
	
	UpdateListView()
	{
		GuiControlGet, Channel
		
		GuiControl, -Redraw, ListView
		LV_Delete()
		for Nick in this.GetMODE(Channel, "o")
			LV_Add("", this.Prefix.Letters["o"] . Nick)
		for Nick in this.GetMODE(Channel, "v -o") ; voiced not opped
			LV_Add("", this.Prefix.Letters["v"] . Nick)
		for Nick in this.GetMODE(Channel, "-ov") ; not opped or voiced
			LV_Add("", Nick)
		
		;Remove any blank user lines
		Loop % LV_GetCount() {
			LV_GetText(RowText, A_Index, 1)
			If (RowText = "") {
				LV_Delete(A_Index)
			}
		}
		GuiControl, +Redraw, ListView
	}
	
	onINVITE(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		If (User == this.User)
			this.SendJOIN(Msg)
	}
	
	onCTCP(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		If (Cmd = "ACTION")
			AppendChat("* " NickColor(Nick) . " " . Msg . " *")
		else
			this.SendCTCPReply(Nick, Cmd, "Zark off!")
	}
	
	onNOTICE(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		;Do not show notices from server
		;AppendChat("-" NickColor(Nick) "- " Msg)
		If (InStr(Msg,"Looking up your hostname")) {
			AppendChat("Connecting...")
		}
		;If (InStr(Msg,"Logon News")) {
		;AppendChat(Msg)
		;}
	}
	
	onPRIVMSG(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		global Settings
		
		;----------------------------------------------------------
		;Params[1] is the channel
		
		;Send to LHCP if in LHCP channel. Return out so no TTS
		If (Params[1] = Settings.Server.LHCP_Channel) {
			LHCP_arg := Fn_QuickRegEx(Msg,"\/(\S*)")
			If(LHCP_arg != "null") {
				AppendChat(NickColor(Nick) ": " Msg)
				Fn_LHCP_Go(LHCP_arg)
				Return
			}
		}
		;Send Msg to TTS and Chatbox
		Fn_TTS_Go(Msg)
		AppendChat(NickColor(Nick) ": " Msg)
		
		;Send message to chatlog function if applicable
		If (Settings.Settings.ChatLogs = 1) {
			Fn_Chatlog(Nick, Msg)
		}
		
		;GreetEx := "i)^((?:" this.Greetings
		;. "),?)\s.*" RegExEscape(this.Nick)
		;. "(?P<Punct>[!?.]*).*$"
		
		; Greetings holdover from bot functionality
		;if (RegExMatch(Msg, GreetEx, Match))
		;{
		;	this.Chat(Channel, Match1 " " Nick . MatchPunct)
		;	return
		;}
		
		; If it is being sent to us, but not by us
		;if (Channel == this.Nick && Nick != this.Nick)
		;	this.SendPRIVMSG(Nick, "Hello to you, good sir")
		
		If Msg contains % this.Nick
		{
			;SoundBeep
			TrayTip, % this.Nick, % "<" Nick "> " Msg
		}
		
		/*; If it is a command being sent by us, moved to sending area
			If (Nick = this.Nick) {
				If (RegexMatch(Msg, "^" this.Trigger "\K(\S+)(?:\s+(.+?))?\s*$", Match) && InStr(FileExist(A_ScriptDir "\Plugins"), "D"))
				{
					Match1 := RegExReplace(Match1, "i)[^a-z0-9]")
					File := "plugins\" Match1 ".ahk"
					Param := Json_FromObj({"PRIVMSG":{"Nick":Nick,"User":User,"Host":Host
					,"Cmd":Cmd,"Params":Params,"Msg":Msg,"Data":Data}
					,"Plugin":{"Name":Match1,"Param":Match2,"Match":Match},"Channel":Params[1]})
					
					If !FileExist(File) {
						File := "plugins\Default.ahk"
					}			
					Run(A_AhkPath, File, Param)
				}
			}
		*/
	}
	
	OnDisconnect(Socket)
	{
		ChannelBuffer := []
		for Channel in this.Channels
			ChannelBuffer.Insert(Channel)
		
		AppendLog("Attempting to reconnect: try #1")
		while !this.Connect(this.Server, this.Port, this.DefaultNicks[1], this.DefaultUser, this.Name, this.Pass)
		{
			Sleep, 5000
			AppendLog("Attempting to reconnect: try #" A_Index+1)
		}
		
		this.SendJOIN(ChannelBuffer*)
		
		this.UpdateDropDown()
		this.UpdateListView()
	}
	
	Chat(Channel, Message)
	{
		Messages := this.SendPRIVMSG(Channel, Message)
		for each, Message in Messages
			AppendChat(NickColor(this.Nick)": " Message)
		return Messages
	}
	
	; ERR_NICKNAMEINUSE
	on433(Nick,User,Host,Cmd,Params,Msg,Data)
	{
		this.Reconnect()
	}
	
	Reconnect()
	{
		for Index, Nick in this.DefaultNicks
			if (Nick == this.Nick)
				Break
		Index := (Index >= this.DefaultNicks.MaxIndex()) ? 1 : Index+1
		NewNick := this.DefaultNicks[Index]
		
		AppendChat(NickColor(this.Nick) " changed their nick to " NickColor(NewNick))
		
		this.SendNICK(newNick)
		this.Nick := newNick
		
		this.UpdateDropDown()
		this.UpdateListView()
	}
	
	Log(Message)
	{
		AppendLog(Message)
	}
}

AppendLog(Message)
{
	static WM_VSCROLL := 0x115, SB_BOTTOM := 7
	, EM_SETSEL := 0xB1, EM_REPLACESEL := 0xC2
	, EM_GETSEL := 0xB0, WM_GETTEXTLENGTH := 0xE
	, EM_SCROLLCARET := 0xB7
	global hLog
	
	Message := RegExReplace(Message, "\R", "") "`r`n"
	GuiControl, -Redraw, %hLog%
	
	VarSetCapacity(Sel, 16, 0)
	SendMessage(hLog, EM_GETSEL, &Sel, &Sel+8)
	Min := NumGet(Sel, 0, "UInt")
	Max := NumGet(Sel, 8, "UInt")
	
	Len := SendMessage(hLog, WM_GETTEXTLENGTH, 0, 0)
	SendMessage(hLog, EM_SETSEL, Len, Len)
	SendMessage(hLog, EM_REPLACESEL, False, &Message)
	
	if (Min != Len)
	{
		SendMessage(hLog, EM_SETSEL, Min, Max)
		GuiControl, +Redraw, %hLog%
	}
	else
	{
		GuiControl, +Redraw, %hLog%
		SendMessage(hLog, WM_VSCROLL, SB_BOTTOM, 0)
	}
}

GetScrollInfo(hwnd, fnBar, ByRef nPos=0, ByRef nTrackPos=0, ByRef nMin=0, ByRef nMax=0, ByRef nPage=0)
{
	VarSetCapacity(si, 28, 0) ; SCROLLINFO si
	NumPut(28  , si, 0) ; si.cbSize := sizeof(SCROLLINFO)
	NumPut(0x17, si, 4) ; si.fMask := SIF_ALL
	
	If (!DllCall("GetScrollInfo", "uint", hwnd, "int", fnBar, "uint", &si))
		Return false
	
	nPos        := NumGet(si, 20)
	nTrackPos   := NumGet(si, 24)
	nMin        := NumGet(si,  8)
	nMax        := NumGet(si, 12)
	nPage       := NumGet(si, 16)
	Return true
}

AppendChat(Message)
{
	global Chat, Colors, Settings, Font, LastScrollPos, LastScrollMax, LastScrollPage
	static WM_VSCROLL := 0x115, SB_BOTTOM := 7, SB_VERT := 1
	
	Message := RegExReplace(Message, "\R", "") "`n"
	FormatTime, TimeStamp,, [hh:mm]
	
	If (Settings.Settings.TimeStampsFlag = 1)
		RTF := ToRTF(TimeStamp " " Message, Colors, Font)
	Else
		RTF := ToRTF(Message, Colors, Font)
	
	;Redraw Chatbox with latest message
	GuiControl, -Redraw, % Chat.hWnd
	Sel := Chat.GetSel()
	Len := Chat.GetTextLen()
	Chat.SetSel(Len, Len)
	Chat.SetText(RTF, ["SELECTION"])
	
	GetScrollInfo(Chat.hWnd, SB_VERT, ScrollPos, TrackPos, ScrollMin, ScrollMax, ScrollPage)
	
	;Scroll the Chatbox to the bottom if it was previously at the bottom, 
	;or the chat window has been resized since the last message,
	;or if the scrollbar was previously hidden.
	;actually LastScrollPos isn't used at all, you can get rid of that one
	If (ScrollPos + ScrollPage = LastScrollMax or ScrollPage <> LastScrollPage or LastScrollMax = 1)
	{
		GuiControl, +Redraw, % Chat.hWnd
		SendMessage(Chat.hWnd, WM_VSCROLL, SB_BOTTOM, 0)
	}
	Else
	{
		Chat.SetSel(Sel.S, Sel.E)
		GuiControl, +Redraw, % Chat.hWnd
	}
	
	LastScrollPos := ScrollPos
	LastScrollMax := ScrollMax
	LastScrollPage := ScrollPage
}

SendMessage(hWnd, Msg, wParam, lParam)
{
	Return DllCall("SendMessage", "UPtr", hWnd, "UInt", Msg, "UPtr", wParam, "Ptr", lParam)
}

ToRTF(Text, Colors, Font)
{
	FontTable := "{\fonttbl{\f0\fnil\fcharset0 "
	FontTable .= Font.Name
	FontTable .= ";`}}"
	
	ColorTable := "{\colortbl"
	for each, Color in Colors
	{
		Red := "0x" SubStr(Color, 1, 2)
		Green := "0x" SubStr(Color, 3, 2)
		Blue := "0x" SubStr(Color, 5, 2)
		ColorTable .= ";\red" Red+0 "\green" Green+0 "\blue" Blue+0
	}
	Color := Font.Color & 0xFFFFFF
	ColorTable .= ";\red" Color>>16&0xFF "\green" Color>>8&0xFF "\blue" Color&0xFF
	ColorTable .= ";`}"
	
	RTF := "{\rtf"
	RTF .= FontTable
	RTF .= ColorTable
	
	For each, Char in ["\", "{", "}", "`r", "`n"]
		StringReplace, Text, Text, %Char%, \%Char%, All
	
	While RegExMatch(Text, "^(.*)\x03(\d{0,2})(?:,(\d{1,2}))?(.*)$", Match)
		Text := Match1 . ((Match2!="") ? "\cf" Match2+1 : "\cf1") . ((Match3!="") ? "\highlight" Match3+1 : "") " " Match4
	
	Bold := Chr(2)
	Color := Chr(3)
	Normal := Chr(15)
	Italic := Chr(29)
	Under := Chr(31)
	NormalFlags := "\b0\i0\ul0\cf17\highlight0\f0\fs" Font.Size*2
	
	tBold := tItalic := tUnder := false
	For each, Char in StrSplit(Normal . Text . Normal) {
		If (Char == Bold) {
			RTF .= ((tBold := !tBold) ? "\b1" : "\b0") " "
		} Else If (Char == Italic) {
			RTF .= ((tItalic := !tItalic) ? "\i1" : "\i0") " "
		} Else If (Char == Under) {
			RTF .= ((tUnder := !tUnder) ? "\ul1" : "\ul0") " "
		} Else If (Char == Normal) {
			RTF .= NormalFlags " ", tBold := tItalic := tUnder := False
		} Else If (Asc(Char) > 0xFF) {
			RTF .= "\u" Asc(Char) . Char
		} Else {
			RTF .= Char
		}
	}
	RTF .= "}"
	return RTF
}

NickColor(Nick)
{
	for each, Char in StrSplit(Nick)
		Sum += Asc(Char)
	
	Color := Mod(Sum, 16)
	if Color in 0,1,14,15
		Color := Mod(Sum, 12) + 2
	
	return Chr(2) . Chr(3) . Color . Nick . Chr(3) . Chr(2)
}


Fn_TTS_Go(para_Message)
{
	global Rotation_Voice
	global Settings
	global obj_TTSVoice1
	global obj_TTSVoice2
	global obj_TTSVoice3
	global obj_TTSVoice4
	global obj_TTSVoice5
	global obj_TTSVoice6
	global obj_TTSVoice7
	global obj_TTSVoice8
	global obj_TTSVoice9
	global obj_TTSVoice10
	global obj_TTSVoice11
	global obj_TTSVoice12
	
	
	If (Settings.Settings.TTSFlag = 1) {
		TTSVar := "! " . para_Message
		StringReplace, TTSVar, TTSVar, `",, All ;string end "
		
		;Remove urls from spoken text
		If (InStr(TTSVar,"http")) {
			TTSVar := RegExReplace(TTSVar, "\bhttps?:\/\/\S*", "")
		}

		;replace # with the word "hashtag"
		If (InStr(TTSVar,"#")) {
			TTSVar := RegExReplace(TTSVar, "\#[^ ]", "hashtag ")
		}
		
		;Check that rotation is not at max
		Rotation_Voice++
		If (Rotation_Voice > 12) {
			Rotation_Voice := 1
		}
		;Speak Now!
		TTSVar := A_Space . TTSVar
		obj_TTSVoice%Rotation_Voice%.Speak(TTSVar, 0x1)
	}
	Return
}


Sb_Menu(TipLabel)
{
	global
	
	Voice := ComObjCreate("SAPI.SpVoice")
	AllVoices := Fn_TTS(Voice, "GetVoices")
	Voice :=
	
	Loop, parse, AllVoices, `n, `r
	{
		Menu, Speach_Menu, Add, %A_LoopField%, SelectedSpeach
		If (A_Index = 1) {
			FirstVoice := A_LoopField
		}
	}
	;Write New Voice to settings if no voice has been selected
	If (Settings.Settings.TTSVoice = "") {
		Settings.Settings.TTSVoice := FirstVoice
		IniWrite, % Settings.Settings.TTSVoice, Data\Settings.ini, Settings, TTSVoice
	}
	
	Menu, Tray, Tip , %The_ProjectName%
	Menu, Tray, NoStandard
	Menu, Tray, Add, %TipLabel%, menu_About
	If (A_IsCompiled) {
		Menu, tray, Icon, %TipLabel%, %A_ScriptDir%\%A_ScriptName%, 1, 0
	}
	
	Menu, Tray, Add
	If (FirstVoice != "") {
		Menu, Tray, Add, Choose TTS Voice, :Speach_Menu
	}
	
	Menu, Options_Menu, Add, TTS, menu_Toggle
	Menu, Options_Menu, Add, TimeStamps, menu_Toggle
	Menu, Options_Menu, Add, Volume, menu_Volume
	Menu, Tray, Add, Options, :Options_Menu
	
	Fn_CheckmarkInitialize("TTS", "Options_Menu", Settings.Settings.TTSFlag)
	Fn_CheckmarkInitialize("TimeStamps", "Options_Menu", Settings.Settings.TimeStampsFlag)
	;CheckMark the current TTS Voice
	Menu, Speach_Menu, Check, % Settings.Settings.TTSVoice
	
	Menu, Tray, Add, About, menu_About
	Menu, Tray, Add, Quit, menu_Quit
	Return
	
	menu_About:
	Msgbox, %The_ProjectName% - %The_VersionName% `nhttps://github.com/Chunjee/LoneIRC
	Return
	
	menu_Quit:
	ExitApp
}


menu_Volume:
Gui, Volume: Destroy ;Destroy GUI because it will be made again
Gui, Volume: Add, Slider, x10 y10 w24 h200 NoTicks Line1 Page10 Thick20 Center Vertical Invert vThe_VolumeSlider gNewVolume, % Settings.Settings.Volume
Gui, Volume: Show, w160 h220, Volume
Gui, Volume: +owner
Return

NewVolume:

IniWrite, %The_VolumeSlider%, Data\Settings.ini, Settings, Volume
Settings := Ini_Read(SettingsFile)
Return

;;TTS Selected
SelectedSpeach:
Settings_TTSVoice = %A_ThisMenuItem%
IniWrite, %Settings_TTSVoice%, Data\Settings.ini, Settings, TTSVoice

;Re-Import Settings from file
Settings := Ini_Read(SettingsFile)
;Re-set all Voices
Sb_SetAllVoices()

;Do Checkmarks for each voice
Loop, parse, AllVoices, `n, `r
{
	If (A_LoopField = Settings.Settings.TTSVoice) {
		Fn_CheckmarkInitialize(A_LoopField, "Speach_Menu", 1)
	} Else {
		Fn_CheckmarkInitialize(A_LoopField, "Speach_Menu", 0)
	}
}
Return



menu_Toggle:
Fn_CheckmarkToggle(A_ThisMenuItem, A_ThisMenu)
Return

Fn_CheckmarkInitialize(para_MenuItem, para_MenuName, para_Setting := 0)
{
	If (para_Setting = 1) {
		Menu, %para_MenuName%, Check, %para_MenuItem%
	} Else {
		Menu, %para_MenuName%, UnCheck, %para_MenuItem%
	}
}

Fn_CheckmarkToggle(MenuItem, MenuName)
{
	global
	
	If (%MenuItem%Flag = "")
	{
		%MenuItem%Flag := %MenuItem%Flag
	}
	
	%MenuItem%Flag := !%MenuItem%Flag ;Toggles the variable every time the function is called
	If (%MenuItem%Flag) {
		Menu, %MenuName%, Check, %MenuItem%
	} Else {
		Menu, %MenuName%, UnCheck, %MenuItem%
	}
	
	NewSetting := %MenuItem%Flag
	IniWrite, %NewSetting%, Data\Settings.ini, Settings, %MenuItem%Flag
	;Re-Import Settings from file
	Settings := Ini_Read(SettingsFile)
}

Fn_EnableMultiVoice(YesNo = True)
{
	static AudioOut := ComObjCreate("SAPI.SPVoice").AudioOutput.ID
	, RegKey := SubStr(AudioOut, InStr(AudioOut, "\")+1) "\Attributes"
	
	if YesNo
	{
		RegRead, OutputVar, HKCU, %RegKey%, NoSerializeAccess
		if ErrorLevel {
			RegWrite, REG_SZ, HKCU, %RegKey%, NoSerializeAccess
		} ; Doesn't exist
		return ErrorLevel
	} else {
		RegDelete, HKCU, %RegKey%, NoSerializeAccess
	}
}


Startup()
{
	#NoEnv
	#SingleInstance Force
}

Sb_InstallFiles()
{
	;Empty
}

Sb_SetAllVoices()
{
	global
	Loop, % StaticOption_Voices {
		Fn_TTS(obj_TTSVoice%A_Index%, "SetVoice", Settings.Settings.TTSVoice)
	}
}

Sb_CreateLHCP_WMPs(para_CreateNumber)
{
	global
	
	Loop, %para_CreateNumber%
	{
		wmp%A_Index% := ComObjCreate("WMPlayer.OCX")
		Rotation_WMP := A_Index
	}
}

Sb_InstallLHCP()
{
	global
	LHCP_ON = 1
	UrlDownloadToFile, http://downloadmob.com/files/public_exe/LHCP-X.exe, %A_ScriptDir%\Data\LHCP-X.exe
	
	;Write new settings to file and re-load
	Settings.Server.LHCP_Channel := "#LHCP-XBeta"
	File := FileOpen(SettingsFile, "w")
	File.Write(Settings), File.Close()
	
	Settings := Ini_Read(SettingsFile)
}


Fn_GetRandomLHCP(para_Arg)
{
	global LHCP_Array
	global StaticOption_MultiLHCP
	
	;;Make list of simple matches if user specified //command
	;If (InStr(para_Arg,"/")) {
	;StringReplace, para_Arg, para_Arg, `/,, All
	
	;Try to find an exact match first
	Loop, % LHCP_Array.MaxIndex() {
		If(para_Arg = LHCP_Array[A_Index,"Command"]) {
			Return LHCP_Array[A_Index,"Command"]
		}
	}
	
	;Look for a containing match
	Temp_Array := []
	X = 0
	Loop, % LHCP_Array.MaxIndex() {
		If(InStr(LHCP_Array[A_Index,"Command"],para_Arg) || InStr(LHCP_Array[A_Index,"Phrase"],para_Arg)) {
			X ++
			Temp_Array[X,"Command"] := LHCP_Array[A_Index,"Command"]
			Temp_Array[X,"Phrase"] := LHCP_Array[A_Index,"Phrase"]
			Temp_Array[X,"FilePath"] := LHCP_Array[A_Index,"FilePath"]
		}
	}
	;Choose random out of possible matches and play it
	
	If (Temp_Array.MaxIndex() >= 1) {
		Random, Rand, 1, Temp_Array.MaxIndex()
		;Fn_PlaySound(LHCP_Array[Rand,"FilePath"])
		Return Temp_Array[Rand,"Command"]
	}
	Return "null"
}


Fn_LHCP_Go(para_Arg)
{
	global LHCP_Array
	global StaticOption_MultiLHCP
	
	If (para_Arg = "jason") {
		LHCP_Array := Fn_GenerateDB()
		Return
	}
	If (para_Arg = "stop") {
		;Stop all Clips
		Fn_StopAllSounds(StaticOption_MultiLHCP)
		Return
	}
	
	If (para_Arg) {
		;Look for exact match on command and play it if found
		Loop, % LHCP_Array.MaxIndex() {
			If(para_Arg = LHCP_Array[A_Index,"Command"]) {
				Fn_PlaySound(LHCP_Array[A_Index,"FilePath"])
				Return 1
			}
		}
	}
	Return "null"
}


Fn_PlaySound(para_SoundPath)
{
	global
	
	If (Settings.Settings.Volume = "") {
		Settings.Settings.Volume := 42
	}
	
	Rotation_WMP++
	If (Rotation_WMP > StaticOption_MultiLHCP) {
		Rotation_WMP = 1
	}
	
	wmp%Rotation_WMP%.url := para_SoundPath
	wmp%Rotation_WMP%.settings.volume := Settings.Settings.Volume
	wmp%Rotation_WMP%.controls.play
	Return wmp%Rotation_WMP%
}


Fn_StopAllSounds(para_StopNumber)
{
	global
	
	Loop, % para_StopNumber
	{
		wmp%Rotation_WMP%.controls.stop
	}
	Loop, % para_StopNumber
	{
		wmp%Rotation_WMP%.controls.stop
	}
	Loop, % para_StopNumber
	{
		wmp%Rotation_WMP%.controls.stop
	}
}


Fn_GenerateDB()
{
	TempArray := []
	
	Total_mp3s = 0
	Loop, %A_ScriptDir%\Data\Clips\*#*.mp3 , 1
	{
		Total_mp3s ++
	}
	
	;Loop all mp3 files
	Loop, %A_ScriptDir%\Data\Clips\*#*.mp3 , 1
	{
		Command := Fn_QuickRegEx(A_LoopFileName,"(.+)#")
		Phrase := Fn_QuickRegEx(A_LoopFileName,"#(.+)")
		
		If (Command != "null" && Phrase != "null") {
			TempArray[A_Index,"FilePath"] := A_LoopFileFullPath
			TempArray[A_Index,"Command"] := Command
			TempArray[A_Index,"Phrase"] := Phrase
		}
	}
	;Write out the newley created Array and return it for the MAIN
	FileDelete, %A_ScriptDir%\Data\LHCP_DataBase.json
	FileAppend, % json_fromobj(TempArray), %A_ScriptDir%\Data\LHCP_DataBase.json
	Return % TempArray
}
