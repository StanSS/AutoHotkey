/*
版本: 1.7
操作系统:    WinXP
原作者:        甲壳虫<jdchenjian@gmail.com>
甲壳虫博客:        http://hi.baidu.com/jdchenjian


[说明]
脚本描述＝此工具用来修改 AutoHotkey 脚本的右键菜单关联，适用于 AutoHotkey 安装版、绿色版。
LastChangedRevision = 7
LastChangedDate = 2013-3-17
*/
#Persistent
#NoEnv
#SingleInstance, force
SendMode Input
SetWorkingDir %A_ScriptDir%

IniRead LastChangedRevision, %A_ScriptFullPath%,  说明, LastChangedRevision, %A_Space%
IniRead LastChangedDate, %A_ScriptFullPath%,  说明, LastChangedDate, %A_Space%

ScriptName = ScriptSetting 1.0.%LastChangedRevision% (%LastChangedDate%)

Change_History=
(
修改历史：
sunwind2013-3-17修改一处错误Template_Path 
sunwind2013-2-24增加CLSID and APPID v1.0.6
sunwind2013-1-8 修改完善 v1.0.5
1.增加shellnew路径
2.增加自身配置读取（需要本脚本的编码为ANSI或UTF-16 LE）
sunwind2012-12-11修改完善 v1.0.4


使用方法：把本脚本放到AutoHotkey.exe目录中,拖动本脚本到AutoHotkey.exe上。
1.将右键菜单中的，编辑代码 编译代码 改为英文
2.使右键菜单支持热键
3.增加默认编辑器为%A_ScriptDir%\SciTE\SciTE.exe
4.增加ahk脚本拖放支持，就是可以将文件拖放到ahk脚本上。
)

; CLSID and APPID for this script: don't reuse, please!
CLSID_SciTE4AHK := "{D7334085-22FB-416E-B398-B5038A5A0784}"
APPID_SciTE4AHK := "SciTE4AHK.Application"

; AutoHotkey 原版的相关信息写在注册表HKCR主键中，
; 尝试是当前用户否有权操作该键，如果无权操作HKCR键（受限用户），
IsLimitedUser:=0
RegWrite, REG_SZ, HKCR, .test
If ErrorLevel
	IsLimitedUser:=1
RegDelete, HKCR, .test
If ErrorLevel
	IsLimitedUser:=1

If IsLimitedUser=0 ; 非受限用户操作HKCR键
{
	RootKey=HKCR
	Subkey=
	;~ MsgBox HKCR
}
Else ; 受限用户操作HKCU键
{
	RootKey=HKCU
	Subkey=Software\Classes\ ; <-- 为简化后面的脚本，此子键须以“\”结尾
	;~ MsgBox hkcu
}

; 检查是否存在AHK注册表项
RegRead, FileType, %RootKey%, %Subkey%.ahk
If FileType<>
{
	RegRead, value, %RootKey%, %Subkey%%FileType%\Shell\Open\Command ;AHK路径
	AHK_Path:=PathGetPath(value)
	RegRead, value, %RootKey%, %Subkey%%FileType%\Shell\Edit\Command ;编辑器路径
	Editor_Path:=PathGetPath(value)
	RegRead, value, %RootKey%, %Subkey%%FileType%\Shell\Compile\Command ;编译器路径
	Compiler_Path:=PathGetPath(value)
	RegRead, Template_Path, %RootKey%, %Subkey%.ahk\ShellNew, FileName ;模板文件名

}
Else
	FileType=AutoHotkeyScript

If AHK_Path=
{
	IfExist, %A_ScriptDir%\AutoHotkey.exe
		AHK_path=%A_ScriptDir%\AutoHotkey.exe
}

If Editor_Path=
{
	IfExist, %A_ScriptDir%\SciTE\SciTE.exe
		Editor_Path=%A_ScriptDir%\SciTE\SciTE.exe
	else{
		IfExist, %A_WinDir%\notepad.exe
			Editor_Path=%A_WinDir%\notepad.exe
	}
}

If Compiler_Path=
{
	IfExist, %A_ScriptDir%\Compiler\Ahk2Exe.exe
		Compiler_Path=%A_ScriptDir%\Compiler\Ahk2Exe.exe
}

If Template_Path=
{
	IfExist, %A_ScriptDir%\AutoHotkey.exe
		Template_Path=%A_ScriptDir%\Template.ahk
}
else
{
	SplitPath,Template_Path,Template_Name,Template_Path
	Template_Path=%A_WinDir%\ShellNew\%Template_Name%
}

Gui, Add, Tab, x10 y10 w480 h300 Choose1, 设置|说明|更新历史
Gui, Tab, 1
Gui, Add, GroupBox, x20 y40 w460 h50 , “运行脚本”关联的 AutoHotkey
Gui, Add, Edit, x35 y60 w340 h20 vAHK_Path, %AHK_path%
Gui, Add, Button, x385 y60 w40 h20 gFind_AHK, 浏览

Gui, Add, GroupBox, x20 y100 w460 h50 , “编辑脚本”关联的编辑器
;~ MsgBox %Editor_Path%
Gui, Add, Edit, x35 y120 w340 h20 vEditor_Path, %Editor_Path%
Gui, Add, Button, x385 y120 w40 h20 gChoose_Editor, 浏览
Gui, Add, Button, x430 y120 w40 h20 gDefault_Editor, 默认

Gui, Add, GroupBox, x20 y160 w460 h50 , “编译脚本”关联的编译器
Gui, Add, Edit, x35 y180 w340 h20 vCompiler_Path, %Compiler_Path%
Gui, Add, Button, x385 y180 w40 h20 gChoose_Compiler, 浏览
Gui, Add, Button, x430 y180 w40 h20 gDefault_Compiler, 默认

Gui, Add, GroupBox, x20 y220 w460 h50 , “模板”存放路径
Gui, Add, Edit, x35 y240 w340 h20 vTemplate_Path, %Template_Path%
Gui, Add, Button, x385 y240 w40 h20 gChoose_Template, 浏览
Gui, Add, Button, x430 y240 w40 h20 gDefault_Template, 默认

Gui, Add, Checkbox, x35 y280 w270 h20 Checked gNew_Script vNew_Script, 右键“新建”菜单中增加“AutoHotkey 脚本”
Gui, Add, Button, x310 y280 w80 h20 vEdit_Template gEdit_Template, 编辑脚本模板
Gui, Add, Button, x400 y280 w80 h20 vDelete_Template gDelete_Template, 删除脚本模板

Gui, Tab, 2
Gui, Font, bold
Gui, Add, Text,, AutoHotkey 脚本关联工具  %ScriptName%
Gui, Font
Gui, Font, CBlue Underline
Gui, Add, Text, gWebsite, 原作者：甲壳虫 <jdchenjian@gmail.com>`n`n博客：http://hi.baidu.com/jdchenjian
Gui, Font
Gui, Add, Text, w450, 此工具用来修改 AutoHotkey 脚本的右键菜单关联，适用于 AutoHotkey 安装版、绿色版。`n`n此版本是sunwind(QQ1576157) 基于甲壳虫的v1.0.3版本修改完善的。
Gui, Add, Text, w450, 您可以用它来修改默认脚本编辑器、编译器，修改默认的新建脚本模板。设置后，在右键菜单中添加“运行脚本”、“编辑脚本”、“编译脚本”和“新建 AutoHotkey 脚本”等选项。
Gui, Add, Text, w450, 要取消脚本的系统关联，请按“卸载”。注意：卸载后您将无法通过双击来运行脚本，也不能通过右键菜单来启动脚本编辑器...

Gui, Tab, 3
Gui, Font, bold
Gui, Add, Text,, 更新历史
Gui, Font
 
Gui, Add, Text, w450, %Change_History%

Gui, Tab
Gui, Add, Button, x100 y320 w60 h20 Default gInstall, 设置
Gui, Add, Button, x200 y320 w60 h20 gUninstall, 卸载
Gui, Add, Button, x300 y320 w60 h20 gCancel, 取消

Gui, Show, x250 y200 h350 w500 Center,  %ScriptName%
IfNotExist, %Template_Path%
	GuiControl, Disable, Delete_Template ; 使“删除脚本模板”按钮无效

; 当鼠标指向链接时，指针变成手形
hCurs:=DllCall("LoadCursor","UInt",NULL,"Int",32649,"UInt") ;IDC_HAND
OnMessage(0x200,"WM_MOUSEMOVE")
Return

; 改变鼠标指针为手形
WM_MOUSEMOVE(wParam,lParam)
{
  Global hCurs
  MouseGetPos,,,,ctrl
  If ctrl in Static2
    DllCall("SetCursor","UInt",hCurs)
  Return
}
Return

GuiClose:
GuiEscape:
Cancel:
ExitApp

; 查找 AutoHotkey 主程序
Find_AHK:
Gui +OwnDialogs
FileSelectFile, AHK_Path, 3, , 查找 AutoHotkey.exe,*.exe
If AHK_Path<>
	GuiControl,,AHK_Path, %AHK_Path%
Gosub Default_Editor
Gosub Default_Compiler
Return

; 选择脚本编辑器
Choose_Editor:
Gui +OwnDialogs
FileSelectFile, Editor_Path, 3, , 选择脚本编辑器, 程序(*.exe)
If Editor_Path<>
	GuiControl,,Editor_Path, %Editor_Path%
Return

; 默认脚本编辑器
Default_Editor:
IfExist, %A_ScriptDir%\SciTE\SciTE.exe
	Editor_Path=%A_ScriptDir%\SciTE\SciTE.exe
Else IfExist, %A_WinDir%\notepad.exe
	Editor_Path=%A_WinDir%\notepad.exe
Else IfExist, %A_WinDir%\system32\notepad.exe
	Editor_Path=%A_WinDir%\system32\notepad.exe

GuiControl,, Editor_Path, %Editor_Path%
Return

; 选择脚本编译器
Choose_Compiler:
Gui +OwnDialogs
FileSelectFile, Compiler_Path, 3, , 选择脚本编译器, 程序(*.exe)
If Compiler_Path<>
	GuiControl,,Compiler_Path, %Compiler_Path%
Return

; 默认脚本编译器
Default_Compiler:
GuiControlGet, AHK_Path
SplitPath, AHK_Path, ,AHK_Dir
IfExist, %AHK_Dir%\Compiler\Ahk2Exe.exe
{
	Compiler_Path=%AHK_Dir%\Compiler\Ahk2Exe.exe
	GuiControl,, Compiler_Path, %Compiler_Path%
}
Return

; 选择模板位置
Choose_Template:
FileSelectFile, Template_Path, 3, , 选择脚本模板位置 程序(*.ahk)

If Template_Path<>
	GuiControl,,Template_Path, %Template_Path%
Return
; 默认模板位置
Default_Template:
IfExist, %A_ScriptDir%\AutoHotkey.exe
	Template_Path=%A_ScriptDir%\Template.ahk
else
	Template_Path=Template.ahk  ;会默认放到%A_WinDir%\ShellNew\

GuiControl,, Template_Path, %Template_Path%
Return
 

; 设置
Install:
Gui, Submit
IfNotExist, %AHK_Path%
{
	MsgBox, 16,  %ScriptName%, AutoHotkey 路径错误 ！
	Return
}

IfNotExist, %Editor_Path%
{
	MsgBox, 16,  %ScriptName%, 编辑器路径错误 ！
	Return
}

IfNotExist, %Compiler_Path%
{
	MsgBox, 16,   %ScriptName%, 提示未设置正确，不过不强制设置，点击确定继续 ！
	;~ Return
}

; 写入注册表
RegWrite, REG_SZ, %RootKey%, %Subkey%.ahk,, %FileType%
If New_Script=1
{
	RegWrite, REG_SZ, %RootKey%, %Subkey%.ahk\ShellNew, FileName, %Template_Path%
	IfNotExist, %Template_Path%
		Gosub Create_Template
	;~ IfNotExist, %A_WinDir%\ShellNew\%Template_Name%
		;~ Gosub Create_Template
}
Else
{
	RegDelete, %RootKey%, %Subkey%.ahk\ShellNew
	IfExist, %Template_Path%
	;~ IfExist, %A_WinDir%\ShellNew\%Template_Name%
		Gosub Delete_Template
}

RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%,, AutoHotkey 脚本 ;AutoHotkey Script
RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\DefaultIcon,, %AHK_Path%`,1
RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell,, Open
RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell\Open,, 运行脚本(&R) ;Run Script 运行
;RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell\Open\Command,, "%AHK_Path%" /CP936 "`%1" `%*
RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell\Open\Command,, "%AHK_Path%" "`%1" `%*

RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell\Edit,, 编辑脚本(&E) ;Edit Script 编辑
RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell\Edit\Command,, "%Editor_Path%" "`%1"
RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell\Compile,, 编译脚本(&C) ;Compile Script
RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\ShellEx\DropHandler,,{86C86720-42A0-1069-A2E8-08002B30309D} ;DropHandler
IfInString, Compiler_Path, Ahk2Exe.exe
	RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell\Compile\Command,, "%Compiler_Path%" /in "`%1"
Else
	RegWrite, REG_SZ, %RootKey%, %Subkey%%FileType%\Shell\Compile\Command,, "%Compiler_Path%" "`%1"
	
RegisterIDs(CLSID_SciTE4AHK, APPID_SciTE4AHK)

MsgBox, 64,   %ScriptName%, 设置完毕 ！
ExitApp

; 卸载
Uninstall:
MsgBox, 36,   %ScriptName%
, 注意：卸载后您将无法通过双击来运行脚本，也不能通过右键菜单来启动脚本编辑器...`n`n确定要取消 AHK 脚本的系统关联吗 ？
IfMsgBox, Yes
{
	RegDelete, %RootKey%, %Subkey%.ahk
	RegDelete, %RootKey%, %Subkey%%FileType%
	RevokeIDs(CLSID_SciTE4AHK, APPID_SciTE4AHK)
	Gosub Delete_Template
	ExitApp
}
Return

; 编辑脚本模板
Edit_Template:
GuiControlGet, Editor_Path
IfNotExist, %Editor_Path%
{
	MsgBox, 64,  %ScriptName%, 脚本编辑器路径错误 ！
	Return
}
;~ IfNotExist, %A_WinDir%\ShellNew\%Template_Name%
IfNotExist, %Template_Path%
	Gosub Create_Template
Run, %Editor_Path% %Template_Path%
;~ Run, %Editor_Path% %A_WinDir%\ShellNew\%Template_Name%
Return

; 使编辑脚本模板按钮有效/无效
New_Script:
GuiControlGet, New_Script
If New_Script=0
	GuiControl, Disable, Edit_Template
Else
	GuiControl, Enable, Edit_Template
Return

; 新建脚本模板
Create_Template:
GuiControlGet, AHK_Path
FileGetVersion, AHK_Ver, %AHK_Path%

FileAppend,
(
/*	名称：		版本：v1.0		AutoHotkey：%AHK_Ver%		编码：UTF-8 BOM

	作者：纯属意外

	说明：
*/
;#NoTrayIcon                         ; 不显示托盘图标
#NoEnv                              ; 不检查环境变量
#SingleInstance Ignore              ; 忽略重复运行脚本(force|ignore|off)
SendMode Input                      ; 改变按键发送模式
SetWorkingDir `%A_ScriptDir`%       ; 设置脚本工作目录
; --------------------------------------------------------------------------------

), %Template_Path%,UTF-8
;~ ), %A_WinDir%\ShellNew\%Template_Name%

GuiControl, Enable, Delete_Template ; 使“删除脚本模板”按钮有效
Return

; 删除脚本模板
Delete_Template:
MsgBox, 36,  %ScriptName%
, 要删除当前的 AHK 脚本模板吗 ？`n`n脚本模板被删除后，仍可通过本工具重建模板。
IfMsgBox, Yes
	FileDelete, %Template_Path%
	;~ FileDelete, %A_WinDir%\ShellNew\%Template_Name%
GuiControl, Disable, Delete_Template ; 使“删除脚本模板”按钮无效
Return

; 打开网站
Website:
Run, http://hi.baidu.com/jdchenjian
Return

RegisterIDs(CLSID, APPID)
{
	RegWrite, REG_SZ, HKCU, Software\Classes\%APPID%,, %APPID%
	RegWrite, REG_SZ, HKCU, Software\Classes\%APPID%\CLSID,, %CLSID%
	RegWrite, REG_SZ, HKCU, Software\Classes\CLSID\%CLSID%,, %APPID%
}

RevokeIDs(CLSID, APPID)
{
	RegDelete, HKCU, Software\Classes\%APPID%
	RegDelete, HKCU, Software\Classes\CLSID\%CLSID%
}


; 从注册表值字符串中提取路径
PathGetPath(pSourceCmd)
{

	 Local Path, ArgsStartPos = 0
	OutputDebug,%pSourceCmd%
	 If (SubStr(pSourceCmd, 1, 1) = """")
		 {
		    Path := SubStr(pSourceCmd, 2, InStr(pSourceCmd, """", False, 2) - 2)
		  	OutputDebug,lf:%Path%
			}
	 Else
	 {
		  ArgsStartPos := InStr(pSourceCmd, " ")
		  If ArgsStartPos
				Path := SubStr(pSourceCmd, 1, ArgsStartPos - 1)
		  Else
				Path = %pSourceCmd%
		OutputDebug,Else:%Path%
	 }
	 Return Path
}
