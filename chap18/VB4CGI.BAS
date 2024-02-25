Attribute VB_Name = "vb4cgi"
Option Explicit
DefInt A-Z

' vb4cgi.bas, version 960628
' Copyright (c) 1996 Greyware Automation Products
' Permission granted to use and modify this file
' for your own projects.  You may not redistribute
' a modified version of this file.  Please send
' updates or revisions to (with complete source)
' techsupport@greyware.com.

' Include this file with your VB4 project.

' ----- Variables local to this module
    
    Dim Env() As String                     ' array to hold environment variables
    Dim hOut As Long                        ' handle to output file
    
' ----- Global variables

    Global CWD As String                    ' Working directory name
    Global PragmaNoCache As Integer         ' If TRUE, "Pragma: no-cache" is sent as part of header
    Global ContentType As String            ' If blank, defaults to "content-type: text/html"

' ----- Functions for STDIO

Declare Function GetStdHandle _
    Lib "Kernel32" _
    ( _
    ByVal nStdHandle As Long _
    ) As Long

Declare Function ReadFile _
    Lib "Kernel32" _
    ( _
        ByVal hFile As Long, _
        lpBuffer As Any, _
        ByVal nNumberOfBytesToRead As Long, _
        lpNumberOfBytesRead As Long, _
        lpOverlapped As Any _
    ) As Long

Declare Function WriteFile _
    Lib "Kernel32" _
    ( _
        ByVal hFile As Long, _
        ByVal lpBuffer As String, _
        ByVal nNumberOfBytesToWrite As Long, _
        lpNumberOfBytesWritten As Long, _
        lpOverlapped As Any _
    ) As Long

Declare Function GetEnvironmentVariable _
    Lib "Kernel32" _
    Alias "GetEnvironmentVariableA" _
    ( _
        ByVal bsName As String, _
        ByVal buff As String, _
        ByVal ch As Long _
    ) As Long

Public Const STD_INPUT_HANDLE = -10&
Public Const STD_OUTPUT_HANDLE = -11&

'
' This routine dumps all env variables to the output
'
Sub cgiDumpEnv()
    Dim x As Integer
    cgiHeader "CGI Environment Variables", 3
    Out "Default Directory=" + CurDir$ + "<br>"
    Out "Current Working Directory=" + CWD + "<br>"
    Out "This script: " + cgiGetScript() + "<br>"
    Out "<ul>"
    For x = 1 To UBound(Env, 1)
        Out "<li>" + Env(x)
    Next x
    Out "</ul>"
End Sub

'
' Prints error message and exits; does not return to calling routine
'
Sub cgiErrExit(ErrMsg As String)
    cgiTitle "CGI Application Problem"
    cgiHeader "CGI Application Problem", 1
    Out "<body>"
    cgiHeader ErrMsg, 3
    cgiShutdown
End Sub

'
' Returns value of env variable 'var'
'
Function cgiGetEnv(var As String) As String
    Dim x As Integer
    Dim QV As String
    
    On Error Resume Next
    
    ' env variables are stores as token=value, so set up QV to match the token= part
    QV = Trim(UCase(var) + "=")
    
    ' Loop through each env variable until match is found, or array exhausted
    For x = 1 To UBound(Env, 1)
        If Left(UCase(Env(x)), Len(QV)) = QV Then
            cgiGetEnv = Mid(Env(x), Len(QV) + 1)
            Exit Function
        End If
    Next x
End Function

'
' Returns name of running script
'
Function cgiGetScript() As String
    Dim x As Integer
    Dim Tmp As String
    On Error Resume Next
    
    ' First, retrieve contents of SCRIPT_NAME
    ' variable, passed to us by the server
    
    Tmp = cgiGetEnv("script_name")
    
    ' Make sure any path separators are in
    ' proper URL format
    cgiSwapChar Tmp, "\", "/"
    
    ' Some servers pass complete paths,
    ' including the driver letter.  If this
    ' is the case, get rid of the drive
    ' reference
    
    If Mid(Tmp, 2, 2) = ":/" Then
        x = InStr(4, Tmp, "/")
        If x Then Tmp = Mid(Tmp, x + 1)
    End If
    
    ' Return result to caller
    cgiGetScript = Tmp
End Function

'
' Outputs a header.  Call with 'cgiHeader "Level One Header", 1' etc.
'
Sub cgiHeader(txt As String, Optional Level As Variant)
    Dim HeadingLevel As String
    
    If IsMissing(Level) Then
        HeadingLevel = "1"
    Else
        HeadingLevel = Format$(Level)
    End If
    
    Out "<H" + HeadingLevel + ">" + txt + "</H" + HeadingLevel + ">" + vbCrLf
End Sub

'
' Normal shutdown procedure; does not return to caller
'
Sub cgiShutdown()
    On Error Resume Next
    ' add any shutdown code you want here
    Out "</body>" + vbCrLf + "</html>" + vbCrLf
    ' then let VB4 clean up & terminate
    End
End Sub

'
' Main CGI startup routine.  Your program's Sub Main() should call this routine
' at startup, and call cgiShutdown or cgiErrExit to terminate.
'
' There are two variables your Sub Main() may set before calling cgiStartup():
'    ContentType -- if non-blank, cgiStartup will use this as your content-type header
'    PragmaNoCache -- if TRUE, cgiStartup will tell browsers not to cache your page
' You may leave these variables alone and accept the defaults most of the time.
'
Sub cgiStartup()
    Dim x As Integer            ' generic local counter
    Dim EnvCount As Integer     ' local counter of environment variables
    Dim Tmp As String
    Dim Content_Length As Long
    Dim lpszBuf As String
    Dim lBytesRead As Long
    Dim lResult As Long
    
    On Error Resume Next
    
    ' output the standard headers unless told otherwise
    If ContentType = "" Then
        ContentType = "Content-Type: text/html"
    End If
    
    Out ContentType + vbCrLf    ' start with Content_Type always!
    
    If PragmaNoCache Then
        Out "Pragma: no-cache" + vbCrLf
    End If
    
    Out "" + vbCrLf             ' terminate header with blank line
    
    ' define constants & such
    CWD = App.Path              ' Current Working Directory (not necessarily CurDir$)
    If Right(CWD, 1) <> "\" Then
        CWD = CWD + "\"
    End If
    
    ' initialize the Env() array
    ReDim Env(0)
    EnvCount = 0
    
    ' fill in first variables with real environment variables
    Do
        Tmp = Environ$(EnvCount + 1)
        If Tmp = "" Then Exit Do
        EnvCount = EnvCount + 1
        ReDim Preserve Env(EnvCount)
        Env(EnvCount) = Tmp
    Loop
        
    ' now retrieve anything in the query string or stdin
    lpszBuf = ""
    Select Case UCase(cgiGetEnv("REQUEST_METHOD"))
        
        Case "POST"
            Content_Length = Val(cgiGetEnv("CONTENT_LENGTH"))
            If Content_Length > 0 Then
                lpszBuf = String$(Content_Length + 1, 0)
                lBytesRead = Content_Length
                lResult = ReadFile( _
                    GetStdHandle(STD_INPUT_HANDLE), _
                    ByVal lpszBuf, _
                    Content_Length, _
                    lBytesRead, _
                    ByVal 0& _
                    )
                
                If lResult Then
                    lpszBuf = Left(lpszBuf, lBytesRead)
                Else
                    lpszBuf = ""
                End If
            
            End If
        
        Case "GET"
            lpszBuf = cgiGetEnv("QUERY_STRING")
        
        Case Else
            cgiErrExit "Request_Method must be either GET or POST"
    
    End Select
    
    ' parse out lpszBuf into separate variables
    Do
        x = InStr(lpszBuf, "&")
        If x Then
            EnvCount = EnvCount + 1
            ReDim Preserve Env(EnvCount)
            Env(EnvCount) = cgiURLDecode(Left(lpszBuf, x - 1))
            lpszBuf = Mid(lpszBuf, x + 1)
        End If
    Loop While x
    
    If Len(lpszBuf) Then
        EnvCount = EnvCount + 1
        ReDim Preserve Env(EnvCount)
        Env(EnvCount) = cgiURLDecode(lpszBuf)
    End If
    
End Sub

'
' searches through string 'source' replacing every instance of
' 'char1' with 'char2' -- char1 and char2 may be any length
'
Sub cgiSwapChar(source As String, char1 As String, char2 As String)
    Dim x As Long
    Dim tmp1 As String, tmp2 As String

    ' make sure char1 and char2 are different
    If InStr(char2, char1) = 0 Then
        Do
            x = InStr(source, char1)
            If x Then
                tmp1 = Left(source, x - 1)
                tmp2 = Mid(source, x + Len(char1))
                source = tmp1 + char2 + tmp2
            End If
        Loop While x
    End If
End Sub

'
' Outputs the standard <head><title>blah-blah-blah</title></head> text.
' For good form, you should include a <body> tag immediately after calling
' this function, and a </body> tag just before calling cgiShutdown.
'
Sub cgiTitle(txt As String)
    Out "<HEAD><TITLE>" + txt + "</TITLE></HEAD>" + vbCrLf
End Sub

'
' Decodes %xx escapes and plus signs; does NOT change / to \
'
Function cgiURLDecode(iTxt As String) As String
    Dim x As Integer, i As Integer
    Dim oTxt As String
    On Error Resume Next
    
    oTxt = iTxt   ' work on a copy of the string
    
    ' first fix all the plus signs
    Do
        x = InStr(oTxt, "+")
        If x Then Mid(oTxt, x, 1) = " "
    Loop While x
        
    ' now fix the %xx escapes
    x = 0
    Do
        x = InStr(x + 1, oTxt, "%")
        If x Then
            i = Val("&H" + Mid(oTxt, x + 1, 2))
            If i Then
                oTxt = Left(oTxt, x - 1) + Chr$(i) + Mid(oTxt, x + 3)
            End If
        End If
    Loop While x
    cgiURLDecode = oTxt
End Function

'
' This function URL-encodes a string
'
Function cgiURLEncode(iTxt As String) As String
    Dim x As Integer, i As Integer
    Dim oTxt As String
    Dim TwoHex As String
    On Error Resume Next
    
    ' Change all spaces to plusses, and escape
    ' anything not A-Z or a-z
    
    For x = 1 To Len(iTxt)
        i = Asc(Mid(iTxt, x, 1))
        If i = Asc(" ") Then
            oTxt = oTxt + "+"
        ElseIf i < Asc("A") Or i > Asc("z") Then
            TwoHex = Hex$(i)
            If Len(TwoHex) = 1 Then TwoHex = "0" + TwoHex
            oTxt = oTxt + "%" + TwoHex
        Else
            oTxt = oTxt + Chr$(i)
        End If
    Next x
    
    ' return encoded string to caller
    cgiURLEncode = oTxt
End Function

'
' Sends txt to the output
'
Sub Out(txt As String)
    Dim lResult As Long
    
    WriteFile _
        GetStdHandle(STD_OUTPUT_HANDLE), _
        txt, _
        Len(txt), _
        lResult, _
        ByVal 0&
    
    Debug.Print txt
End Sub

'
' Converts string with pathname to string with url-encoded pathname
'
Function PathToURL(txt As String) As String
    Dim Tmp As String
    Tmp = txt
    cgiSwapChar Tmp, "\", "/"
    cgiSwapChar Tmp, " ", "+"
    PathToURL = Tmp
End Function

'
' Returns 'txt' surrounded by double-quote marks
'
Function Q(txt As String) As String
    Q = Chr$(34) + txt + Chr$(34)
End Function

