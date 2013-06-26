/*  名称:自动语法整理    版本:V12    主页:www.autohotkey.com/forum/topic7810.html
   
    说明:根据语法和命令更改缩进
    ----------------------------

    已知的限制:
    ----------------------------
    - 需要空格后的最后 ":" 热键, 热字串和子程序
    - 意见可能不具备在某些强烈的右缩进封装块结构，由于不知道下一行会带来什么。
    - 情况下，校正工作超过4个字符的话，
    (除了: (在所有情况下，) If, Loop, Else
    (可选)  Goto, Gui, Run, Exit, Send, Sort, Menu
            Parse, Read, Mouse, SendAndMouse, Default, Permit, Screen, Relative
            Pixel, Toggle, UseErrorLevel, AlwaysOn, AlwaysOff

    !!! 慎重 !!! 矫正情况非常危险，因为WinTitles命令是大小写敏感的

    - 在编辑器光标跳跃后做缩进在最后一行到第一位置
    - 缩进可能会失败，如果一个 "{" 一个循环的最后一个字符，如果语句不支持OTB. 例如. "If x = {" or "Loop, Parse, Var, {"

    功能:
    ----------------------------
    - Gui: 对于拖放文件，设置选项和反馈
    - 命令行选项 "/in" 用于文件和 "/log" 日志文件
    - 命令行选项 "/hidden" 隐藏GUI启动脚本
    - 命令行选项 "/watch hwnd" 隐藏GUI启动脚本，关闭在HWND关闭时
    - 命令行选项 "/toggle" 检查如果另一个实例正在运行，并关闭这两个脚本
    - 命令行选项 "/hidden" 无GUI启动脚本

    选项:
    ----------------------------
    - 定制热键 indenation
    - 自定义文件扩展名           (如果没有指定，会覆盖旧的文件)
    - 自定义缩进                 (一个选项卡或空格数)
    - 不同的缩进风格             (Rajat, Toralf or BoBo)
    - 连续行缩进                 (一些制表符或空格)
    - 缩进保存块延续线           (圆括弧) On/Off
    - 缩进保存块注释             (/* ... */)      On/Off
    - 校正语法词的情况下超过4个字符 (感谢拉雅)
    - 统计脚本 (总空行代码，注释所需时间)
    - 掉落的文件: 内容将被缩进，并复制到一个新文件与用户定义的扩展 (如果没有指定，会覆盖旧的文件).
    - 热键 (F2): 在编辑器中突出显示的语法将缩进，如果没有强调所有文本将缩进。 （感谢圣油）
    - Gui 记得最后一个位置和设置会话之间（感谢拉雅）
    - 子程序调用和函数调用的情况下，调整的情况下它们分别定义
    - 按Ctrl-D切换调试模式
    - 12% 快则第7版(由于缩短循环周期) 但长90线

    !!! 没有大量测试 !!!!  ---- !!!!!! 备份你的数据 !!!!!

    希望:
    ----------------------------
    - 条型码：删除空行，所有的意见，并加入分割表达式的选项 (&&/AND/OR/||)


    v11版本以后的变化 :
    ----------------------------
    - 托盘图标可以切换显示/隐藏GUI和退出脚本
    - 进度条，如果identation做一个编辑器里面加入了BlockInput用于限制干扰
    - 功能，新功能shortend代码的行数等于入住
    - 日志文本滚动到最后
    - on /hidden, 创建GUI，但隐藏在这两种情况下，托盘图标可见。
    - on "/watch hwnd" , GUI是隐藏和关闭时HWND关闭
    - on /toggle, 脚本检查，如果另一个实例正在运行，并关闭这两个脚本
    - 改善possibilty华民找到路径
    - 警告消息，如果文件不存在语法
    - OwnHotkey INI文件存储在GUI中有一个控制
*/

FileInstall,AutoSyntaxTidy.ahk,AutoSyntaxTidy.ahk
FileInstall,AutoSyntaxTidy.ini,AutoSyntaxTidy.ini

Version = v12
ScriptName =  Auto-Syntax-Tidy %Version%


#SingleInstance off
SetBatchLines, -1

;设置工作目录，这个脚本调用一些其他的脚本在不同的目录
SetWorkingDir, %A_ScriptDir%

;处理命令行参数   ;by Ace_NoOne - www.autohotkey.com/forum/viewtopic.php?t=7556
If %0%{
        Loop, %0% { ; 每个命令行参数
                next := A_Index + 1           ;得到下一个参数号
                ; 检查如果存在已知的命令行参数
                If (%A_Index% = "/in")
                        param_in := %next%   ;指定下一个命令行参数值
                Else If (%A_Index% = "/log")
                        param_log := %next%
                Else If (%A_Index% = "/Hidden")
                        param_Hidden = Hide
                Else If (%A_Index% = "/watch"){
                        param_Hidden = Hide
                        param_watch := %next%
                }Else If (%A_Index% = "/Toggle")
                        Gosub, CheckAndToggleRunState
            }
    }

;Turn DebugMode on (=1) ，以显示与Debug（调试）信息的MsgBox的
DebugMode = 0

;图标文件的位置
If ( A_OSType = "WIN32_WINDOWS" )  ; Windows 9x
        IconFile = %A_WinDir%\system\shell32.dll
Else
        IconFile = %A_WinDir%\system32\shell32.dll

;托盘菜单
Menu, Tray, Icon, %IconFile%, 56   ;任务栏图标和任务管理器的进程
Menu, Tray, Tip, %ScriptName%
Menu, Tray, NoStandard
Menu, Tray, Add, 显示/隐藏, ShowHideGui
Menu, Tray, Add, 退出, ExitApp
Menu, Tray, Default, 显示/隐藏
Menu, Tray, Click, 1

SplitPath, A_ScriptName, , , , OutNameNoExt
IniFile = %OutNameNoExt%.ini
Gosub, ReadDataFromIni

;找到华民航空的路径
If !FileExist(AHKPath){
        SplitPath, A_AHKPath,, AHKPath
        If !FileExist(AHKPath){
                RegRead, AHKPath, HKLM, Software\AutoHotkey, InstallDir
                If !FileExist(AHKPath){
                        RegRead, AHKPath, HKCR, Applications\AutoHotkey.exe\shell\Open\Command
                        StringTrimLeft, AHKPath, EdtAHKPath, 1
                        StringTrimRight, AHKPath, EdtAHKPath, 24
                        If !FileExist(AHKPath){
                                AHKPath = %A_ProgramFiles%\AutoHotkey
                                If !FileExist(AHKPath){
                                        AHKPath = C:\Programme\AutoHotkey
                                        If !FileExist(AHKPath){
                                                AHKPath =
                                            }
                                    }
                            }
                    }
            }
    }
IfNotExist %AHKPath%
    { MsgBox,,, 找不到 AutoHotkey 文件夹.`n请编辑脚本: `n%A_ScriptFullPath%`n行号: %A_LineNumber%
        ExitApp
    }

Gosub, ReadSyntaxFiles

If FileExist(param_in){
        Gosub, IndentFile
        ExitApp
    }

Gosub, BuildGui

If param_watch
        SetTimer, WatchWindow, On

;禁用热键在自己的GUI
Hotkey, IfWinNotActive, %GuiUniqueID%
;设置热键，并记住它
Hotkey, %OwnHotKey%, IndentHighlightedText
OldHtk = %OwnHotkey%
Hotkey, IfWinNotActive,
Return
;#############   自动执行部分结束   ####################################

;#############   作案的toogle调试  #########################################
^d::
    DebugMode := not DebugMode
    ToolTip, 调试模式 = %DebugMode%
    Sleep, 1000
    ToolTip
Return

;#############   关闭脚本时表窗口不存在   ###############
WatchWindow:
    DetectHiddenWindows, On
    If !WinExist("ahk_id " param_watch)  ;检查监视窗口是否存在
            Gosub, GuiClose                  ;如果不关闭这个脚本
    DetectHiddenWindows, Off
Return

;#############   第二次运行的toogle运行状态 - 关闭   ####################
CheckAndToggleRunState:
    ;获得自己的PID
    Process, Exist
    OwnPID := ErrorLevel

    ;get own title
    If A_IsCompiled
            OwnTitle := A_ScriptFullPath
    Else
            OwnTitle := A_ScriptFullPath " - AutoHotkey v" A_AhkVersion

    ;得到所有窗口列表
    DetectHiddenWindows, On
    WinGet, WinIDs, List

    ;通过列表，并获得他们的头衔
    Loop, %WinIDs% {
            UniqueID := "ahk_id " WinIDs%A_Index%
            WinGetTitle, winTitle, %UniqueID%

            ;检查是否有脚本与同一个标题，因为这是一个窗口，但本身并不是
            If (winTitle = OwnTitle ) {
                    WinGet, winPID, PID, %UniqueID%
                    If (winPID <> OwnPID) {
                            ;关闭它本身
                            Process, Close, %winPID%
                            ExitApp
                        }
                }
        }
    DetectHiddenWindows, off
Return

;#############   从语法文件中读取指令和命令   ##############
ReadSyntaxFiles:
    ;语法文件的路径
	IfExist %A_ScriptDir%\Extras\Editors\Syntax\CommandNames.txt
		PathSyntaxFiles = %A_ScriptDir%\Extras\Editors\Syntax
    Else
		PathSyntaxFiles = %AHKPath%\Extras\Editors\Syntax

    ;明确列出
    ListOfDirectives =
    ListOfIFCommands =

    ;阅读语法文件的每一行和搜索指令，如果关键字
    ;~ MsgBox PathSyntaxFiles%PathSyntaxFiles%
    CommandNamesFile = %PathSyntaxFiles%\CommandNames.txt
    ;~ MsgBox %CommandNamesFile%
    IfNotExist %CommandNamesFile%
        {
             MsgBox,,, 路径: "%CommandNamesFile%" `n找不到 "CommandNames.txt" 文件.`n请编辑脚本: `n%A_ScriptFullPath%`n行号: %A_LineNumber%
            ExitApp
        }
    Loop, Read , %CommandNamesFile%   ;阅读语法文件
        { ;删除空格从读线
            Line = %A_LoopReadLine%

            ;获得第一个字符和第2行的字符
            StringLeft,FirstChar, Line ,1
            StringLeft,FirstTwoChars, Line ,2

            ;如果行是注释，继续下一行
            If (FirstChar = ";")
                    Continue
            ;否则，如果关键字的指令或关键字，如果添加它列出
            Else If (FirstChar = "#")
                    ListOfDirectives=%ListOfDirectives%,%Line%
            Else If (FirstTwoChars = "if") {
                    ;第一个字，因为如果关键字的语法文件中有更多的单词
                    StringSplit, Array, Line, %A_Space%
                    Line = %Array1%
                    If (StrLen(Line) > 4)
                            ListOfIFCommands=%ListOfIFCommands%,%Line%
                }
        }
    ;删除第一个逗号和换至低炭
    StringTrimLeft,ListOfIFCommands,ListOfIFCommands,1
    StringTrimLeft,ListOfDirectives,ListOfDirectives,1

    ;如果删除多个
    Sort, ListOfIFCommands, U D,

    ;阅读所有变量名
    FileRead, Variables, *t %PathSyntaxFiles%\Variables.txt
    StringReplace , Variables , Variables , `n , | , All

    FilesSyntax = CommandNames|Keywords|Keys

    ;遍历所有语法文件
    Loop, Parse, FilesSyntax,|
        { String =
            SyntaxFile = %PathSyntaxFiles%\%A_LoopField%.txt
            IfNotExist %SyntaxFile%
                { MsgBox,,,  路径: "%SyntaxFile%" `n找不到语法文件 "%A_LoopField%.txt".`n请编辑脚本:`n%A_ScriptFullPath%`n行号: %A_LineNumber%
                    ExitApp
                }
            ;阅读语法文件的每一行
            Loop, Read , %SyntaxFile%
                {
                    ;删除空格从读线
                    Line = %A_LoopReadLine%

                    ;获得第一个字符，线路长度，看看空间
                    StringLeft,FirstChar, Line ,1

                    ;如果包含空格，继续下一行
                    If InStr(Line," ")
                            Continue
                    ;如果线是空的，继续下一行
                    Else If Line is Space
                            Continue
                    ;如果行是注释，继续下一行
                    Else If (FirstChar = ";")
                            Continue
                    ;否则，如果词是超过4个字符，请记住它
                    Else If (StrLen(Line) > 4 )
                            String = %String%,%Line%
                }
            ;除去第一管
            StringTrimLeft,String,String,1
            ;店想起在var字符串具有相同的名称syntaxfile
            %A_LoopField% := String
        }

    CommandNames = %CommandNames%,Goto,Gui,Run,Exit,Send,Sort,Menu
        ,Parse,Read,Mouse,SendAndMouse,Default,Permit,Screen,Relative
        ,Pixel,Toggle,UseErrorLevel,AlwaysOn,AlwaysOff

    ;阅读中的所有函数名
    BuildInFunctions =
    ;阅读语法文件的每一行
    FunctionsFile = %PathSyntaxFiles%\Functions.txt
    IfNotExist %SyntaxFile%
        { MsgBox,,, 路径: "%FunctionsFile%" `n找不到 "Functions.txt" 文件.`n请编辑脚本:`n%A_ScriptFullPath%`n行号: %A_LineNumber%
            ExitApp
        }
    Loop, Read , %FunctionsFile%
        { ;删除空格从读线
            Line = %A_LoopReadLine%

            ;获得第一个字符，函数的名字加上其墙座，如. "ATan("
            StringLeft,FirstChar, Line ,1
            StringSplit, Line, Line, (

            ;如果线是空的，继续下一行
            If Line is Space
                    Continue
            ;如果行是注释，继续下一行
            Else If (FirstChar = ";")
                    Continue
            ;否则记得它与BRAKET
            Else
                    BuildInFunctions = %BuildInFunctions%,%Line1%(
        }
    ;不删除第一个逗号，它只是校正前将完成

Return

;#############   INI文件中读取数据  ####################################
ReadDataFromIni:
    IniRead, Extension, %IniFile%, Settings, Extension, _autoindent_%Version%.ahk
    IniRead, Indentation, %IniFile%, Settings, Indentation, 2
    IniRead, NumberSpaces, %IniFile%, Settings, NumberSpaces, 2
    IniRead, NumberIndentCont, %IniFile%, Settings, NumberIndentCont, 8
    IniRead, IndentCont, %IniFile%, Settings, IndentCont, 2
    IniRead, Style, %IniFile%, Settings, Style, 2
    IniRead, CaseCorrectCommands, %IniFile%, Settings, CaseCorrectCommands, 1
    IniRead, CaseCorrectVariables, %IniFile%, Settings, CaseCorrectVariables, 1
    IniRead, CaseCorrectBuildInFunctions, %IniFile%, Settings, CaseCorrectBuildInFunctions, 1
    IniRead, CaseCorrectKeys, %IniFile%, Settings, CaseCorrectKeys, 1
    IniRead, CaseCorrectKeywords, %IniFile%, Settings, CaseCorrectKeywords, 1
    IniRead, CaseCorrectDirectives, %IniFile%, Settings, CaseCorrectDirectives, 1
    IniRead, Statistic, %IniFile%, Settings, Statistic, 1
    IniRead, ChkSpecialTabIndent, %IniFile%, Settings, ChkSpecialTabIndent, 1
    IniRead, KeepBlockCommentIndent, %IniFile%, Settings, KeepBlockCommentIndent, 0
    IniRead, AHKPath, %IniFile%, Settings, AHKPath, %A_Space%
    ;~ MsgBox %AHKPath%
    IniRead, OwnHotkey, %IniFile%, Settings, OwnHotKey, F2
Return

OwnHotKey:
    ;deacticate老热键
    Hotkey, IfWinNotActive, %GuiUniqueID%
    Hotkey, %OldHtk%, IndentHighlightedText, Off
    ;不要让没有热键
    If OwnHotkey is Space
        {
            Hotkey, %OldHtk%, IndentHighlightedText
            GuiControl, , OwnHotkey, %OldHtk%
    }Else{
            Hotkey, %OwnHotKey%, IndentHighlightedText
            OldHtk = %OwnHotkey%
        }
    Hotkey, IfWinNotActive,
Return

;#############   构建GUI自动语法整理   #############################
BuildGui:
    LogText = %OwnHotkey% :减少当前脚本中的缩进.`n并突出AHK脚本语法.`n`nCtrl + D :选择调试模式 `n

    Gui, +ToolWindow +AlwaysOnTop
    Gui, Add, Text, xm Section ,热键
    Gui, Add, Hotkey, ys-3 r1 w206 vOwnHotkey gOwnHotKey, %OwnHotKey%

    Gui, Add, Text, xm Section ,扩展名
    Gui, Add, Edit, ys-3 r1 w117 vExtension, %Extension%

    Gui, Add, GroupBox, xm w242 r6.3,缩进
    Gui, Add, Text, xp+8 yp+15 Section,类型:
    Gui, Add, Radio, ys vIndentation,Tab x1 或
    Gui, Add, Radio, ys Checked,Spaces x
    Gui, Add, Edit, ys-3 r1 Limit1 Number w20 vNumberSpaces, %NumberSpaces%
    Gui, Add, Text, xs Section,风格:
    Gui, Add, Radio, x+8 ys vStyle,Rajat
    Gui, Add, Radio, x+8 ys Checked,Toralf
    Gui, Add, Radio, x+8 ys ,BoBo
    Gui, Add, Text, xs Section,延续行缩进方式:
    Gui, Add, Edit, xs ys+15 Section r1 Limit2 Number w20 vNumberIndentCont, %NumberIndentCont%
    Gui, Add, Text, ys+4, x
    Gui, Add, Radio, ys+4 vIndentCont ,Tabs 或
    Gui, Add, Radio, ys+4 Checked,Spaces
    Gui, Add, Checkbox, xs vKeepBlockCommentIndent Checked%KeepBlockCommentIndent%, 保留块注释缩进
    Gui, Add, Checkbox, xs vChkSpecialTabIndent Checked%ChkSpecialTabIndent%, 特殊缩进 "Gui,Tab" 

    Gui, Add, GroupBox, xm w242 r3,脚本修正
    Gui, Add, Checkbox, xp+8 yp+18 Section vCaseCorrectCommands Checked%CaseCorrectCommands%,命令
    Gui, Add, Checkbox, vCaseCorrectVariables Checked%CaseCorrectVariables%,变量
    Gui, Add, Checkbox, vCaseCorrectBuildInFunctions Checked%CaseCorrectBuildInFunctions%,内置函数
    Gui, Add, Checkbox, ys vCaseCorrectKeys Checked%CaseCorrectKeys%,按键
    Gui, Add, Checkbox, vCaseCorrectKeywords Checked%CaseCorrectKeywords%,关键词
    Gui, Add, Checkbox, vCaseCorrectDirectives Checked%CaseCorrectDirectives%,指令
    Gui, Add, Text, xm Section, 信息
    Gui, Add, Checkbox, ys vStatistic Checked%Statistic%, 统计
    Gui, Add, Edit, xm r10 w242 vlog ReadOnly, %LogText%

    If (Indentation = 1)
            GuiControl,,Tab x1 或,1
    If (Style = 1)
            GuiControl,,Rajat,1
    Else If (Style = 3)
            GuiControl,,BoBo,1
    If (IndentCont = 1)
            GuiControl,, IndentCont, 1

    ;以前的位置，并显示桂
    IniRead, Pos_Gui, %IniFile%, General, Pos_Gui,
    Gui, Show, %Pos_Gui% %param_Hidden% ,%ScriptName%
    Gui, +LastFound
    GuiUniqueID := "ahk_id " WinExist()

    ;获得日志classNN控制
    GuiControl, Focus, Log
    ControlGetFocus, ClassLog, %GuiUniqueID%
    GuiControl, Focus, Extension
Return

;#############   Toggle 显示/隐藏托盘图标桂  ###################
ShowHideGui:
    If param_Hidden {
            Gui, Show
            param_Hidden =
    }Else{
            param_Hidden = Hide
            Gui, Show, %param_Hidden%
        }
Return

;#############   功能IIF：返回a或b取决于表达   #######
iif(exp,a,b=""){
        If exp
                Return a
        Return b
    }

;#############   捷径 F? - 缩进突出显示的文本  ######################
IndentHighlightedText:
    ;存储速度测量的时间
    StartTime = %A_TickCount%

    ;保存并清除剪贴板
    ClipSaved := ClipboardAll
    Clipboard =

    ;剪切突出到剪贴板
    Send, ^c

    ;获得当前窗口的窗口的UID
    WinUniqueID := WinExist("A")

    ;如果没有突出显示，选择和复制
    If Clipboard is Space
        { ;选择和复制到剪贴板
            Send, ^a^c
        }

    ;摆脱所有回车 (`r).
    StringReplace, ClipboardString, Clipboard, `r`n, `n, All

    ;恢复原来的剪贴板和释放内存
    Clipboard := ClipSaved
    ClipSaved =

    ;如果被选中的东西，做压痕，并再次把它放回
    If ClipboardString is Space
            MsgBox, 0 , %ScriptName%,
        (LTrim
            没有发现任何缩进。
            请再试一次。
        ), 1
    Else {
            ;获得选项
            Gui, Submit, NoHide

            ;创建进度条和块的输入
            StringReplace, x, ClipboardString, `n, `n, All UseErrorLevel
            NumberOfLines = %ErrorLevel%
            Progress, R0-%NumberOfLines% FM10 WM8000 FS8 WS400, `n, 请稍候 `n正在运行自动语法整理, %ScriptName%
            BlockInput, On

            ;设置矫正情况的话
            Gosub, SetCaseCorrectionSyntax

            ;创建缩进
            Gosub, CreateIndentSize

            ;重置所有值
            Gosub, SetStartValues

            ;阅读每一行形式剪贴板
            Loop, Parse, ClipboardString, `n
                { ;记得原线其identation
                    AutoTrim, Off
                    Original_Line = %A_LoopField%
                    AutoTrim, On

                    ;做压痕
                    Gosub, DoSyntaxIndentation

                    ;更新进度条，每10日线
                    If (Mod(A_Index, 10)=0)
                            Progress, %A_Index%, 行: %A_Index% 的 %NumberOfLines%
                }

            CaseCorrectSubsAndFuncNames()

            ;除去最后 `n
            StringTrimRight,String,String,1

            ;保存并清除剪贴板
            ClipSaved := ClipboardAll
            Clipboard =

            ;把字符串到剪贴板
            ;StringReplace, String, String, `n, `r`n, All
            Clipboard = %String%

            ;关闭进度条和重新激活旧的窗口
            Progress, Off
            WinActivate, ahk_id %WinUniqueID%

            ;粘贴剪贴板
            Send, ^v{HOME}
            ;恢复原来的剪贴板和释放内存
            Clipboard := ClipSaved
            ClipSaved =

            ;关闭块输入
            BlockInput, Off

            ;写信息
            LogText = %LogText% 文本编辑器缩进 `n
            If Statistic
                    Gosub, AddStatisticToLog
            Else
                    LogText = %LogText%`n
            GuiControl, ,Log , %LogText%
            ControlSend, %ClassLog%, ^{End}, %GuiUniqueID%
        }
Return

;#############   设置情况下，校正的话  ##############################
SetCaseCorrectionSyntax:
    CaseCorrectionSyntax =
    If CaseCorrectCommands
            CaseCorrectionSyntax = ,%CommandNames%
    If CaseCorrectVariables
            CaseCorrectionSyntax = %CaseCorrectionSyntax%,%Variables%
    If CaseCorrectKeys
            CaseCorrectionSyntax = %CaseCorrectionSyntax%,%Keys%
    If CaseCorrectKeywords
            CaseCorrectionSyntax = %CaseCorrectionSyntax%,%Keywords%
    If CaseCorrectDirectives
            CaseCorrectionSyntax = %CaseCorrectionSyntax%,%ListOfDirectives%
    ;remove first pipe
    StringTrimLeft, CaseCorrectionSyntax, CaseCorrectionSyntax, 1
Return

;#############   创建缩进大小取决于选择   ###############
CreateIndentSize:
    ;clear
    IndentSize =
    IndentContLine =

    ;打开自动配能够指定空格和制表符
    AutoTrim, Off

    ;创建缩进大小取决于选项
    If Indentation = 1
            IndentSize = %A_Tab%
    Else
            Loop, %NumberSpaces%
                    IndentSize = %IndentSize%%A_Space%

            ;续行缩进
    If IndentCont = 1
            Loop, %NumberIndentCont%
                    IndentContLine = %IndentContLine%%A_Tab%
    Else
            Loop, %NumberIndentCont%
                    IndentContLine = %IndentContLine%%A_Space%

            ;设置自动配默认
    AutoTrim, On
Return

;#############   重置所有启动值   #####################################
SetStartValues:
    String =                 ;字符串，保存文件内容temporarely（自动缩进）
    Indent =                 ;压痕字符串
    IndentIndex = 0          ;的阵列Inde​​ntIncrement和IndentCommand指数
    InBlockComment := False  ;循环状态，如果在Blockcomment
    InsideContinuation := False
    InsideTab = 0
    EmptyLineCount = 0       ;Counts the Number of empty Lines for statistics
    TotalLineCount = 0       ;Counts the Number of total Lines for statistics
    CommentLineCount = 0     ;Counts the Number of comments Lines for statistics
    If CaseCorrectBuildInFunctions
            CaseCorrectFuncList = %BuildInFunctions%  ;CSV list of function names in current script including build in functions
    Else
            CaseCorrectFuncList =                     ;CSV list of function names in current script
    CaseCorrectSubsList=     ;CSV list of subroutine names in current script
    Loop, 11{
            IndentIncrement%A_Index% =
            IndentCommand%A_Index% =
        }
Return

;#############   缩进所有删除的文件   ###################################
GuiDropFiles:
    ;store time for speed measurement
    OverAllStartTime = %A_TickCount%

    ;get options
    Gui, Submit,NoHide

    ;set words for case correction
    Gosub, SetCaseCorrectionSyntax

    ;create indentation
    Gosub, CreateIndentSize

    OverAllCodeLineCount = 0
    OverAllTotalLineCount = 0
    OverAllCommentLineCount = 0
    OverAllCommentLineCount = 0

    ;for each dropped file, read file line by line and indent each line
    Loop, Parse, A_GuiControlEvent, `n
        { ;store time for speed measurement
            StartTime = %A_TickCount%

            ;file
            FileToautoIndent = %A_LoopField%

            ;reset start values
            Gosub, SetStartValues

            ;Read each line in the file and do indentation
            Loop, Read, %FileToautoIndent%
                { ;remember original line with its identation
                    AutoTrim, Off
                    Original_Line = %A_LoopReadLine%
                    AutoTrim, On

                    ;do indentation
                    Gosub, DoSyntaxIndentation
                }

            CaseCorrectSubsAndFuncNames()

            ;paste file with auto-indentation into new file
            ;  if Extension is empty, old file will be overwritten
            FileDelete, %FileToautoIndent%%Extension%
            FileAppend, %String%,%FileToautoIndent%%Extension%

            ;write information
            LogText = %LogText%缩进完成: %FileToautoIndent%`n
            If Statistic
                    Gosub, AddStatisticToLog
            Else
                    LogText = %LogText%`n
            GuiControl, ,Log , %LogText%
            ControlSend, %ClassLog%, ^{End}, %GuiUniqueID%
        }
    If Statistic {
            LogText = %LogText%=====统计:=======`n
            LogText = %LogText%=====所有文件====`n
            LogText = %LogText%代码行: %A_Tab%%A_Tab%%OverAllCodeLineCount%`n
            LogText = %LogText%注释行: %A_Tab%%OverAllCommentLineCount%`n
            LogText = %LogText%空白行: %A_Tab%%A_Tab%%OverAllEmptyLineCount%`n
            LogText = %LogText%总行数: %A_Tab%%OverAllTotalLineCount%`n
            ;time for speed measurement
            OverAllTimeNeeded := (A_TickCount - OverAllStartTime) / 1000
            LogText = %LogText%总处理时间: %A_Tab%%OverAllTimeNeeded%[s]`n`n
            GuiControl, ,Log , %LogText%
            ControlSend, %ClassLog%, ^{End}, %GuiUniqueID%
        }
Return

;#############   新增统计登录   ######################################
AddStatisticToLog:
    ;calculate lines of code
    CodeLineCount := TotalLineCount - CommentLineCount - EmptyLineCount

    OverAllCodeLineCount    += CodeLineCount
    OverAllTotalLineCount   += TotalLineCount
    OverAllCommentLineCount += CommentLineCount
    OverAllEmptyLineCount   += EmptyLineCount

    ;add information
    LogText = %LogText%=====统计:=====`n
    LogText = %LogText%代码行: %A_Tab%%A_Tab%%CodeLineCount%`n
    LogText = %LogText%注释行: %A_Tab%%CommentLineCount%`n
    LogText = %LogText%空行: %A_Tab%%A_Tab%%EmptyLineCount%`n
    LogText = %LogText%总行数: %A_Tab%%TotalLineCount%`n
    ;time for speed measurement
    TimeNeeded := (A_TickCount - StartTime) / 1000
    LogText = %LogText%处理时间: %A_Tab%%TimeNeeded%[s]`n`n
Return

;#############   命令行缩进文件  ##############################
IndentFile:
    ;set words for case correction
    Gosub, SetCaseCorrectionSyntax

    ;create indentation
    Gosub, CreateIndentSize

    ;file
    FileToautoIndent = %param_in%

    ;reset start values
    Gosub, SetStartValues

    ;Read each line in the file and do indentation
    Loop, Read, %FileToautoIndent%
        { ;remember original line with its identation
            AutoTrim, Off
            Original_Line = %A_LoopReadLine%
            AutoTrim, On

            ;do indentation
            Gosub, DoSyntaxIndentation
        }

    CaseCorrectSubsAndFuncNames()

    ;remove old file and paste with auto-indentation into same file
    FileDelete, %FileToautoIndent%
    FileAppend, %String%, %FileToautoIndent%

    ;write information to log file
    LogText = 缩进完成: %FileToautoIndent%`n
    If Statistic
            Gosub, AddStatisticToLog
    FileAppend , %LogText%, %param_log%
Return

;#############   创建下一个循环取决于IndentIndex的缩进  ##
SetIndentForNextLoop:
    ;clear
    Indent =
    If IndentIndex < 0            ;in case something went wrong
            IndentIndex = 0

    ;turn AutoTrim off, to be able to process tabs and spaces
    AutoTrim, Off

    ;Create indentation depending on IndentIndex
    Loop, %IndentIndex% {
            Increments := IndentIncrement%A_Index%
            Loop, %Increments%
                    Indent = %Indent%%IndentSize%
        }

    ;turn AutoTrim on, to remove leading and trailing tabs and spaces
    AutoTrim, On
Return

;#############   剥开线意见   ###################################
StripCommentsFromLine(Line) {
        StartPos = 1
        Loop {   ;go from semicolon to semicolon, start at 2nd position, First doesn't make sence, since it would be a comment
                StartPos := InStr(Line,";","",StartPos + 1)
                If (StartPos > 1) {
                        ;the following is not very robust but it will serve for most cases that a ";" is inside an := or () expression
                        ; limitations:
                        ; - comments that include a " on an := expression line
                        ; - comments that include a ") on an ()expression line
                        StringMid,CharBeforeSemiColon, Line, StartPos - 1 , 1
                        If (CharBeforeSemiColon = "``")            ;semicolon is Escaped
                                Continue
                        Else If ( 0 < InStr(Line,":=") AND InStr(Line,":=") < StartPos
                                AND 0 < InStr(Line,"""") AND InStr(Line,"""") < StartPos
                                AND 0 < InStr(Line,"""","",StartPos) )   ;It on the right side of an := expression and surounded with "..."
                                Continue
                        Else If ( 0 < InStr(Line,"(") AND InStr(Line,"(") < StartPos
                                AND InStr(Line,")","",StartPos) > StartPos
                                AND 0 < InStr(Line,"""") AND InStr(Line,"""") < StartPos
                                AND 0 < InStr(Line,"""","",StartPos) )    ;It is inside and () expression and surounded with "..."
                                Continue
                        Else {                                     ;it is a semicolon
                                StringLeft, Line, Line, StartPos - 1   ;get CommandLine up to semicolon
                                Line = %Line%                          ;remove Spaces
                                Return Line
                            }
                } Else   ;no more semicolon found, hence no comments on this line
                        Return Line
            }
    }

;#############   功能MemorizeIndent：列表存储缩进   ########
MemorizeIndent(Command,Increment,Index=0){
        global
        If (Index > 0)
                IndentIndex += %Index%
        Else If (Index < 0)
                IndentIndex := Abs(Index)
        IndentCommand%IndentIndex% = %Command%
        IndentIncrement%IndentIndex% = %Increment%
    }

;#############   执行语法对于每个给定的行缩进   #########
DoSyntaxIndentation:
    ;count line
    TotalLineCount ++

    ;##################################
    ;########### judge on line   ######
    ;##################################
    ;remove space and tabs from beginning and end of original line
    Line = %Original_Line%

    If Line is Space                ;nothing in line
        { String = %String%`n

            ;count line
            EmptyLineCount ++
            Gosub, FinishThisLine
            Return  ;Continue with next line
        }

    ;##################################
    ;########### 法官第一字符
    ;##################################
    ;get first and last characters of line
    StringLeft,  FirstChar    , Line, 1
    StringLeft,  FirstTwoChars, Line, 2

    FinishThisLine := False

    ;turn AutoTrim off, to be able to process tabs and spaces
    AutoTrim, Off

    If (FirstTwoChars = "*/") {          ;line is end of BlockComment
            String = %String%%Line%`n
            InBlockComment := False
            CommentLineCount ++
            FinishThisLine := True
        }

    Else If InBlockComment {              ;line is inside the BlockComment
            If KeepBlockCommentIndent
                    String = %String%%Original_Line%`n
            Else
                    String = %String%%Line%`n
            CommentLineCount ++
            FinishThisLine := True
        }

    Else If (FirstTwoChars = "/*") {          ;line is beginning of a BlockComment, end will be */
            String = %String%%Line%`n
            InBlockComment := True
            CommentLineCount ++
            FinishThisLine := True
        }

    Else If (FirstChar = ":") {                 ;line is hotstring
            String = %String%%Line%`n
            MemorizeIndent("Sub",1,-1)
            FinishThisLine := True
        }

    Else If (FirstChar = ";") {          ;line is comment
            String = %String%%Indent%%Line%`n
            CommentLineCount ++
            FinishThisLine := True
        }

    If FinishThisLine {
            Gosub, FinishThisLine
            Return  ;Continue with next line
        }

    ;turn AutoTrim back on
    AutoTrim, On

    ;##################################
    ;########### 法官命令/字
    ;##################################

    ;get pure command line
    StripedLine := StripCommentsFromLine(Line)

    ;get last character of CommandLine
    StringRight, LastChar     , StripedLine, 1

    ;get shortest first, second and third word of CommandLine
    Loop, 3
            CommandLine%A_Index% =
    StringReplace, CommandLine, StripedLine, %A_Tab%, %A_Space%,All
    StringReplace, CommandLine, CommandLine, `, , %A_Space%,All
    StringReplace, CommandLine, CommandLine, {, %A_Space%,All
    StringReplace, CommandLine, CommandLine, }, %A_Space%,All
    StringReplace, CommandLine, CommandLine, %A_Space%if(, %A_Space%if%A_Space%,All
    StringReplace, CommandLine, CommandLine, ), %A_Space%,All
    StringReplace, CommandLine, CommandLine, %A_Space%%A_Space%%A_Space%%A_Space%, %A_Space%,All
    StringReplace, CommandLine, CommandLine, %A_Space%%A_Space%%A_Space%, %A_Space%,All
    StringReplace, CommandLine, CommandLine, %A_Space%%A_Space%, %A_Space%,All
    CommandLine = %CommandLine%  ;remove Spaces from begining and end
    StringSplit, CommandLine, CommandLine, %A_Space%
    FirstWord  = %CommandLine1%
    SecondWord = %CommandLine2%
    ThirdWord  = %CommandLine3%

    ;get last character of First word
    StringRight, FirstWordLastChar,  FirstWord,  1

    ;check if previoulsly found function name is really a function definition
    ;if line is not start of bracket block but a funtion name exists
    If ( FirstChar <> "{" AND IndentIndex = 1 AND   FunctionName <> "") {
            FunctionName =         ; then that previous line is not a function definition.
            IndentIndex = 0         ; set back the indentation, which was previously set.
            Gosub, SetIndentForNextLoop
        }

    ;Assume line is not a function
    FirstWordIsFunction := False
    ;If no indentation and bracket not as first character it might be a function
    If ( IndentIndex = 0 And InStr(FirstWord,"(") > 0 )
            FirstWordIsFunction := ExtractFunctionName(FirstWord,InStr(FirstWord,"("),FunctionName)

    LineIsTabSpecialIndentStart := False
    LineIsTabSpecialIndent      := False
    LineIsTabSpecialIndentEnd   := False
    If (ChkSpecialTabIndent AND FirstWord = "Gui") {
            If (InStr(SecondWord,"add") And ThirdWord = "tab")
                    LineIsTabSpecialIndentStart := True
            Else If (InStr(SecondWord,"tab")) {
                    If ThirdWord is Space
                            LineIsTabSpecialIndentEnd := True
                    Else
                            LineIsTabSpecialIndent := True
                }
        }

    ;turn AutoTrim off, to be able to process tabs and spaces
    AutoTrim, Off

    ;###### 开始调整缩进 ##########

    If FirstWord in %ListOfDirectives%         ;line is directive
        { Loop, Parse, CaseCorrectionSyntax, `,
                    StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All
            String = %String%%Line%`n
        }
    Else If FirstChar in #,!,^,+,<,>,*,~,$     ;line is Hotkey (has be be after directives due to the #)
        { If InStr(FirstWord,"::"){
                    String = %String%%Line%`n
                    MemorizeIndent("Sub",1,-1)
                }
        }
    Else If (FirstChar = "," OR FirstTwoChars = "||" OR FirstTwoChars = "&&"
            OR FirstWord = "and" OR FirstWord = "or" )                     ;line is a implicit continuation
            String = %String%%Indent%%IndentContLine%%Line%`n
    Else If (FirstChar = ")" and InsideContinuation) {  ;line is end of a continuation block
            Gosub, SetIndentOfLastBracket
            String := String . Indent . iif(Style=1,"",IndentSize) . Line . "`n"
            ;IndentIndex doesn't need to be reduced, this is done inside SetIndentOfLastBracket
            InsideContinuation := False
        }
    Else If InsideContinuation {                ; line is inside a continuation block
            If AdjustContinuation
                    String = %String%%Indent%%Line%`n
            Else
                    String = %String%%Original_Line%`n
        }
    Else If (FirstChar = "(") {                 ;line is beginning of a continuation block
            String := String . Indent . iif(Style>1,IndentSize) . Line . "`n"
            MemorizeIndent("(",iif(Style=2,2,1),+1)
            AdjustContinuation := False
            If ( InStr(StripedLine, "LTrim") > 0 AND InStr(StripedLine, "RTrim0") = 0)
                    AdjustContinuation := True
            InsideContinuation := True                  ;allow nested cont磗
        }
    Else If LineIsTabSpecialIndentStart {                   ;line is a "Gui, Add, Tab" line
            String = %String%%Indent%%Line%`n
            MemorizeIndent("AddTab",1,+1)
        }
    Else If LineIsTabSpecialIndent {                        ;line is a "Gui, Tab, TabName" line
            Gosub, SetIndentOfLastAddTaborBracket
            String = %String%%Indent%%IndentSize%%Line%`n
            MemorizeIndent("Tab",1,+2)
        }
    Else If LineIsTabSpecialIndentEnd {                     ;line is a "Gui, Tab" line
            Gosub, SetIndentOfLastAddTaborBracket
            String = %String%%Indent%%Line%`n
        }
    Else If (FirstWordLastChar = ":") {   ;line is start of subroutine or Hotkey
            If (InStr(FirstWord,"::") = 0) {     ;line is start of a subroutine
                    StringTrimRight, SubroutineName, Line, 1
                    If SubroutineName not in %CaseCorrectSubsList%
                            CaseCorrectSubsList = %CaseCorrectSubsList%,%SubroutineName%
                }
            String = %String%%Line%`n
            MemorizeIndent("Sub",1,-1)
        }
    Else If (FirstChar = "}") {             ;line is end bracket block
            If (FirstWord = "else"){            ;it uses OTB and must be a "}[ ]else [xxx] [{]"
                    ;do the case correction
                    StringReplace, Line, Line, else, Else
                    Loop, Parse, CaseCorrectionSyntax, `,
                            StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

                    Gosub, SetIndentOfLastCurledBracket
                    IndentIndex --
                    Gosub, SetIndentOfLastIfOrOneLineIf

                    ;else line is also start of If-Statement
                    If SecondWord in %ListOfIFCommands%          ;Line is an old  If-statement
                        {
                            StringReplace, Line, Line, if, If
                            StringReplace, ParsedCommand, StripedLine, ```, ,,All
                            ;Search if a third comma exists
                            StringGetPos, ParsedCommand, ParsedCommand , `, ,L3
                            If ErrorLevel                           ;Line is an old If-statement
                                    MemorizeIndent("If",iif(Style=1,0,1),+1)
                    }Else If (SecondWord = "if") {              ;Line is a Normal if-statement
                            StringReplace, Line, Line, if, If
                            MemorizeIndent("If",iif(Style=1,0,1),+1)
                            If (LastChar = "{")                     ;it uses OTB
                                    MemorizeIndent("{",iif(Style=3,0,1),+1)
                    }Else If (SecondWord = "loop"){             ;Line is the begining of a loop
                            StringReplace, Line, Line, loop, Loop
                            MemorizeIndent("Loop",iif(Style=1,0,1),+1)
                            If (LastChar = "{")                     ;it uses OTB
                                    MemorizeIndent("{",iif(Style=3,0,1),+1)
                    }Else If SecondWord is Space                 ;just a plain Else
                        {
                            MemorizeIndent("Else",iif(Style=1,0,1),+1)
                            If (LastChar = "{")                     ;it uses OTB
                                    MemorizeIndent("{",iif(Style=3,0,1),+1)
                        }
                    ;if all the previous if didn't satisfy,
                    ; the Line is an else with any command following,
                    ;  then nothing has to be done
                    String = %String%%Indent%%Line%`n
            }Else {                               ;line is end bracket block without OTB
                    Gosub, SetIndentOfLastCurledBracket
                    String = %String%%Indent%%Line%`n
                    IndentIndex --
                }
        }
    Else If (FirstChar = "{") {                   ;line is start of bracket block
            ;check if line is start of a function implementation
            If ( IndentIndex = 1 AND  FunctionName <> "" )
                ;then add function name to list if not in it already
                    If FunctionName not in %CaseCorrectFuncList%
                            CaseCorrectFuncList = %CaseCorrectFuncList%,%FunctionName%(
                    ;clear function name
            FunctionName =

            IndentIndex ++
            IndentCommand%IndentIndex% = {
            IndentIncrement%IndentIndex% := iif(Style=3,0,1)

            ;check if command after { is if or loop
            If (FirstWord = "loop"){                   ;line is start of Loop block after the {
                    ;do the case correction
                    StringReplace, Line, Line, loop, Loop
                    Loop, Parse, CaseCorrectionSyntax, `,
                            StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

                    MemorizeIndent("Loop",iif(Style=1,0,1),+1)
                    If (LastChar = "{")                     ;it uses OTB
                            MemorizeIndent("{",iif(Style=3,0,1),+1)
                    ;assuming that there are no old one-line if-statements following a {
            }Else If FirstWord in %ListOfIFCommands%  ;line is start of old If-Statement after the {
                {
                    ;do the case correction
                    StringReplace, Line, Line, if, If, 1
                    Loop, Parse, CaseCorrectionSyntax, `,
                            StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

                    MemorizeIndent("If",iif(Style=1,0,1),+1)
            }Else If (FirstWord = "if"){                ;line is start of If-Statement after the {
                    ;do the case correction
                    StringReplace, Line, Line, if, If, 1
                    Loop, Parse, CaseCorrectionSyntax, `,
                            StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

                    MemorizeIndent("If",iif(Style=1,0,1),+1)
                    If (LastChar = "{")                     ;it uses OTB
                            MemorizeIndent("{",iif(Style=3,0,1),+1)
                }
            String = %String%%Indent%%Line%`n
        }
    Else If FirstWordIsFunction {                ;line is function
            String = %String%%Line%`n
            MemorizeIndent("Func",1,-1)

            If (LastChar = "{") {                 ;it uses OTB
                    If FunctionName not in %CaseCorrectFuncList%
                            CaseCorrectFuncList = %CaseCorrectFuncList%,%FunctionName%(
                    ;clear function name
                    FunctionName =

                    MemorizeIndent("{",iif(Style=3,0,1),+1)
                }
        }
    Else If (FirstWord = "loop") {         ;line is start of Loop block
            ;do the case correction
            StringReplace, Line, Line, loop, Loop
            Loop, Parse, CaseCorrectionSyntax, `,
                    StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

            PrevCommand := IndentCommand%IndentIndex%
            If (PrevCommand = "If"){               ;line is First line of a one-line If-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineIf",iif(Style=2,2,1))
            }Else If (PrevCommand = "Else"){         ;Line is First line of a one-line Else-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineElse",iif(Style=2,2,1))
            }Else If (PrevCommand = "Loop"){         ;Line is First line of a one-line loop-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineLoop",iif(Style=2,2,1))
            }Else {                              ;it follows a Sub , { , OneLineCommand or nothing
                    Gosub, SetIndentToLastSubBracketOrTab
                    String = %String%%Indent%%Line%`n
                }
            MemorizeIndent("Loop",iif(Style=1,0,1),+1)
            If (LastChar = "{")                  ;it uses OTB
                    MemorizeIndent("{",iif(Style=3,0,1),+1)
        }
    Else If FirstWord in %ListOfIFCommands% ;line is start of old If-Statement
        {
            ;do the case correction
            StringReplace, Line, Line, if, If
            Loop, Parse, CaseCorrectionSyntax, `,
                    StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

            PrevCommand := IndentCommand%IndentIndex%

            ;eliminate comments and escaped commas
            ParsedCommand := StripCommentsFromLine(Line)
            StringReplace, ParsedCommand, ParsedCommand, ```, ,,All
            ;Search if a third comma exists
            StringGetPos, ParsedCommand, ParsedCommand , `, ,L3
            If ( ErrorLevel = 0 ){                 ;Line is a old one-line If-statement
                    If (PrevCommand = "If"){           ;Line is a one-line command of an If-block
                            String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                            MemorizeIndent("OneLineIf",0)
                            MemorizeIndent("OneLineCommand",0,+1)
                    }Else If (PrevCommand = "Else"){       ;Line is a one-line command of an Else-block
                            String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                            MemorizeIndent("OneLineElse",0)
                            MemorizeIndent("OneLineCommand",0,+1)
                    }Else If (PrevCommand = "Loop"){       ;Line is a one-line command of a loop-block
                            String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                            MemorizeIndent("OneLineLoop",0)
                            MemorizeIndent("OneLineCommand",0,+1)
                    }Else {                            ;line is Normal one-line if-statement
                            Gosub, SetIndentToLastSubBracketOrTab
                            String = %String%%Indent%%Line%`n
                        }
            }Else {                              ;Line is not an one-line if-statement
                    If (PrevCommand = "If"){              ;Line is First line of an one-line If-block
                            String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                            MemorizeIndent("OneLineIf",iif(Style=2,2,1))
                    } Else If (PrevCommand = "Else"){       ;Line is First line of a one-line Else-block
                            String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                            MemorizeIndent("OneLineElse",iif(Style=2,2,1))
                    } Else If (PrevCommand = "Loop"){       ;Line is First line of a one-line loop-block
                            String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                            MemorizeIndent("OneLineLoop",iif(Style=2,2,1))
                    } Else {                             ;it follows a Sub , { , OneLineCommand or nothing
                            Gosub, SetIndentToLastSubBracketOrTab
                            String = %String%%Indent%%Line%`n
                        }
                    MemorizeIndent("If",iif(Style=1,0,1),+1)
                }
        }
    Else If (FirstWord = "if"){                  ;line is start of a Normal If-Statement
            ;do the case correction
            StringReplace, Line, Line, if, If
            Loop, Parse, CaseCorrectionSyntax, `,
                    StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

            PrevCommand := IndentCommand%IndentIndex%
            If (PrevCommand = "If"){              ;Line is First line of a one-line If-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineIf",iif(Style=2,2,1))
            } Else If (PrevCommand = "Else"){       ;Line is First line of a one-line Else-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineElse",iif(Style=2,2,1))
            } Else If (PrevCommand = "Loop"){       ;Line is First line of a one-line loop-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineLoop",iif(Style=2,2,1))
            } Else {                             ;it follows a Sub , { , OneLineCommand or nothing
                    Gosub, SetIndentToLastSubBracketOrTab
                    String = %String%%Indent%%Line%`n
                }
            MemorizeIndent("If",iif(Style=1,0,1),+1)
            If (LastChar = "{")                  ;it uses OTB
                    MemorizeIndent("{",iif(Style=3,0,1),+1)
        }
    Else If (FirstWord = "Else") {         ;line is a Else block
            ;do the case correction
            StringReplace, Line, Line, else, Else
            Loop, Parse, CaseCorrectionSyntax, `,
                    StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

            PrevCommand := IndentCommand%IndentIndex%
            If PrevCommand in OneLineCommand,Else
                    Gosub, SetIndentOfLastIfOrOneLineIf

            ;else line is also start of If-Statement
            If SecondWord in %ListOfIFCommands%          ;Line is an old  If-statement
                {
                    StringReplace, Line, Line, if, If
                    StringReplace, ParsedCommand, StripedLine, ```, ,,All
                    ;Search if a third comma exists
                    StringGetPos, ParsedCommand, ParsedCommand , `, ,L3
                    If ErrorLevel {                         ;Line is an old one-line If-statement
                            MemorizeIndent("If",1,+1)
                        }
            }Else If (SecondWord = "if"){               ;Line is a Normal if-statement
                    StringReplace, Line, Line, if, If
                    MemorizeIndent("If",iif(Style=1,0,1),+1)
                    If (LastChar = "{")                  ;it uses OTB
                            MemorizeIndent("{",iif(Style=3,0,1),+1)
            }Else If (Secondword = "loop"){             ;else is followed by a loop command
                    ;do the case correction
                    StringReplace, Line, Line, loop, Loop
                    MemorizeIndent("Loop",iif(Style=1,0,1),+1)
                    If (LastChar = "{")                  ;it uses OTB
                            MemorizeIndent("{",iif(Style=3,0,1),+1)
            }Else If SecondWord is Space                 ;just a plain Else
                { MemorizeIndent("Else",iif(Style=1,0,1),+1)
                    If (LastChar = "{")                  ;it uses OTB
                            MemorizeIndent("{",iif(Style=3,0,1),+1)
                }
            ;if all the previous if didn't satisfy,
            ; the Line is an else with any command following,
            ;  then nothing has to be done
            String = %String%%Indent%%Line%`n
        }
    Else {                                        ;line is a Normal command or Return
            ;do the case correction
            Loop, Parse, CaseCorrectionSyntax, `,
                    StringReplace, Line, Line, %A_LoopField%, %A_LoopField%, All

            PrevCommand := IndentCommand%IndentIndex%
            If (PrevCommand = "If"){             ;Line is a one-line command of an If-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineIf",0)
                    MemorizeIndent("OneLineCommand",0,+1)
            }Else If (PrevCommand = "Else"){      ;Line is a one-line command of an Else-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineElse",0)
                    MemorizeIndent("OneLineCommand",0,+1)
            }Else If (PrevCommand = "Loop"){      ;Line is a one-line command of a loop-block
                    String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
                    MemorizeIndent("OneLineLoop",0)
                    MemorizeIndent("OneLineCommand",0,+1)
            }Else If (PrevCommand = "Func"){      ;Line follows a function call   ??? is this ever True?
                    String = %String%%Line%`n
                    IndentIndex = 0
            }Else {                               ;line is Normal command or Return
                    Gosub, SetIndentToLastSubBracketOrTab
                    PrevCommand := IndentCommand%IndentIndex%

                    ;if command is end of subroutine (return) no indentation, otherwise keep indentation
                    If (FirstWord = "Return" AND PrevCommand = "Sub") {
                            String = %String%%Line%`n
                            IndentIndex = 0
                    }Else
                        ;String := String . Indent . iif(Style=2,IndentSize) . Line . "`n"
                            String = %String%%Indent%%Line%`n
                }
        }
    Gosub, FinishThisLine
Return

FinishThisLine:
    ;###### 改变缩进结束 ##########

    ;关闭自动配，回到默认行为
    AutoTrim, On

    ;显示MsgBox的调试
    If DebugMode
            Gosub, ShowDebugStrings

    ;得到下一个循环的缩进
    Gosub, SetIndentForNextLoop
Return


;#############   显示MsgBox的调试  ######################################
ShowDebugStrings:
    msgtext = line#: %TotalLineCount%`n
    msgtext = %msgtext%风格: %Style%`n
    msgtext = %msgtext%行: %Line%`n
    msgtext = %msgtext%删去行: %CommandLine%`n
    msgtext = %msgtext%缩进: |%Indent%|`n
    msgtext = %msgtext%第一个字符: >%FirstChar%<`n
    msgtext = %msgtext%第1个词: >%FirstWord%<`n
    msgtext = %msgtext%第2个词: >%SecondWord%<`n
    msgtext = %msgtext%第3个词: >%ThirdWord%<`n
    msgtext = %msgtext%第1个词最后一个字符: >%FirstWordLastChar%<`n
    msgtext = %msgtext%函数名称: >%FunctionName%<`n`n
    msgtext = %msgtext%索引缩进: %IndentIndex%`n
    ;msgtext = %msgtext%LineIsTabSpecialIndentStart: %LineIsTabSpecialIndentStart%`n
    ;msgtext = %msgtext%LineIsTabSpecialIndent: %LineIsTabSpecialIndent%`n
    ;msgtext = %msgtext%LineIsTabSpecialIndentEnd: %LineIsTabSpecialIndentEnd%`n`n
    msgtext = %msgtext%缩进1: %IndentIncrement1% - %IndentCommand1%`n
    msgtext = %msgtext%缩进: %IndentIncrement2% - %IndentCommand2%`n
    msgtext = %msgtext%缩进3: %IndentIncrement3% - %IndentCommand3%`n
    msgtext = %msgtext%缩进4: %IndentIncrement4% - %IndentCommand4%`n
    msgtext = %msgtext%缩进5: %IndentIncrement5% - %IndentCommand5%`n
    msgtext = %msgtext%缩进6: %IndentIncrement6% - %IndentCommand6%`n
    msgtext = %msgtext%缩进7: %IndentIncrement7% - %IndentCommand7%`n
    msgtext = %msgtext%缩进8: %IndentIncrement8% - %IndentCommand8%`n
    msgtext = %msgtext%缩进9: %IndentIncrement9% - %IndentCommand9%`n
    msgtext = %msgtext%缩进10: %IndentIncrement10% - %IndentCommand10%`n
    msgtext = %msgtext%缩进11: %IndentIncrement11% - %IndentCommand11%`n
    ;msgtext = %msgtext%`nDirectives: %ListOfDirectives%`n
    ;msgtext = %msgtext%`nIf-Commands: %ListOfIFCommands%`n
    ;msgtext = %msgtext%`nCommandNames: %CommandNames%`n
    ;msgtext = %msgtext%`nKeywords: %Keywords%`n
    ;msgtext = %msgtext%`nKeys: %Keys%`n
    ;msgtext = %msgtext%`nVariables: %Variables%`n
    ;msgtext = %msgtext%`nBuildInFunctions: %BuildInFunctions%`n
    ;msgtext = %msgtext%`nCaseCorrectFuncList: %CaseCorrectFuncList%`n

    MsgBox %msgtext%`n%String%
Return

;#############   设置IndentIndex的持续或onelineif  ##############
SetIndentOfLastIfOrOneLineIf:
    ;loop inverse through command array
    Loop, %IndentIndex% {
            InverseIndex := IndentIndex - A_Index + 2
            ;if command is if or onelineif, exit loop and remember the previous Index
            If IndentCommand%InverseIndex% in If,OneLineIf
                { IndentIndex := InverseIndex - 1
                    Break
                }
        }
    ;set indentation for that index
    Gosub, SetIndentForNextLoop
Return

;#############   的IndentIndex设置到最后卷曲支架  ##############
SetIndentOfLastCurledBracket:
    ;loop inverse through command array
    Loop, %IndentIndex% {
            InverseIndex := IndentIndex - A_Index + 1
            ;if command is bracket, exit loop and remember the previous Index
            If (IndentCommand%InverseIndex% = "{") {
                    IndentIndex := InverseIndex - 1
                    Break
                }
        }
    ;set indentation for that index
    Gosub, SetIndentForNextLoop
Return

;#############   设置IndentIndex去年支架  #####################
SetIndentOfLastBracket:
    ;loop inverse through command array
    Loop, %IndentIndex% {
            InverseIndex := IndentIndex - A_Index + 1
            ;if command is bracket, exit loop and remember the previous Index
            If (IndentCommand%InverseIndex% = "(") {
                    IndentIndex := InverseIndex - 1
                    Break
                }
        }
    ;set indentation for that index
    Gosub, SetIndentForNextLoop
Return

;#############  设置IndentIndex最后addtab  ######################
SetIndentOfLastAddTaborBracket:
    ;loop inverse through command array
    Loop, %IndentIndex% {
            InverseIndex := IndentIndex - A_Index + 1
            ;if command is AddTab, exit loop and remember the previous Index
            If IndentCommand%InverseIndex% in {,AddTab
                { IndentIndex := InverseIndex - 1
                    Break
                }
        }
    ;set indentation for that index
    Gosub, SetIndentForNextLoop
Return

;#############   设置IndenIndex，到最后一个子或支架   ###############
SetIndentToLastSubBracketOrTab:
    FoundItem:=False
    ;loop inverse through command array
    Loop, %IndentIndex% {
            InverseIndex := IndentIndex - A_Index + 1

            ;if command is sub or bracket, exit loop and remember the Index
            If IndentCommand%InverseIndex% in {,Sub
                { IndentIndex := InverseIndex
                    FoundItem:=True
                    Break
            }Else If ChkSpecialTabIndent
                    If IndentCommand%InverseIndex% in AddTab,Tab
                        { IndentIndex := InverseIndex
                            FoundItem:=True
                            Break
                        }
        }
    ;如果没有找到一套指数为零
    If ! FoundItem
            IndentIndex = 0

    ;set indentation for that index
    Gosub, SetIndentForNextLoop
Return

;#############   提取函数名称   #####################################
ExtractFunctionName(FirstWord,BracketPosition, ByRef FunctionName)  {
        ;get function name without braket
        StringLeft, FunctionName, FirstWord, % BracketPosition - 1

        If (FunctionName = "If")   ;it is a If statement "If(", empty FunctionName and function will Return 0
                FunctionName =

        ;check each char in name if it is allowed
        Loop, Parse, FunctionName
                If ( A_LoopField <> "_" )
                        If A_LoopField is not Alnum
                            { FunctionName =
                                Break
                            }
        Return StrLen(FunctionName)
    }

;#############   做CaseCorrection函数和子程序   ############
CaseCorrectSubsAndFuncNames() {
        global
        LenString := StrLen(String)

        ;remove first comma
        StringTrimLeft, CaseCorrectFuncList, CaseCorrectFuncList, 1
        StringTrimLeft, CaseCorrectSubsList, CaseCorrectSubsList, 1

        ;loop over all remembered function names
        Loop, Parse, CaseCorrectFuncList, CSV
            { FuncName := A_LoopField
                LenFuncName := StrLen(FuncName)

                ;Loop through string to find all occurances of function names
                StartPos = 0
                Loop {
                        StartPos := InStr(String,FuncName,0,StartPos + 1)
                        If (StartPos > 0) {
                                StringMid,PrevChar, String, StartPos - 1 , 1
                                If PrevChar is not Alnum
                                        ReplaceName( String, FuncName, StartPos-1, LenString - StartPos + 1 - LenFuncName )
                        } Else
                                Break
                    }
            }

        ;loop over all remembered subroutine names
        Loop, Parse, CaseCorrectSubsList, CSV
            { SubName := A_LoopField
                LenSubName := StrLen(SubName)

                ;Loop through string to find all occurances of function names
                StartPos = 0
                Loop {
                        StartPos := InStr(String,SubName,"",StartPos + 1)
                        If (StartPos > 0) {
                                StringMid,PrevChar, String, StartPos - 1 , 1
                                StringMid,NextChar, String, StartPos + LenSubName, 1

                                ;if it is an exact match the char after the subroutine names has not to be a char
                                If NextChar is not Alnum
                                    { ;If previous character is a "g" and has TestStrings in same line replace the name.
                                        If ( PrevChar = "g" ) {
                                                TestAndReplaceSubName( String, SubName, "Gui,", LenString, LenSubName, StartPos)
                                                TestAndReplaceSubName( String, SubName, "Gui ", LenString, LenSubName, StartPos)

                                                ;If previous character is something else then Alnum and has TestStrings in same line replace the name.
                                        }Else If PrevChar is not Alnum
                                            { TestAndReplaceSubName( String, SubName, "Gosub" , LenString, LenSubName, StartPos )
                                                TestAndReplaceSubName( String, SubName, "Menu"  , LenString, LenSubName, StartPos )
                                                TestAndReplaceSubName( String, SubName, "`:`:"  , LenString, LenSubName, StartPos )
                                                TestAndReplaceSubName( String, SubName, "Hotkey", LenString, LenSubName, StartPos )
                                            }
                                    }
                        } Else
                                Break
                    }
            }
    }

TestAndReplaceSubName( ByRef string, Name, TestString, LenString, LenSubName, StartPos ) {
        ;find Positions of Teststring and LineFeed in String from the right side starting at routine position
        StringGetPos, PosTestString, String, %TestString%, R , LenString - StartPos + 1
        StringGetPos, PosLineFeed  , String,     `n      , R , LenString - StartPos + 1

        ;If %TestString% is in the same line do replace name
        If ( PosLineFeed < PosTestString )
                ReplaceName( String, Name, StartPos - 1, LenString - StartPos + 1 - LenSubName )
    }

ReplaceName( ByRef String, Name, PosLeft, PosRight ) {
        ;split String up into left and right
        StringLeft, StrLeft, String, PosLeft
        StringRight, StrRight, String, PosRight

        ;insert Name into it again
        String = %StrLeft%%Name%%StrRight%
    }

;#############   ，如果桂关闭退出所有  #####################################
GuiClose:
    ;store current position and settings and exit app
    Gui, Show
    WinGetPos, PosX, PosY, SizeW, SizeH, %ScriptName%
    Gui, Submit
    IniWrite, x%PosX% y%PosY%, %IniFile%, General, Pos_Gui
    IniWrite, %Extension%, %IniFile%, Settings, Extension
    IniWrite, %Indentation%, %IniFile%, Settings, Indentation
    IniWrite, %NumberSpaces%, %IniFile%, Settings, NumberSpaces
    IniWrite, %NumberIndentCont%, %IniFile%, Settings, NumberIndentCont
    IniWrite, %IndentCont%, %IniFile%, Settings, IndentCont
    IniWrite, %Style%, %IniFile%, Settings, Style
    IniWrite, %CaseCorrectCommands%, %IniFile%, Settings, CaseCorrectCommands
    IniWrite, %CaseCorrectVariables%, %IniFile%, Settings, CaseCorrectVariables
    IniWrite, %CaseCorrectBuildInFunctions%, %IniFile%, Settings, CaseCorrectBuildInFunctions
    IniWrite, %CaseCorrectKeys%, %IniFile%, Settings, CaseCorrectKeys
    IniWrite, %CaseCorrectKeywords%, %IniFile%, Settings, CaseCorrectKeywords
    IniWrite, %CaseCorrectDirectives%, %IniFile%, Settings, CaseCorrectDirectives
    IniWrite, %Statistic%, %IniFile%, Settings, Statistic

    IniWrite, %ChkSpecialTabIndent%, %IniFile%, Settings, ChkSpecialTabIndent
    IniWrite, %KeepBlockCommentIndent%, %IniFile%, Settings, KeepBlockCommentIndent
    IniWrite, %AHKPath%, %IniFile%, Settings, AHKPath
    IniWrite, %OwnHotkey%, %IniFile%, Settings, OwnHotKey
ExitApp:
    ExitApp
Return
;#############   文件结束  #################################################
