#NoEnv
#NoTrayIcon
; #Warn
#SingleInstance Off

if !A_IsAdmin && !%False%
{
    if A_OSVersion not in WIN_2003,WIN_XP,WIN_2000
    {
        Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%",, UseErrorLevel
        if !ErrorLevel
            ExitApp
    }
    MsgBox 0x31, AutoHotkey 安装,
    (LTrim Join`s
    以受限用户身份运行安装程序。如果继续，很可
    能会发生一些问题。我们强烈建议您作为管理员
    运行安装程序。`n
    `n
    要继续, 单击“确定”。否则，请单击“取消”。
    )
    IfMsgBox Cancel
        ExitApp
}

SourceDir := A_ScriptDir
SilentMode := false
SilentErrors := 0

if 0 > 0
if 1 = /kill ; 供内部使用。
{
    DetectHiddenWindows On
    WinKill % "ahk_id " %0%
    ExitApp
}
else if 1 = /fin ; 供内部使用。
{
    DetectHiddenWindows On
    WinKill % "ahk_id " %0%
    WinWaitClose % "ahk_id " %0%,, 1
    
    exefile = %2%
    InstallFile(exefile, "AutoHotkey.exe")
    if 3 = 0 ; SilentMode
        MsgBox 64, AutoHotkey 安装, 设置已更新.
    ExitApp
}
else if 1 = /runahk ; 供内部使用。
{
    RunAutoHotkey_()
    ExitApp
}

ProductName := "AutoHotkey"
ProductVersion := A_AhkVersion
ProductPublisher := "Lexikos"
ProductWebsite := "http://www.autohotkey.com/"

EnvGet ProgramW6432, ProgramW6432
DefaultPath := (ProgramW6432 ? ProgramW6432 : A_ProgramFiles) "\AutoHotkey"
DefaultType := A_Is64bitOS ? "x64" : "Unicode"
DefaultStartMenu := "AutoHotkey"
DefaultCompiler := true
DefaultDragDrop := true
DefaultToUTF8 := false
DefaultIsHostApp := false
AutoHotkeyKey := "SOFTWARE\AutoHotkey"
UninstallKey := "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AutoHotkey"
FileTypeKey := "AutoHotkeyScript"

DetermineVersion()

Loop %0%
    if %A_Index% = /S
        SilentMode := true
    else if %A_Index% = /U32
        DefaultType = Unicode
    else if %A_Index% in /U64,/x64
        DefaultType = x64
    else if %A_Index% in /A32,/ANSI
        DefaultType = ANSI
    else if InStr(%A_Index%, "/D=") = 1 {
        if !RegExMatch(DllCall("GetCommandLine", "str"), "(?<!"")/D=\K[^""]*?(?=$|[ `t]+/)", DefaultPath)
            DefaultPath := SubStr(%A_Index%, 4)
        Loop %DefaultPath%, 2  ; 解决相对路径。
            DefaultPath := A_LoopFileLongPath
        SlashD := true
    }
    else if (%A_Index% = "/?") {
        ViewHelp("/docs/Scripts.htm#install")
        ExitApp
    }
    else if (%A_Index% = "/Uninstall") {
        SilentMode := true
        Uninstall()
        ExitApp
    }
    else if (%A_Index% = "/E") {
        Extract(SlashD ? DefaultPath : "")
        ExitApp
    }
    else if (SubStr(%A_Index%,1,5) = "/Test") {
        TestMode := SubStr(%A_Index%,6)
    }

if SilentMode {
    QuickInstall()
    ExitApp % SilentErrors
}

if WinExist("AutoHotkey 安装 ahk_class AutoHotkeyGUI") {
    MsgBox 0x30, AutoHotkey 安装, AutoHotkey 安装 已经运行!
    WinActivate
    ExitApp
}

OnExit GuiClose

Gui Margin, 0, 0
Gui Add, ActiveX, vwb w600 h400 hwndhwb, Shell.Explorer
ComObjConnect(wb, "wb_")
OnMessage(0x100, "gui_KeyDown", 2)
try {
    if (TestMode = "FailUI")
        throw
    InitUI()
}
catch {
    if (A_ScriptDir = DefaultPath) {
        MsgBox 0x10, AutoHotkey 安装, 安装程序初始化失败，现在退出用户界面.
        ExitApp
    }
    MsgBox 0x14, AutoHotkey 安装,
    (LTrim Join`s`s
    安装程序用户界面初始化失败。
    你想保存AutoHotkey的程序文件吗？
    (您需要选择一个文件夹，保存它们。)
    )
    IfMsgBox Yes
        Extract()
    ExitApp
}
Gui Show,, AutoHotkey 安装
return

GuiEscape:
MsgBox 0x34, AutoHotkey 安装, 你确定要退出设置?
IfMsgBox No
    return
GuiClose:
Gui Destroy
OnExit
ExitApp

DetermineVersion() {
    global
    local url, v
    ; 第一部分有两个目的:
    ;  1) 任何当前安装的位置确定。
    ;  2) 确定的注册表视图，它被安装到
    ;     (只适用，如果操作系统是64位).
    CurrentRegView := ""
    Loop % (A_Is64bitOS ? 2 : 1) {
        SetRegView % 32*A_Index
        RegRead CurrentPath, HKLM, %AutoHotkeyKey%, InstallDir
        if !ErrorLevel {
            CurrentRegView := A_RegView
            break
        }
    }
    if ErrorLevel {
        CurrentName := ""
        CurrentVersion := ""
        CurrentType := ""
        CurrentPath := ""
        CurrentStartMenu := ""
        return
    }
    RegRead CurrentVersion, HKLM, %AutoHotkeyKey%, Version
    RegRead CurrentStartMenu, HKLM, %AutoHotkeyKey%, StartMenuFolder
    RegRead url, HKLM, %UninstallKey%, URLInfoAbout
    ; 通过URL识别，因为卸载程序显示名称是相同的:
    if (url = "http://www.autohotkey.net/~Lexikos/AutoHotkey_L/"
        || url = "http://l.autohotkey.net/")
        CurrentName := "AutoHotkey_L"
    else
        CurrentName := "AutoHotkey"
    ; 确定哪些编译安装/设置为默认值:
    FileAppend ExitApp `% (A_IsUnicode=1) << 8 | (A_PtrSize=8) << 9, %A_Temp%\VersionTest.ahk
    RunWait %CurrentPath%\AutoHotkey.exe "%A_Temp%\VersionTest.ahk",, UseErrorLevel
    if ErrorLevel = 0x300
        CurrentType := "x64"
    else if ErrorLevel = 0x100
        CurrentType := "Unicode"
    else if ErrorLevel = 0
        CurrentType := "ANSI"
    else
        CurrentType := ""
    FileDelete %A_Temp%\VersionTest.ahk
    ; 基于当前的安装设置一些默认参数:
    if CurrentType
        DefaultType := CurrentType
    DefaultPath := CurrentPath
    DefaultStartMenu := CurrentStartMenu
    DefaultCompiler := FileExist(CurrentPath "\Compiler\Ahk2Exe.exe") != ""
    RegRead v, HKCR, %FileTypeKey%\ShellEx\DropHandler
    DefaultDragDrop := ErrorLevel = 0
    RegRead v, HKCR, Applications\AutoHotkey.exe, IsHostApp
    DefaultIsHostApp := !ErrorLevel
    RegRead v, HKCR, %FileTypeKey%\Shell\Open\Command
    DefaultToUTF8 := InStr(v, " /CP65001 ") != 0
}

InitUI() {
    local w
    SetWBClientSite()
    gosub DefineUI
    wb.Silent := true
    wb.Navigate("about:blank")
    while wb.ReadyState != 4
        Sleep 10
    wb.Document.open()
    wb.Document.write(html)
    wb.Document.Close()
    w := wb.Document.parentWindow
    if (!CurrentType && A_ScriptDir != DefaultPath)
        CurrentName := ""  ; 避免重新安装选项，因为我们不知道这是哪个版本。
    w.initOptions(CurrentName, CurrentVersion, CurrentType
                , ProductVersion, DefaultPath, DefaultStartMenu
                , DefaultType, A_Is64bitOS = 1)
    if (A_ScriptDir = DefaultPath) {
        w.installdir.disabled := true
        w.installdir_browse.disabled := true
        w.installcompiler.disabled := !DefaultCompiler
        w.installcompilernote.style.display := "block"
        w.ci_nav_install.innerText := "apply"
        w.install_button.innerText := "Apply"
        w.extract.style.display := "None"
        w.opt1.disabled := true
        w.opt1.firstChild.innerText := "检查更新..."
        SetTimer CheckForUpdates, -500
    }
    w.installcompiler.checked := DefaultCompiler
    w.enabledragdrop.checked := DefaultDragDrop
    w.separatebuttons.checked := DefaultIsHostApp
    ; w.defaulttoutf8.checked := DefaultToUTF8
    if !A_Is64bitOS
        w.it_x64.style.display := "None"
    if A_OSVersion in WIN_2000,WIN_2003,WIN_XP ; i.e. not WIN_7, WIN_8 or a future OS.
        w.separatebuttons.parentNode.style.display := "none"
    w.switchPage("start")
    w.document.body.focus()
}

CheckForUpdates:
CheckForUpdates()
return
CheckForUpdates() {
    local w := getWindow(), latestVersion := ""
    URLDownloadToFile http://l.autohotkey.net/version.txt, %A_Temp%\ahk_version.txt
    if !ErrorLevel {
        FileRead latestVersion, %A_Temp%\ahk_version.txt
        FileDelete %A_Temp%\ahk_version.txt
    }
    if RegExMatch(latestVersion, "^(\d+\.){3}\d+") {
        if (latestVersion = ProductVersion)
            w.opt1.firstChild.innerText := "Reinstall (download required)"
        else
            w.opt1.firstChild.innerText := "Download v" latestVersion
        w.opt1.href := "ahk://Download/"
        w.opt1.disabled := false
    } else
        w.opt1.innerText := "检查更新时发生错误。"
}

/*  修复WebBrowser控件中的键盘快捷键。
 *  References:
 *    http://www.autohotkey.com/community/viewtopic.php?p=186254#p186254
 *    http://msdn.microsoft.com/en-us/library/ms693360
 */

gui_KeyDown(wParam, lParam, nMsg, hWnd) {
    global wb
    pipa := ComObjQuery(wb, "{00000117-0000-0000-C000-000000000046}")
    VarSetCapacity(kMsg, 48), NumPut(A_GuiY, NumPut(A_GuiX
    , NumPut(A_EventInfo, NumPut(lParam, NumPut(wParam
    , NumPut(nMsg, NumPut(hWnd, kMsg)))), "uint"), "int"), "int")
    Loop 2
    r := DllCall(NumGet(NumGet(1*pipa)+5*A_PtrSize), "ptr", pipa, "ptr", &kMsg)
    ; Loop to work around an odd tabbing issue (it's as if there
    ; is a non-existent element at the end of the tab order).
    until wParam != 9 || wb.Document.activeElement != ""
    ObjRelease(pipa)
    if r = 0 ; S_OK: the message was translated to an accelerator.
        return 0
}


/*  ahk://Func/Param  -->  Func("Param")
 */

wb_BeforeNavigate2(wb, url, flags, frame, postdata, headers, cancel) {
    if !RegExMatch(url, "^ahk://(.*?)/(.*)", m)
        return
    static func, prms
    func := m1
    prms := []
    StringReplace m2, m2, `%20, %A_Space%, All
    Loop Parse, m2, `,
        prms.Insert(A_LoopField)
    ; Cancel: don't load the error page (or execute ahk://whatever
    ; if it happens to somehow be a registered protocol).
    NumPut(-1, ComObjValue(cancel), "short")
    ; Call after a delay to allow navigation (this might only be
    ; necessary if called from NavigateError; i.e. on Windows 8).
    SetTimer wb_bn2_call, -15
    return
wb_bn2_call:
    %func%(prms*)
    func := prms := ""
    return
}

wb_NavigateError(wb, url, frame, status, cancel) {
    ; This might only be called on Windows 8, which skips the
    ; BeforeNavigate2 call (because the protocol is invalid?).
    wb_BeforeNavigate2(wb, url, 0, frame, "", "", cancel)
}


/*  复杂的解决方法，以覆盖 "活动脚本" 设置
 *  and ensure scripts can run within the WebBrowser control.
 */

global WBClientSite

SetWBClientSite()
{
    interfaces := {
    (Join,
        IOleClientSite: [0,3,1,0,1,0]
        IServiceProvider: [3]
        IInternetSecurityManager: [1,1,3,4,8,7,3,3]
    )}
    unkQI      := RegisterCallback("WBClientSite_QI", "Fast")
    unkAddRef  := RegisterCallback("WBClientSite_AddRef", "Fast")
    unkRelease := RegisterCallback("WBClientSite_Release", "Fast")
    WBClientSite := {_buffers: bufs := {}}, bufn := 0, 
    for name, prms in interfaces
    {
        bufn += 1
        bufs.SetCapacity(bufn, (4 + prms.MaxIndex()) * A_PtrSize)
        buf := bufs.GetAddress(bufn)
        NumPut(unkQI,       buf + 1*A_PtrSize)
        NumPut(unkAddRef,   buf + 2*A_PtrSize)
        NumPut(unkRelease,  buf + 3*A_PtrSize)
        for i, prmc in prms
            NumPut(RegisterCallback("WBClientSite_" name, "Fast", prmc+1, i), buf + (3+i)*A_PtrSize)
        NumPut(buf + A_PtrSize, buf + 0)
        WBClientSite[name] := buf
    }
    global wb
    if pOleObject := ComObjQuery(wb, "{00000112-0000-0000-C000-000000000046}")
    {   ; IOleObject::SetClientSite
        DllCall(NumGet(NumGet(pOleObject+0)+3*A_PtrSize), "ptr"
            , pOleObject, "ptr", WBClientSite.IOleClientSite, "uint")
        ObjRelease(pOleObject)
    }
}

WBClientSite_QI(p, piid, ppvObject)
{
    static IID_IUnknown := "{00000000-0000-0000-C000-000000000046}"
    static IID_IOleClientSite := "{00000118-0000-0000-C000-000000000046}"
    static IID_IServiceProvider := "{6d5140c1-7436-11ce-8034-00aa006009fa}"
    iid := _String4GUID(piid)
    if (iid = IID_IOleClientSite || iid = IID_IUnknown)
    {
        NumPut(WBClientSite.IOleClientSite, ppvObject+0)
        return 0 ; S_OK
    }
    if (iid = IID_IServiceProvider)
    {
        NumPut(WBClientSite.IServiceProvider, ppvObject+0)
        return 0 ; S_OK
    }
    NumPut(0, ppvObject+0)
    return 0x80004002 ; E_NOINTERFACE
}

WBClientSite_AddRef(p)
{
    return 1
}

WBClientSite_Release(p)
{
    return 1
}

WBClientSite_IOleClientSite(p, p1="", p2="", p3="")
{
    if (A_EventInfo = 3) ; GetContainer
    {
        NumPut(0, p1+0) ; *ppContainer := NULL
        return 0x80004002 ; E_NOINTERFACE
    }
    return 0x80004001 ; E_NOTIMPL
}

WBClientSite_IServiceProvider(p, pguidService, piid, ppvObject)
{
    static IID_IUnknown := "{00000000-0000-0000-C000-000000000046}"
    static IID_IInternetSecurityManager := "{79eac9ee-baf9-11ce-8c82-00aa004ba90b}"
    if (_String4GUID(pguidService) = IID_IInternetSecurityManager)
    {
        iid := _String4GUID(piid)
        if (iid = IID_IInternetSecurityManager || iid = IID_IUnknown)
        {
            NumPut(WBClientSite.IInternetSecurityManager, ppvObject+0)
            return 0 ; S_OK
        }
        NumPut(0, ppvObject+0)
        return 0x80004002 ; E_NOINTERFACE
    }
    NumPut(0, ppvObject+0)
    return 0x80004001 ; E_NOTIMPL
}

WBClientSite_IInternetSecurityManager(p, p1="", p2="", p3="", p4="", p5="", p6="", p7="", p8="")
{
    if (A_EventInfo = 5) ; ProcessUrlAction
    {
        if (p2 = 0x1400) ; dwAction = URLACTION_SCRIPT_RUN
        {
            NumPut(0, p3+0)  ; *pPolicy := URLPOLICY_ALLOW
            return 0 ; S_OK
        }
    }
    return 0x800C0011 ; INET_E_DEFAULT_ACTION
}

_String4GUID(pGUID)
{
	VarSetCapacity(String,38*2)
	DllCall("ole32\StringFromGUID2", "ptr", pGUID, "str", String, "int", 39)
	Return	String
}


/*  Utility Functions
 */

getWindow() {
    global wb
    return wb.document.parentWindow
}

ErrorExit(errMsg) {
    global
    if SilentMode
        ExitApp 1
    MsgBox 16, AutoHotkey 安装, %errMsg%
    Exit
}

CloseScriptsEtc(installdir, actionToContinue) {
    titles := ""
    DetectHiddenWindows On
    close := []
    WinGet w, List, ahk_class AutoHotkey
    Loop % w {
        ; Exclude the install script.
        if (w%A_Index% = A_ScriptHwnd)
            continue
        ; Determine if the script actually needs to be terminated.
        WinGet exe, ProcessPath, % "ahk_id " w%A_Index%
        if (exe != "") {
            ; Exclude external executables.
            if InStr(exe, installdir "\") != 1
                continue
            ; The main purpose of this next check is to avoid closing
            ; SciTE4AutoHotkey's toolbar, but also may be helpful for
            ; other situations.
            exe := SubStr(exe, StrLen(installdir) + 2)
            if !RegExMatch(exe, "i)^(AutoHotkey(A32|U32|U64)?\.exe|Compiler\\Ahk2Exe.exe)$")
                continue
        }        
        ; Append script path to the list.
        WinGetTitle title, % "ahk_id " w%A_Index%
        title := RegExReplace(title, " - AutoHotkey v.*")
        titles .= "  -  " title "`n"
        close.Insert(w%A_Index%)
    }
    if (titles != "") {
        global SilentMode
        if !SilentMode {
            MsgBox 49, AutoHotkey 安装,
            (LTrim
            安装程序需要关闭以下脚本(s):
            `n%titles%
            点击“确定”以关闭这些脚本，并继续 %actionToContinue%.
            )
            IfMsgBox Cancel
                Exit
        }
        ; Close script windows (typically causing them to exit).
        Loop % close.MaxIndex()
            WinClose % "ahk_id " close[A_Index]
    }
    ; Close all help file and Window Spy windows automatically:
    GroupAdd autoclosegroup, AutoHotkey_L Help ahk_class HH Parent
    GroupAdd autoclosegroup, AutoHotkey Help ahk_class HH Parent
    GroupAdd autoclosegroup, Active Window Info ahk_exe %installdir%\AU3_Spy.exe
    ; Also close the old Ahk2Exe (but the new one is a script, so it
    ; was already handled by the section above):
    GroupAdd autoclosegroup, Ahk2Exe v ahk_exe %installdir%\Compiler\Ahk2Exe.exe
    WinClose ahk_group autoclosegroup
}

GetErrorMessage(error_code="") {
    VarSetCapacity(buf, 1024) ; Probably won't exceed 1024 chars.
    if DllCall("FormatMessage", "uint", 0x1200, "ptr", 0, "int", error_code!=""
                ? error_code : A_LastError, "uint", 1024, "str", buf, "uint", 1024, "ptr", 0)
        return buf
}

switchPage(page) {
    global
    if !SilentMode
        getWindow().switchPage(page)
}

UpdateStatus(status) {
    ; if !SilentMode
        ; getWindow().install_status.innerText := status
}

ShellRun(prms*)
{
    shellWindows := ComObjCreate("{9BA05972-F6A8-11CF-A442-00A0C90A8F39}")
    
    desktop := shellWindows.Item(ComObj(19, 8)) ; VT_UI4, SCW_DESKTOP                
   
    ; Retrieve top-level browser object.
    if ptlb := ComObjQuery(desktop
        , "{4C96BE40-915C-11CF-99D3-00AA004AE837}"  ; SID_STopLevelBrowser
        , "{000214E2-0000-0000-C000-000000000046}") ; IID_IShellBrowser
    {
        ; IShellBrowser.QueryActiveShellView -> IShellView
        if DllCall(NumGet(NumGet(ptlb+0)+15*A_PtrSize), "ptr", ptlb, "ptr*", psv:=0) = 0
        {
            ; Define IID_IDispatch.
            VarSetCapacity(IID_IDispatch, 16)
            NumPut(0x46000000000000C0, NumPut(0x20400, IID_IDispatch, "int64"), "int64")
           
            ; IShellView.GetItemObject -> IDispatch (object which implements IShellFolderViewDual)
            DllCall(NumGet(NumGet(psv+0)+15*A_PtrSize), "ptr", psv
                , "uint", 0, "ptr", &IID_IDispatch, "ptr*", pdisp:=0)
           
            ; Get Shell object.
            shell := ComObj(9,pdisp,1).Application
           
            ; IShellDispatch2.ShellExecute
            shell.ShellExecute(prms*)
           
            ObjRelease(psv)
        }
        ObjRelease(ptlb)
    }
}

Run_(target, args="") {
    try
        ShellRun(target, args)
    catch e
        Run % args="" ? target : target " " args
}


/*  由UI调用效用函数
 */

Customize() {
    getWindow().switchPage("custom-install")
}

SelectFolder(id, prompt="", root="::{20d04fe0-3aea-1069-a2d8-08002b30309d}") {
    global wb
    if !(field := wb.document.getElementById(id))
        return
    Gui +OwnDialogs
    FileSelectFolder path
        , % root " *" field.value
        ,, % prompt
    if !ErrorLevel
        field.value := path
}

ReadLicense() {
    Run_(A_ScriptDir "\license.txt")
}

ViewHelp(topic) {
    local path
    if FileExist("AutoHotkey.chm")
        path := A_WorkingDir "\AutoHotkey.chm"
    else
        path := CurrentPath "\AutoHotkey.chm"
    if FileExist(path)
        Run_("hh.exe", "mk:@MSITStore:" path "::" topic)
    else
        Run_("http://l.autohotkey.net" topic)
}

RunAutoHotkey() {
    ; Setup may be running as a user other than the one that's logged
    ; in (i.e. an admin user), so in addition to running AutoHotkey.exe
    ; in user mode, have it call the function below to ensure the script
    ; file is correctly located.
    Run_("AutoHotkey.exe", """" A_WorkingDir "\Installer.ahk"" /runahk")
}
RunAutoHotkey_() {
    ; This could detect %ExeDir%\AutoHotkey.ahk (which takes precedence
    ; over %A_MyDocuments%\AutoHotkey.ahk), but that file is unlikely to
    ; exist in this situation.
    script_path := A_MyDocuments "\AutoHotkey.ahk"
    ; Start the script.
    Run AutoHotkey.exe,,, pid
    ; Check for common failures.
    SetTitleMatchMode 2
    DetectHiddenWindows On
    message := ""
    message_flags := 0x34
    Loop {
        Sleep 50
        Process Exist, %pid%
        if !ErrorLevel {
            message =
            (LTrim Join`s
            AutoHotkey 已经退出。  您可能需要修改你的启动
            脚本。  例如，如果它退出，因为这样做它没有任何
            关系，你可以添加一个热键。
            )
            message_flags := 0x44 ; Less severe, since it might be intentional.
            break
        }
        if WinExist("ahk_class #32770 ahk_pid " pid) {
            WinGetText message
            if !InStr(message, "Error")
                return
            WinWaitClose
            Process Exist, %pid%
            message := "你的脚本遇到错误" (ErrorLevel ? "." : " and exited.")
                   . "  您将需要编辑来解决这个错误。"
            break
        }
        if WinExist("ahk_class AutoHotkey ahk_pid " pid) {
            WinWaitClose,,, .2 ; 稍等片刻情况下，脚本是空/退出。
            if !ErrorLevel
                continue ; 回到循环的顶部。
            DetectHiddenWindows Off
            if !WinExist("ahk_pid " pid)
                MsgBox 0x40, AutoHotkey 安装, 你的脚本在后台运行。
            return
        }
    }
    MsgBox % message_flags, AutoHotkey 安装, %message%`n`n你的脚本就在这里：`n   %script_path%`n`n你要编辑这个文件？
    IfMsgBox Yes
        Run edit "%script_path%"
}

Quit() {
    ExitApp
}

Extract(dstDir="") {
    if (dstDir = "") {
        FileSelectFolder dstDir,,, 选择一个文件夹，复制程序文件。
        if ErrorLevel
            return
    }
    try {
        global TestMode, SourceDir
        if (TestMode = "FailExtract")
            throw
        shell := ComObjCreate("Shell.Application")
        try FileCreateDir %dstDir%
        dst := shell.NameSpace(dstDir)
        src := shell.NameSpace(SourceDir)
        if !(dst && src)
            throw
        try dst.CopyHere(src.Items, 256)
    }
    catch {
        FileCopyDir %SourceDir%, %dstDir%, 1
        if ErrorLevel {
            MsgBox 48, AutoHotkey 安装, 发生不明错误。
            return
        }
    }
    Run %dstDir%
}

Download() {
    Run http://l.autohotkey.net/AutoHotkey_L_Install.exe
    ExitApp
}


/*  动作设置
 */

; 升级到新版本，或从AutoHotkey的AutoHotkey_L的。
;   类型: "ANSI" 或 "Unicode"
Upgrade(Type="") {
    global
    _Install({
    (Join C
        type: Type,
        path: DefaultPath,
        menu: DefaultStartMenu,
        ahk2exe: DefaultCompiler,
        dragdrop: DefaultDragDrop,
        utf8: DefaultToUTF8,
        isHostApp: DefaultIsHostApp
    )})
}

; 快速安装的默认选项。
QuickInstall() {
    global
    _Install({
    (Join
        type: DefaultType,
        path: DefaultPath,
        menu: DefaultStartMenu,
        ahk2exe: DefaultCompiler,
        dragdrop: DefaultDragDrop,
        utf8: DefaultToUTF8,
        isHostApp: DefaultIsHostApp
    )})
}

; 开始审查后选择安装。
CustomInstall() {
    local w := getWindow()
    _Install({
    (C Join
        type: w.installtype.value,
        path: w.installdir.value,
        menu: w.startmenu.value,
        ahk2exe: w.installcompiler.checked,
        dragdrop: w.enabledragdrop.checked,
        utf8: DefaultToUTF8, ;w.defaulttoutf8.checked
        isHostApp: w.separatebuttons.checked
    )})
}

; 卸载。
Uninstall() {
    global
    
    try
        SetWorkingDir % CurrentPath
    catch
        ErrorExit("卸载安装目录错误 '" CurrentPath "' 可能是无效的。")
    
    CloseScriptsEtc(CurrentPath, "卸载")
    
    switchPage("wait")
    
    /*  注册处
     */
    
    SetRegView % CurrentRegView
    
    RegDelete HKLM, %UninstallKey%
    RegDelete HKLM, %AutoHotkeyKey%
    RegDelete HKCU, %AutoHotkeyKey%  ; 创建者 Ahk2Exe.
    
    RegDelete HKCR, .ahk
    RegDelete HKCR, %FileTypeKey%
    RegDelete HKCR, Applications\AutoHotkey.exe
    
    RegDelete HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoHotkey.exe
    
    /*  档
     */
    
    FileDelete AutoHotkeyU32.exe
    FileDelete AutoHotkeyA32.exe
    FileDelete AutoHotkeyU64.exe
    
    FileDelete AU3_Spy.exe
    FileDelete AutoHotkey.chm
    FileDelete license.txt
    
    ; 这个文件只存在一个旧版本的AutoHotkey_L的
    ; 安装它:
    FileDelete Update.ahk
    
    ; 虽然旧的安装设计不覆盖此
    ; 情况下，用户自定义，旧的卸载删除它：
    FileDelete %A_WinDir%\ShellNew\Template.ahk
    
    RemoveCompiler()
    
    FileDelete %ProductName% Website.url
    if (CurrentStartMenu != "")  ; 必须不删除A_ProgramsCommon本身！
        FileRemoveDir %A_ProgramsCommon%\%CurrentStartMenu%, 1
    
    if !SilentMode
        MsgBox 64, AutoHotkey 安装
            , 安装程序将立即关闭以完成卸载。
    
    ; 尝试删除它通常首先，脚本运行的情况下，这
    ; 在外部exe (如通过下载安装).
    FileDelete AutoHotkey.exe
    if !ErrorLevel {
        FileDelete Installer.ahk
        SetWorkingDir %A_Temp%  ; 否则将失败FileRemoveDir。
        FileRemoveDir %CurrentPath%  ; 只有当空。
        ExitApp
    }
    
    Gui Cancel
    
    ; 使用cmd.exe的解决被锁定的事实AutoHotkey.exe
    ; 而它仍然运行。有脚本的第二个实例
    ; 终止这种情况下，应该进行更可靠的比
    ; 任意的等待（例如，通过调用“平”）。
    Run %ComSpec% /c "
    (Join`s&`s
    AutoHotkey.exe "%A_ScriptFullPath%" /kill %A_ScriptHwnd%
    del Installer.ahk
    del AutoHotkey.exe
    cd %A_Temp%
    rmdir "%CurrentPath%"
    )",, Hide
}


/*  安装
 */

_Install(opt) {
    global
    
    /*  Validation
     */
    
    local exefile, binfile
    if opt.type = "Unicode" {
        exefile := "AutoHotkeyU32.exe"
        binfile := "Unicode 32-bit.bin"
    } else if opt.type = "x64" && A_Is64bitOS {
        exefile := "AutoHotkeyU64.exe"
        binfile := "Unicode 64-bit.bin"
    } else if opt.type = "ANSI" {
        exefile := "AutoHotkeyA32.exe"
        binfile := "ANSI 32-bit.bin"
    } else
        ErrorExit("安装类型无效 '" opt.type "'")
    
    if !InStr(FileExist(opt.path), "D")
        try
            FileCreateDir % opt.path
        catch
            ErrorExit("无法创建安装目录 ('" opt.path "')")
    
    CloseScriptsEtc(CurrentPath, "安装")
    
    /*  Preparation
     */
    
    SetWorkingDir % opt.path
    
    switchPage("wait")
    
    ; Remove old files which are no longer relevant.
    if (CurrentName = "AutoHotkey") {
        FileDelete Compiler\README.txt
        FileDelete Compiler\upx.exe
    }
    FileDelete uninst.exe
    
    if A_Is64bitOS {
        ; For xx-bit installs, write to the xx-bit view of the registry.
        local regView := (opt.type = "x64") ? 64 : 32
        if (CurrentRegView && CurrentRegView != regView) {
            ; Clean up old keys in the other registry view.
            SetRegView % CurrentRegView
            RegDelete HKLM, %UninstallKey%
            RegDelete HKLM, %AutoHotkeyKey%
            RegDelete HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoHotkey.exe
            RegDelete HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe
        }
        SetRegView % regView
    }
    
    /*  Install Files
     */
    
    UpdateStatus("Copying files")
    
    ; If the following is "true", we have no source files to install,
    ; but we may have settings to change.  This includes replacing the
    ; binary files with %exefile% and %binfile%.
    installInPlace := (A_WorkingDir = A_ScriptDir)
    
    ; Install all unique files.
    if !installInPlace {
        InstallMainFiles()
        if opt.ahk2exe
            InstallCompilerFiles()
    }
    
    ; If the user deselected Ahk2Exe and it was previously installed,
    ; ensure it is removed.
    if !opt.ahk2exe
        RemoveCompiler()
    
    ; Create the "default" binaries, corresponding to whichever version
    ; the user selected.
    if !installInPlace
        InstallFile(exefile, "AutoHotkey.exe")
    ;else: a workaround is needed later.
    if opt.ahk2exe
        InstallFile("Compiler\" binfile, "Compiler\AutoHotkeySC.bin")
    
    /*  Start Menu Shortcuts
     */
    
    if CurrentStartMenu
        FileRemoveDir %A_ProgramsCommon%\%CurrentStartMenu%, 1
    
    if opt.menu {
        UpdateStatus("Creating shortcuts")
        local smpath := A_ProgramsCommon "\" opt.menu
        FileCreateDir %smpath%
        FileCreateShortcut %A_WorkingDir%\AutoHotkey.exe, %smpath%\AutoHotkey.lnk
        FileCreateShortcut %A_WorkingDir%\AU3_Spy.exe, %smpath%\AutoIt3 Window Spy.lnk
        FileCreateShortcut %A_WorkingDir%\AutoHotkey.chm, %smpath%\AutoHotkey Help File.lnk
        IniWrite %ProductWebsite%, %ProductName% Website.url, InternetShortcut, URL
        FileCreateShortcut %A_WorkingDir%\%ProductName% Website.url, %smpath%\Website.lnk
        FileCreateShortcut %A_WorkingDir%\Installer.ahk, %smpath%\AutoHotkey Setup.lnk
            ,,,, %A_WinDir%\System32\appwiz.cpl,, -1499
        if opt.ahk2exe
            FileCreateShortcut %A_WorkingDir%\Compiler\Ahk2Exe.exe
                , %smpath%\Convert .ahk to .exe.lnk
    }
    
    /*  Registry
     */
    
    UpdateStatus("Configuring registry")
    
    RegWrite REG_SZ, HKLM, %AutoHotkeyKey%, InstallDir, %A_WorkingDir%
    RegWrite REG_SZ, HKLM, %AutoHotkeyKey%, Version, %ProductVersion%
    if opt.menu
        RegWrite REG_SZ, HKLM, %AutoHotkeyKey%, StartMenuFolder, % opt.menu
    else
        RegDelete HKLM, %AutoHotkeyKey%, StartMenuFolder
    
    ; Might need to get rid of this to allow the ShellNew template to work:
    RegDelete HKCR, ahk_auto_file
    RegWrite REG_SZ, HKCR, .ahk,, %FileTypeKey%
    RegWrite REG_SZ, HKCR, .ahk\ShellNew, FileName, Template.ahk
    
    RegWrite REG_SZ, HKCR, %FileTypeKey%,, AutoHotkey Script
    RegWrite REG_SZ, HKCR, %FileTypeKey%\DefaultIcon,, %A_WorkingDir%\AutoHotkey.exe`,1
    
    ; Set up system verbs:
    RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Open,, Run Script
    RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Edit,, Edit Script
    if opt.ahk2exe
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Compile,, Compile Script
    
    local value
    
    ; Set default action, but don't overwrite.
    try
        RegRead value, HKCR, %FileTypeKey%\Shell,
    catch   ; Key likely doesn't exist.
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell,, Open
    
    ; Set editor, but don't overwrite.
    try
        RegRead value, HKCR, %FileTypeKey%\Shell\Edit\Command,
    catch
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Edit\Command,, notepad.exe `%1
    
    if opt.ahk2exe
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Compile\Command,, "%A_WorkingDir%\Compiler\Ahk2Exe.exe" /in "`%l"
    
    local cmd
    cmd = "%A_WorkingDir%\AutoHotkey.exe"
    if opt.utf8
        cmd = %cmd% /CP65001
    cmd = %cmd% "`%1" `%*
    RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Open\Command,, %cmd%
    
    ; If UAC is enabled, add a "Run as administrator" option.
    RegRead value, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System, EnableLUA
    if value
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\RunAs\Command,, "%A_WorkingDir%\AutoHotkey.exe" "`%1" `%*
    
    if opt.dragdrop
        RegWrite REG_SZ, HKCR, %FileTypeKey%\ShellEx\DropHandler,, {86C86720-42A0-1069-A2E8-08002B30309D}
    else
        RegDelete HKCR, %FileTypeKey%\ShellEx
    
    RegWrite REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoHotkey.exe,, %A_WorkingDir%\AutoHotkey.exe
    if opt.ahk2exe
        RegWrite REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe,, %A_WorkingDir%\Compiler\Ahk2Exe.exe
    
    RegDelete HKCR, Applications\AutoHotkey.exe
    if opt.isHostApp
        RegWrite REG_SZ, HKCR, Applications\AutoHotkey.exe, IsHostApp
    
    ; Write uninstaller info.
    RegWrite REG_SZ, HKLM, %UninstallKey%, DisplayName, %ProductName% %ProductVersion%
    RegWrite REG_SZ, HKLM, %UninstallKey%, UninstallString, "%A_WorkingDir%\AutoHotkey.exe" "%A_WorkingDir%\Installer.ahk"
    RegWrite REG_SZ, HKLM, %UninstallKey%, DisplayIcon, %A_WorkingDir%\AutoHotkey.exe
    RegWrite REG_SZ, HKLM, %UninstallKey%, DisplayVersion, %ProductVersion%
    RegWrite REG_SZ, HKLM, %UninstallKey%, URLInfoAbout, %ProductWebsite%
    RegWrite REG_SZ, HKLM, %UninstallKey%, Publisher, %ProductPublisher%
    RegWrite REG_SZ, HKLM, %UninstallKey%, NoModify, 1
    
    ; Notify other programs (e.g. explorer.exe) that file type associations have changed.
    ; This may be necessary to update the icon when upgrading from an older version of AHK.
    DllCall("shell32\SHChangeNotify", "uint", 0x08000000, "uint", 0, "int", 0, "int", 0) ; SHCNE_ASSOCCHANGED
    
    if installInPlace {
        ; As AutoHotkey.exe is probably in use by this script, the final
        ; step will be completed by another instance of this script:
        Run AutoHotkeyU32.exe "%A_ScriptFullPath%" /fin %exefile% %A_ScriptHwnd% %SilentMode%
        ExitApp
    }
    
    switchPage("done")
}

InstallFile(file, target="") {
    global
    if (target = "")
        target := file
    Loop { ; Retry loop.
        try {
            FileCopy %SourceDir%\%file%, %target%, 1
            ; If successful (no exception thrown):
            return
        }
        if SilentMode {
            SilentErrors += 1
            return  ; Continue anyway.
        }
        local error_message := RTrim(GetErrorMessage(), "`r`n")
        MsgBox 0x12, AutoHotkey 安装,
        (LTrim
        安装文件时出错 "%target%"
        
        特别是: %error_message%
        
        单击“中止”停止安装，
        重试，或
        忽略此文件跳过。
        )
        IfMsgBox Abort
            ExitApp
        IfMsgBox Ignore
            return
    }
}

InstallMainFiles() {
    InstallFile("AutoHotkeyU32.exe")
    InstallFile("AutoHotkeyA32.exe")
    if A_Is64bitOS
        InstallFile("AutoHotkeyU64.exe")
    
    InstallFile("AU3_Spy.exe")
    InstallFile("AutoHotkey.chm")
    InstallFile("license.txt")
    
    InstallFile("Installer.ahk")
    
    if !FileExist(A_WinDir "\ShellNew\Template.ahk") {
        FileCreateDir %A_WinDir%\ShellNew
        InstallFile("Template.ahk", A_WinDir "\ShellNew\Template.ahk")
    }
}

InstallCompilerFiles() {
    FileCreateDir Compiler
    InstallFile("Compiler\Ahk2Exe.exe")
    InstallFile("Compiler\ANSI 32-bit.bin")
    InstallFile("Compiler\Unicode 32-bit.bin")
    ; Install the following file even if !isOS64bit() to support
    ; compiling scripts for 64-bit systems on 32-bit systems:
    InstallFile("Compiler\Unicode 64-bit.bin")
}

RemoveCompiler() {
    global
    FileDelete Compiler\Ahk2Exe.exe
    FileDelete Compiler\ANSI 32-bit.bin
    FileDelete Compiler\Unicode 32-bit.bin
    FileDelete Compiler\Unicode 64-bit.bin
    FileDelete Compiler\AutoHotkeySC.bin
    FileRemoveDir Compiler  ; Only if empty.    
    RegDelete HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe
}

DefineUI:
html=
(%`
<html><head>
<style type="text/css">
body {
	background-color: ButtonFace;
	font-family: "Arial", sans-serif;
	font-size: 15px;
	overflow: hidden;
	cursor: default;
	padding: 0;
	margin: 0;
}
h1 {
	font-size: 37px;
	font-weight: normal;
	color: #405871;
	background-color: white;
	padding: 15px 25px;
	margin: 0 -15px;
}
p {
	margin-top: 15px;
}
a:link, a:visited {
	color: #0066CC;
}
.options {
	margin: 0 3em 0 2em;
}
.options a {
	display: block;
	padding: 0.8em 1em;
	margin: 0.3em 0;
	position: relative;
	width: 100%;
}
.marker {
	position: absolute;
	right: 10px;
	font-size: 25px;
	top: 50%;
	margin-top: -17px;
}
a.button,
.options a {
	cursor: hand;
	border: 1px solid ButtonShadow;
	background-color: white;
	text-decoration: none;
}
a.button {
	padding: .3em .5em;
}
a.button,
a.button:visited,
.options a,
.options a:visited {
	color: #405871;
}
a.button:hover,
a.button:active,
.options a:hover,
.options a:active {
	background-color: #F8F8FF;
	border-color: #4774B2;
	color: #4774B2;
}
.options a:active {
	left: 3px;
}
.options p {
	font-size: 80%;
	margin: 0.2em 1em;
}
#license, #extract {
	position: absolute;
	bottom: 1em;
	font-size: 80%;
}
#extract {
    right: 1em;
}
.page {
	width: 100%;
	height: 100%;
	padding: 0 15px;
	display: none; /* overridden by script */
	color: ButtonText;
}
.pager .page {
	padding: 15px 0;
}
.nav {
	background-color: #405871;
	color: white;
	margin: 0 -15px;
	padding: 3px 20px;
	height: 24px;
}
.nav a, .nav a:visited {
	color: #ddd;
	text-decoration: none;
	padding: 0;
}
.nav a:hover {
	color: white;
}
.nav .current {
	color: white;
	font-weight: bold;
	cursor: default;
}
.warning {
	display: none;
	background-color: #fee;
	color: #800;
	border: 1px solid #800;
	padding: 0.5em;
	margin: -0.5em 0 1em;
}
.textbox {
	border: 1px solid ButtonShadow;
	padding: 0 0.4em;
	height: 29px;
	line-height: 27px;
	vertical-align: top;
	margin-top: 9px;
}
#installdir, #startmenu {
	width: 70%;
}
#installdir_browse, #startmenu_del {
	height: 28px;
	margin-top: 10px;
}
label {
	padding: 5px;
	display: block;
	width: 90%;
}
label.indent {
	padding-left: 30px;
}
label p {
	font-size: 85%;
	margin: .3em 25px;
	color: #405871;
}
#install_button, #next-button {
	position: absolute;
	bottom: 15px;
	right: 15px;
	width: 5em;
	font-size: 125%;
	text-align: center;
}
#installcompilernote {
	display: none;
	font-weight: bold;
}
</style>
<script type="text/javascript">
function forEach(arr, fn) {
	var i;
	for (i = 0; i < arr.length; ++i)
		fn.apply(arr[i]);
}
function onload() {
	ci_nav_list.length = 0;
	forEach (ci_nav.getElementsByTagName("a"), function() {
		this.tabIndex = 1000;
		if (this.hash != "") {
			var list = this.parentNode == ci_nav_list ? ci_nav_list : null;
			if (list)
				list[list.length++] = this;
			this.onclick = function() {
				if (list) {
					forEach (list.getElementsByTagName("a"), function() {
						this.className = "";
					})
					this.className = "current";
				}
				event.returnValue = switchPage(this.hash.substr(1));
			}
		}
	})
}
function initOptions(curName, curVer, curType, newVer, instDir, smFolder, defType, is64) {
	if (onload) onload(), onload = null;
	var opt;
	var warn;
	var types = {Unicode: "Unicode 32-bit", ANSI: "ANSI 32-bit", x64: "Unicode 64-bit"};
	var curTypeName = types[curType];
	var defTypeName = types[defType];
	curTypeName = curTypeName ? " (" + curTypeName + ")" : "";
	if (curName == "AutoHotkey" && curVer <= "1.0.48.05") {
		start_intro.innerText = curName + " v" + curVer + " 安装位置。你想要做什么？";
		var uniType = is64 ? "x64" : "Unicode";
		var uniTypeName = types[uniType];
		opt = [
			"ahk://Upgrade/ANSI", "升级到 v" + newVer + " (" + types.ANSI + ")", "兼容性推荐",
			"ahk://Upgrade/" + uniType, "升级到 v" + newVer + " (" + uniTypeName + ")", "",
			"ahk://Customize/", "自定义安装", ""
		];
		warn = '<strong>Note:</strong> Some AutoHotkey 1.0 scripts are <a href="ahk://ViewHelp//docs/Compat.htm">not compatible</a> with AutoHotkey 1.1.';
	} else if (curName == "") {
		start_intro.innerText = "请选择您要执行的安装类型。";
		opt = [
			"ahk://QuickInstall/", "快速安装", "默认版本：" + defTypeName + "<br>安装：" + instDir,
			"ahk://Customize/", "自定义安装", ""
		];
	} else if (curVer != newVer) {
		start_intro.innerText = curName + " v" + curVer + curTypeName + " 安装位置。你想要做什么？";
		opt = [
			"ahk://Upgrade/" + defType, (curVer < newVer ? "升级" : "Downgrade") + " 至 v" + newVer + " (" + defTypeName + ")", "",
			"ahk://Customize/", "自定义安装", ""
		];
	} else {
		start_intro.innerText = curName + " v" + curVer + curTypeName + " 安装位置。你想要做什么？";
		opt = [
			"ahk://QuickInstall/", "修复", "",
			"ahk://Customize/", "修改", "",
			"ahk://Uninstall/", "卸载", ""
		];
	}
	var i, html = [];
	for (i = 0; i < opt.length; i += 3) {
		html.push('<a href="', opt[i], '" id="opt', Math.floor(i/3)+1, '"><span>', opt[i+1], '</span>');
		if (opt[i+2])
			html.push('<p>', opt[i+2], '</p>');
		if (opt[i] == 'ahk://Customize/')
			html.push('<div class="marker">\u00BB</div>');
		html.push('</a>');
	}
	start_options.innerHTML = html.join("");
	start_warning.innerHTML = warn;
	start_warning.style.display = warn ? "block" : "none";
	start_nav.innerHTML = '<em style="text-align:right;width:100%">version ' + newVer + '</em>';
	installtype.value = defType;
	installdir.value = instDir;
	startmenu.value = smFolder;
	startmenu.onblur();
	forEach (document.getElementsByTagName("a"), function() {
		if (/*this.className == "button" ||*/ this.parentNode.className == "options")
			this.hideFocus = true;
	})
}
document.onselectstart =
document.oncontextmenu =
document.ondragstart =
	function() {
		return window.event && event.srcElement.tagName == "INPUT" || false;
	};
function setInstallType(type) {
	installtype.value = type;
	ci_nav_list[1].click();
	event.returnValue = false;
}
function switchPage(page) {
	page = document.getElementById(page);
	if (page.id == "start")
		ci_nav_list[0].click();
	for (var n = page.parentNode.firstChild; n; n = n.nextSibling) if (n.className == "page") {
		if (n != page)
			n.style.display = "none";
		else
			n.style.display = "block";
	}
	var f;
	switch (page.id) {
	case "custom-install":
	case "ci_version":  f = "it_" + installtype.value; break;
	case "ci_location": f = "next-button"; break;
	case "ci_options":  f = "install_button"; break;
	case "done":        f = "done_exit"; break;
	}
	if (f) {
		// If page == ci_version, it mightn't actually be visible at this point,
		// which causes IE7 (and perhaps older) to throw error 0x80020101.
		try { document.getElementById(f).focus() } catch (ex) { }
	}
	return false;
}
function beforeCustomInstall() {
	if (startmenu.style.color == '#888')
		startmenu.value = '';
}</script>
</head><body>

<div class="page" id="start">
	<h1>AutoHotkey 安装</h1>
	<div class="nav" id="start_nav">&nbsp;</div>
	<p id="start_intro"></p>
	<div class="warning" id="start_warning"></div>
	<div class="options" id="start_options"></div>
	<div id="license">AutoHotkey是开源软件： <a href="ahk://ReadLicense/">读取许可证</a></div>
  <div id="extract"><a href="ahk://Extract/" title="Save program files without installing.">解压到...</a></div>
</div>

<div class="page" id="custom-install">
	<h1>AutoHotkey 安装</h1>
	<div class="nav" id="ci_nav">
		<a href="#start">开始</a> &#187;
		<span id="ci_nav_list">
			<a href="#ci_version">版本</a> &#187;
			<a href="#ci_location">位置</a> &#187;
			<a href="#ci_options">选项</a> &#187;
		</span>
		<a id="ci_nav_install" href="ahk://CustomInstall/" onclick="beforeCustomInstall()">安装</a>
	</div>
	<div class="pager" id="ci_pager">
		<div class="page" id="ci_version">
			<p>默认情况下，应该运行哪个版本的AutoHotkey.exe？</p>
			<input type="hidden" id="installtype">
			<div class="options">
				<a href="#" id="it_Unicode" onclick="setInstallType('Unicode')" tabindex="1">Unicode 32-bit
					<p>推荐新安装/脚本.</p> <div class="marker">&#187;</div></a>
				<a href="#" id="it_x64" onclick="setInstallType('x64')" tabindex="2">Unicode 64-bit
					<p>更快, 但是编译的脚本将不能运行在 32-bit 系统.</p> <div class="marker">&#187;</div></a>
				<a href="#" id="it_ANSI" onclick="setInstallType('ANSI')" tabindex="3">ANSI 32-bit
					<p>一些传统脚本的兼容性更好。</p> <div class="marker">&#187;</div></a>
			</div>
		</div>
		<div class="page" id="ci_location">
			<label for="installdir" class="indent">安装位置：<br>
			<input type="text" class="textbox" id="installdir" value="C:\Program Files\AutoHotkey" tabindex="11"> <a href="ahk://SelectFolder/installdir,Select the folder to install AutoHotkey in." id="installdir_browse" class="button" tabindex="12">浏览</a></label><br>
			<label for="startmenu" class="indent"> 在“开始菜单”中创建的快捷方式:<br>
			<input type="text" class="textbox" id="startmenu" value="AutoHotkey" tabindex="13"
				onfocus="if (style.color == '#888') value='', style.color = '';"
				onblur="if (value == '') value = '(don\'t create shortcuts)', style.color = '#888';">
			<a href="#" id="startmenu_del" class="button" style="color:red" tabindex="14"
				onclick = "startmenu.value=''; startmenu.onblur(); return false;">X</a>
			</label><br>
			<a href="#" id="next-button" class="button" onclick="ci_nav_list[2].click(); return false;" tabindex="15">下一步</a>
		</div>
		<div class="page" id="ci_options">
			<label for="installcompiler"><input type="checkbox" id="installcompiler" checked="checked"> 安装脚本编译器
				<p>安装 Ahk2Exe, 编译工具，将任何 .ahk 脚本 编译成一个独立的 EXE。<br>
				还添加了一个 "编译" 选项 至 .ahk 上下文菜单。</p>
				<p id="installcompilernote">下载并重新运行安装程序重新安装 Ahk2Exe。</p></label>
			<label for="enabledragdrop"><input type="checkbox" id="enabledragdrop" checked="checked"> 启用拖放 &amp; drop
				<p>拖放文件到 .ahk 脚本将启动该脚本 (文件将被作为参数传递)。这可能会导致意外启动，所以有些用户可能希望禁用它。</p></label>
			<label for="separatebuttons"><input type="checkbox" id="separatebuttons"> 独立的任务栏按钮
				<p>使每个脚本的可见窗口被视为一个单独的程序，但可以用固定到任务栏阻止 AutoHotkey.exe。</p></label>
			<a href="ahk://CustomInstall/" onclick="beforeCustomInstall()" id="install_button" class="button">安装</a>
		</div>
	</div>
</div>

<div class="page" id="wait">
	<h1>AutoHotkey 安装</h1>
	<div class="nav">&nbsp;</div>
	<p style="color: #999; font-size: 120%; text-align: center; margin-top: 5em">这应该用不了多长时间...</p>
	<p style="text-align: center" id="install_status"></p>
</div>

<div class="page" id="done">
	<h1>AutoHotkey 安装</h1>
	<div class="nav">&nbsp;</div>
	<p>安装完成。</p>
	<div class="options">
		<a href="ahk://ViewHelp//docs/AHKL_ChangeLog.htm">查看变更 &amp; 新特点</a>
		<a href="ahk://ViewHelp//docs/Tutorial.htm">查看教程</a>
		<a href="ahk://RunAutoHotkey/">运行 AutoHotkey</a>
		<a href="ahk://Quit/" id="done_exit">退出</a>
	</div>
</div>

</body></html>
)
return