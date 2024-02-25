#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

#define Op_SignBook     1           // op is "sign"
#define Op_ViewBook     2           // op is "view"

// Global storage

char    szBuffer[1024];             // generic input buffer
char    szDataFile[256];            // name of gb data file
char    szINIFile[256];             // config file name
char    szHeader[128];              // <h1> header to use
char    szBodyTag[128];             // body tag to use
char    szEmail[80];                // user's email address
char    szComments[512];            // user's comments
char    szName[80];                 // user's name

int     iOperation;                 // sign or view?
long    liFirstRecord;              // first entry to view
long    liHowMany;                  // how many to show


// SwapChar:  This routine swaps one character for another

void SwapChar(char * pOriginal, char cBad, char cGood) {
    int i;    // generic counter variable

    // Loop through the input string (cOriginal), character by
    // character, replacing each instance of cBad with cGood

    i = 0;
    while (pOriginal[i]) {
        if (pOriginal[i] == cBad) pOriginal[i] = cGood;
        i++;
    }
}

// IntFromHex:  A subroutine to unescape escaped characters.

static int IntFromHex(char *pChars) {
    int Hi;        // holds high byte
    int Lo;        // holds low byte
    int Result;    // holds result

    // Get the value of the first byte to Hi

    Hi = pChars[0];
    if ('0' <= Hi && Hi <= '9') {
        Hi -= '0';
    } else
    if ('a' <= Hi && Hi <= 'f') {
        Hi -= ('a'-10);
    } else
    if ('A' <= Hi && Hi <= 'F') {
        Hi -= ('A'-10);
    }

    // Get the value of the second byte to Lo

    Lo = pChars[1];
    if ('0' <= Lo && Lo <= '9') {
        Lo -= '0';
    } else
    if ('a' <= Lo && Lo <= 'f') {
        Lo -= ('a'-10);
    } else
    if ('A' <= Lo && Lo <= 'F') {
        Lo -= ('A'-10);
    }
    Result = Lo + (16 * Hi);
    return (Result);
}

// URLDecode -- un-URL-Encode a string.  This routine loops
// through the string pEncoded, and decodes it in place.  It
// checks for escaped values, and changes all plus signs to
// spaces.  The result is a normalized string.  It calls the
// two subroutines directly above in this listing.

void URLDecode(unsigned char *pEncoded) {
    char *pDecoded;          // generic pointer

    // First, change those pesky plusses to spaces
    
    SwapChar (pEncoded, '+', ' ');

    // Now, loop through looking for escapes
    
    pDecoded = pEncoded;
    while (*pEncoded) {
        if (*pEncoded=='%')
        {
            // A percent sign followed by two hex digits means
            // that the digits represent an escaped character.  We
            // must decode it.
        
            pEncoded++;
            if (isxdigit(pEncoded[0]) && isxdigit(pEncoded[1]))
            {
                *pDecoded++ = (char) IntFromHex(pEncoded);
                pEncoded += 2;
            }
        }
        else
        {
            *pDecoded ++ = *pEncoded++;
        }
    }
    *pDecoded = '\0';
}

// GetPOSTData:  Read in data from POST operation

void GetPOSTData() {
    char * pContentLength;  // pointer to CONTENT_LENGTH
    int  ContentLength;     // value of CONTENT_LENGTH string
    int  i;                 // local counter
    int  x;                 // generic char holder

    // Retrieve a pointer to the CONTENT_LENGTH variable

    pContentLength = getenv("CONTENT_LENGTH");

    // If the variable exists, convert its value to an integer
    // with atoi()

    if (pContentLength != NULL)
    {
    	ContentLength = atoi(pContentLength);
    }
    else
    {
    	ContentLength = 0;
    }

    // Make sure specified length isn't greater than the size
    // of our statically-allocated buffer

    if (ContentLength > sizeof(szBuffer)-1)
    {
    	ContentLength = sizeof(szBuffer)-1;
    }

    // Now read ContentLength bytes from STDIN
    
    i = 0;
    while (i < ContentLength)
    {
    	x = fgetc(stdin);
    	if (x==EOF) break;
    	szBuffer[i++] = x;
    }

    // Terminate the string with a zero
    
    szBuffer[i] = '\0';

    // And update ContentLength
    
    ContentLength = i;
}

// PrintMIMEHeader:  Prints content-type header

void PrintMIMEHeader() {
    // This is the basic MIME header for the
    // CGI.  Note that it is a 2-line header,
    // including a "pragma: no-cache" directive.
    // This keeps the page from being cached,
    // and reduces the number of duplicate
    // entries from users who keep hitting the
    // submit button over and over
    printf("Content-type: text/html\n");
    printf("Pragma: no-cache\n");
    printf("\n");

}

// PrintHTMLHeader:  Prints HTML page header

void PrintHTMLHeader() {
    printf(
        "<html>\n"
        "<head><title>sgb1.c</title></head>\n"
        "<body %s>\n"
        "%s\n",
        szBodyTag,szHeader
        );
}

// PrintHTMLTrailer:  Prints closing HTML info

void PrintHTMLTrailer() {
    printf(
        "</body>\n"
        "</html>\n"
        );
}
    
// ProcessPair:  Processes a var=val pair

void ProcessPair (char * VarVal) {
    char * pEquals;	          // pointer to equals sign

    // Find the equals sign separating Var from Val
    pEquals = strchr(VarVal, '=');

    // If equals sign is found....
    if (pEquals != NULL)
    {
        // terminate the Var name 
        *pEquals++ = '\0'; 

        // decode the Varname (*VarVal)
        URLDecode(VarVal);

        // and the value (*pEquals)
        URLDecode(pEquals);

        if (stricmp(VarVal,"email")==0)
        {
            // copy into szEmail global variable, being
            // careful not to overflow the variable

            strncpy(szEmail,pEquals,sizeof(szEmail)-1);
        }
        
        else if (stricmp(VarVal,"comments")==0)
        {
            // copy into szComments global variable, being
            // careful not to overflow the variable

            strncpy(szComments,pEquals,sizeof(szComments)-1);
        }
        
        else if (stricmp(VarVal,"name")==0)
        {
            // copy into szName global variable, being
            // careful not to overflow the variable

            strncpy(szName,pEquals,sizeof(szName)-1);
        }
    }
}

// FilterHTML -- removes any HTML tags from data
// This routine removes any <> tags found in the
// szData string.  If we didn't remove these tags,
// malicious (or silly) visitors could wreak havoc
// with our guestbook data, or possibly execute a
// SSI or CGI command to get at private data

void FilterHTML (char *szData) {
    char    *pOpenAngle;
    char    *pCloseAngle;
    while (TRUE)
    {

        // Find an opening angle bracket
        pOpenAngle = strchr(szData,'<');
        
        // If none, all done here
        if (pOpenAngle==NULL) break;

        // Otherwise, look for the closing angle bracket
        pCloseAngle = strchr(pOpenAngle,'>');

        // If we found a closing angle bracket, snug
        // up all the characters after it, thus removing
        // the tag entirely from the string
        
        if (pCloseAngle)
        {
            strcpy(pOpenAngle,pCloseAngle+1);
        }
        
        // If no closing angle bracket, then the visitor
        // has provided invalid HTML, so truncate at the
        // opening bracket
        else
        {
            *pOpenAngle = '\0';
        }
    }
}


// FormatGBEntry -- formats GB entry

void FormatGBEntry() {
    char        szTmp[128]; // work buffer
    SYSTEMTIME  st;         // holds system time
    char        *p;         // generic pointer        

    // clear out the buffer area
    
    ZeroMemory(szBuffer,sizeof(szBuffer));

    // start each entry with an <hr> tag
    
    strcpy(szBuffer,"<hr>\r\n");

    // fill in default if visitor left
    // the name field blank

    if (*szName == '\0') strcpy(szName, szEmail);
    
    // Remove any unwanted characters from the visitor parms
    
    FilterHTML(szName);
    FilterHTML(szEmail);
    FilterHTML(szComments);
    
    // replace any CRs or LFs in the comments
    // from the visitor with spaces
    SwapChar(szComments,'\r',' ');
    SwapChar(szComments,'\n',' ');
        

    // add the visitor's comments, if any
    if (*szComments != '\0')
    {
        // make the visitor comments bold italic
        strcat(szBuffer,"<b><i>");
        strcat(szBuffer,szComments);
        strcat(szBuffer,"</i></b><br>");
    }
    

    // if email is blank, but name isn't, use name
    
    if ((*szEmail=='\0') && (*szName !='\0'))
    {
        sprintf(szTmp,"%s",szName);
        strcat(szBuffer,szTmp);
    }
    
    // if email and name are blank, say "anonymous"
    
    else if ((*szEmail=='\0') && (*szName =='\0'))
    {
        strcat(szBuffer,"Anonymous Visitor");
    }

    // else use email address in a mailto tag
    
    else
    {
        strcat(szBuffer,"<a href=mailto:");
        sprintf(szTmp,"\"%s\">%s</a>",szEmail,szName);
        strcat(szBuffer,szTmp);
    }
    
    // whatever name we have so far, add " signed the
    // guestbook on " to it
    
    strcat(szBuffer," signed the guestbook on ");

    // now add the date and time
    
    GetLocalTime(&st);
    GetDateFormat(0,0,&st,"ddd dd MMM yyyy",szTmp,sizeof(szTmp));
    strcat(szBuffer,szTmp);
    sprintf(szTmp," at %02d:%02d:%02d, ",
        st.wHour,st.wMinute,st.wSecond);
    strcat(szBuffer,szTmp);
    
    // now add the visitor's IP address and browser, if
    // available

    p = getenv("HTTP_USER_AGENT");
    if (p)
    {
        sprintf(szTmp,"using %s",p);
        strcat(szBuffer,szTmp);
    }

    p = getenv("REMOTE_ADDR");
    if (p)
    {
        sprintf(szTmp," from %s",p);
        strcat(szBuffer,szTmp);
    }

    p = getenv("REMOTE_HOST");
    if (p)
    {
        sprintf(szTmp," (%s)",p);
        strcat(szBuffer,szTmp);
    }

    // always add a <br> tag and CRLF at the end
    
    strcat(szBuffer,"<br>\r\n");
}

// AppendToGB -- appends new entry to gb file

void AppendToGB() {
    int         iWaitForIt;         // generic counter
    HANDLE      hFile;              // file handle
    BOOL        bSuccess;           // success indicator
    DWORD       dwBytesWritten;     // num bytes written
    DWORD       dwNumBytes;         // generic counter

    // First, format the entry
    
    FormatGBEntry();

    // Now inform the user

    printf("Thank you for signing the "
        "Guestbook!  Here is your entry:"
        "<br>%s\n",szBuffer);

    // Set up a counter/loop.  We'll use the iWaitForIt
    // variable as our counter, and we'll go through the
    // loop up to 100 times.

    for (iWaitForIt = 0; iWaitForIt < 100; iWaitForIt++)
    {

        // Each time within the loop, we'll try to get
        // exclusive read-write access to the log file.

        hFile = CreateFile (
            szDataFile,                   
            GENERIC_READ | GENERIC_WRITE, // read-write
            0,              // no sharing!
            0,              // no special security
            OPEN_ALWAYS,    // create if not there
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_WRITE_THROUGH,
            0
            );
        
        // If we were able to open the file, proceed with
        // the business of writing the log entry

        if (hFile != INVALID_HANDLE_VALUE)
        {

            // This is an append operation, so we want to
            // position the file pointer to the end of the
            // file.

            SetFilePointer (hFile,0L,0L,FILE_END);

            //Write out the entry now

            dwNumBytes = sizeof(szBuffer);
            bSuccess = WriteFile (
                hFile,
                szBuffer,
                dwNumBytes,
                &dwBytesWritten,
                0
                );

            // And close the file, releasing the locks, so
            // another thread (or external process) can
            // access the file

            CloseHandle (hFile);

            // If the write operation was successful, and
            // the number of bytes written equals the number
            // of bytes we wanted to write, all done here

            if ( (bSuccess) && (dwNumBytes == dwBytesWritten))
            {
                
                printf("<hr>\n");
                printf(
                    "<a href=\"%s"
                    "?op=view&first=0&howmany=%li\">"
                    "View the Complete Guestbook"
                    "</a>\n",
                    getenv("SCRIPT_NAME"),
                    liHowMany
                    );
                return;
            }
            else
            {
                printf("Could not write to file.  "
                       "Error code %d\n",GetLastError());
                return;
            }
         }

         // Control comes here if the CreateFile call above
         // failed.  We don't care why it failed at the 
         // moment.  Instead, we'll just sleep for 100 milliseconds
         // and try again (up to 100 times, or 10 seconds).  A
         // more robust routine would call GetLastError() to find
         // out WHY the open failed.  If it's anything other than
         // file is busy right now, we should exit the loop instead
         // of trying again.

         else
         {
             Sleep(100);
         }
    }

    // If we never could get access to the file, 
    // tell caller we failed

    printf("Couldn't open file.");
    return;
}

// ProcessPOSTData:  Processes data from POST buffer.
// This routine splits up the Var & Val pairs, calls
// ProcessPair() to handle the data, then calls
// AppendtoGB() to write the new record to disk.

void ProcessPOSTData() {
    char    * pToken;           // pointer to token separator
    
    // Find the first "&" token in the string
    pToken = strtok(szBuffer,"&");
    
    // If any tokens in the string
    while (pToken != NULL)
    {

        // Process the pair of tokens (var=val)
        ProcessPair (pToken);

        // And look for the next "&" token
        pToken = strtok(NULL,"&");
    }
    
    // Now append the data to the guestbook file
    AppendToGB();
}

// PrintGBEntries -- print out the contents of the guestbook

BOOL PrintGBEntries() {
    int         iWaitForIt;         // generic counter
    HANDLE      hFile;              // file handle
    BOOL        bSuccess;           // success indicator
    DWORD       dwBytesRead;        // num bytes written
    DWORD       dwNumBytes;         // generic counter
    DWORD       dwLastError;        // hold last err code
    DWORD       dwLoWord;           // file size lo word
    DWORD       dwHiWord;           // file size hi word
    long        liRecordNumber;           // record number
    long        liTotalRecords;
    long        dwNumPrinted = 0;    // num printed so far    

    // First, print a link to allow the visitor to sign
    // the guestbook.  A sign operation is accomplished
    // by invoking the script with the GET method (an
    // <a href...> link, with a query string of "sign"

    printf("<a href=\"%s"
           "?op=sign\">"
           "Sign the Guestbook"
           "</a><p>\n",
           getenv("SCRIPT_NAME")
           );

    // Set up a counter/loop.  We'll use the iWaitForIt
    // variable as our counter, and we'll go through the
    // loop up to 100 times.
    
    for (iWaitForIt = 0; iWaitForIt < 100; iWaitForIt++)
    {

        // Each time within the loop, we'll try to get
        // non-exclusive read access to the log file.

        hFile = CreateFile (
            szDataFile,                   
            GENERIC_READ,       // read-only 
            FILE_SHARE_READ,    // let others read, too
            0,                  // no special security
            OPEN_EXISTING,      // fail if not there
            FILE_ATTRIBUTE_NORMAL,
            0
            );
        
        // If we were unable to open the file, find out why
        
        if (hFile == INVALID_HANDLE_VALUE)
        {
            dwLastError = GetLastError();
            switch (dwLastError)
            {
                case ERROR_FILE_NOT_FOUND:

                    // file doesn't exist

                    return FALSE;

                case ERROR_SHARING_VIOLATION:
                case ERROR_LOCK_VIOLATION:

                    // file is busy
                    // so sleep for .1 second
                
                    Sleep(100);
                    break;

                default:
                
                    // some other fatal error
                    // we don't care what; just
                    // exit
                
                    return FALSE;
            }
        }
        else
        {
            // At this point, the file is open for read
            // Loop through backwards, starting with
            // liFirstRecord, for liHowMany records
            
            dwLoWord = GetFileSize(hFile,&dwHiWord);
            liTotalRecords = dwLoWord / sizeof(szBuffer);

            if ((liFirstRecord==0) || (liFirstRecord > liTotalRecords))
                liFirstRecord = liTotalRecords;

            liRecordNumber = liFirstRecord;

            if (liTotalRecords==0)      // if no records at all
            {
                CloseHandle(hFile);
                return TRUE;
            }
                
            if ((liRecordNumber - liHowMany) > 0)
            {
                // not starting at beginning of
                // file, so print a link for "View
                // Earlier Records"
                liFirstRecord = liRecordNumber - liHowMany;
                if (liFirstRecord < 1) liFirstRecord = 1;
                
                printf("<a href=\"%s"
                    "?op=view&first=%li&howmany=%li\">"
                    "Earlier Records"
                    "</a> &nbsp;",
                    getenv("SCRIPT_NAME"),
                    liFirstRecord,
                    liHowMany
                    );
            }
            
            if (liRecordNumber!=liTotalRecords)
            {
                // not starting at end of file,
                // so print a link for "View Later
                // "Records"
                liFirstRecord = liRecordNumber + liHowMany;
                if (liFirstRecord > liTotalRecords)
                    liFirstRecord = liTotalRecords;

                printf("<a href=\"%s"
                    "?op=view&first=%li&howmany=%li\">"
                    "Later Records"
                    "</a> &nbsp;",
                    getenv("SCRIPT_NAME"),
                    liFirstRecord,
                    liHowMany
                    );
            }

            printf("<p>\n");

            while (dwNumPrinted < liHowMany)
            {
             
                liRecordNumber--;     // record numbers are zero-based

                SetFilePointer (
                    hFile,
                    liRecordNumber * sizeof(szBuffer),
                    0L,
                    FILE_BEGIN
                    );

                dwNumBytes = sizeof(szBuffer);
                bSuccess = ReadFile (
                    hFile,
                    szBuffer,
                    dwNumBytes,
                    &dwBytesRead,
                    0
                    );
            
                if ( (bSuccess==FALSE) || (dwBytesRead==0))
                {

                    // file is done, or there was an error

                    break;
                }
                else
                {

                    // print out what we got

                    dwNumPrinted++;
                    szBuffer[dwBytesRead]='\0';
                    printf(szBuffer);
                    printf("(Record #%d of %d)<br>",
                        liRecordNumber+1,
                        liTotalRecords
                        );
                    if (liRecordNumber==0) break;
                }

            } // end of while loop
            
            CloseHandle(hFile);
            return TRUE;

        } // end of if hFILE test

    } // end of for loop

    return FALSE;
 }

// PrintForm -- prints the fill-in form at the head of the
// guestbook display

void PrintForm() {
    
    // This is a self-referencing form.  That is, it takes the
    // name of the script from the SCRIPT_NAME environment
    // variable, and creates a form to reinvoke the script using
    // the POST method

    printf("<b>Won't you please sign the guestbook?</b><p>\n");
    printf("<ul>\n");
    printf("<form method=POST action=\"%s\">\n",getenv("SCRIPT_NAME"));
    printf("Your name:  ");
    printf("<input type=TEXT name=name  size=30 maxlength=80><br>\n");
    printf("Your email address:  ");
    printf("<input type=TEXT name=email size=30 maxlength=80><br>\n");
    printf("Your comments:<br>\n");
    printf("<textarea rows=3 cols=40 name=comments>\n");
    printf("</textarea><p>\n");
    printf("<input type=submit value=\" Submit \"><br>\n");
    printf("</form>\n<p>\n");
    printf("</ul>");

    // And add a link to view the guestbook instead, so the
    // visitor doesn't have to mess with the browser's back
    // button.  Use the query string to set the operation and
    // some sensible numbers.

    printf("<a href=\"%s"
           "?op=view&first=0&howmany=%li\">"
           "View the Guestbook"
           "</a><p>\n",
           getenv("SCRIPT_NAME"),
           liHowMany
           );
}

// ProcessINIFile -- get info from config file
void GetINIValues() {
    char        szTmp[128];
    SYSTEMTIME  st;
    
    
    // We'll need the date & time later, so
    // go ahead and format the string now.
    // We'll stuff it in szBuffer, the
    // generic I/O buffer
    
    GetLocalTime(&st);
    GetDateFormat(0,0,&st,"ddd dd MMM yyyy",
        szBuffer,sizeof(szBuffer));
    sprintf(szTmp," at %02d:%02d:%02d",
        st.wHour,st.wMinute,st.wSecond);
    strcat(szBuffer,szTmp);
    
    // Get the body tag
    
    GetPrivateProfileString(
        "Settings",         // section name
        "BodyTag",          // entry name
        "",                 // default value
        szBodyTag,          // return value
        sizeof(szBodyTag),  // max length
        szINIFile
        );

    if (*szBodyTag=='\0')
        strcpy(szBodyTag,
            "bgcolor=#FEFEFE "
            "text=#000000 "
            "link=#000040 "
            "alink=FF0040 "
            "vlink=#7F7F7F"
            );

    // Get the header

    GetPrivateProfileString(
        "Settings",         // section name
        "Header",           // entry name
        "",                 // default value
        szHeader,           // return value
        sizeof(szHeader),   // max length
        szINIFile
        );

    if (*szHeader=='\0')
        strcpy(szHeader,
            "<h1><i>CGI by Example</i></h1>"
            "<b>sgb2.c</b> -- demonstration CGI written "
            "in C to make a simple guestbook<p>"
            );

    // Get default number for liHowMany
  
    GetPrivateProfileString(
        "Settings",
        "HowMany",
        "10",
        szTmp,
        sizeof(szTmp),
        szINIFile
        );

    if (*szTmp != '\0')
    {
        liHowMany = atol(szTmp);
        if (liHowMany < 1) liHowMany = 1;
        if (liHowMany > 999) liHowMany = 999;
    }

    // If the guestbook has never been accessed
    // before, write the default entries into the
    // config file, to make things easier for the
    // webmaster (why look up names of optional
    // parms, when the program can just tell you?)
    
    GetPrivateProfileString(
        "Info",             // section name
        "First Access",     // entry name
        "",                 // default
        szTmp,              // return value
        sizeof(szTmp),      // max length
        szINIFile
        );

    if (*szTmp=='\0')
    {
        
        // szBuffer has the date & time
        // so write that out as the
        // First Access entry
        
        WritePrivateProfileString(
            "Info","First Access",
            szBuffer,szINIFile);

        // More info -- mention the path
        // and filename of the datafile

        WritePrivateProfileString(
            "Info","DataFile",
            szDataFile,szINIFile);

        // Write out the settings --
        // BodyTag and Header

        WritePrivateProfileString(
            "Settings","BodyTag",
            szBodyTag,szINIFile);

        WritePrivateProfileString(
            "Settings","Header",
            szHeader,szINIFile);

        WritePrivateProfileString(
            "Settings","HowMany",
            ltoa(liHowMany,szTmp,10),
            szINIFile);
    }

    // Whether or not we've been accessed
    // before, we want to keep track of
    // THIS access.  Write it out to the
    // Last Access entry.  The date & time
    // is still in szBuffer

    WritePrivateProfileString(
        "Info","Last Access",
        szBuffer,szINIFile);
}

    
void DecodeQueryString() {
    char    *pQueryString;      // pointer to QUERY_STRING
    char    *p;                 // generic pointer

    iOperation = 0;             // undefined value
    liFirstRecord = 0;            // first entry to view

    pQueryString = getenv("QUERY_STRING");

    // If query string absent, or op = view, set
    // the operation to view
    
    if ( (pQueryString==NULL) ||    // no query string
        (*pQueryString=='\0'))      // query string blank
    {
        iOperation = Op_ViewBook;
        return;
    }

    _strlwr(pQueryString);

    if (strstr(pQueryString,"op=view"))
    {
        iOperation = Op_ViewBook;
    }
    
    // else if op = sign, set operation to sign

    else if (strstr(pQueryString,"op=sign"))
    {
        iOperation = Op_SignBook;
    }

    // Look for first=xx in the query string
    
    p = strstr(pQueryString,"first=");
    if (p)
    {
        strcpy(szBuffer,p+6);
        p = strchr(szBuffer,'&');
        if (p) *p = '\0';
        liFirstRecord = atol(szBuffer);
        if (liFirstRecord < 0) liFirstRecord = 0;
    }

    // Look for howmany=xx in the query string
    
    p = strstr(pQueryString,"howmany=");
    if (p)
    {
        strcpy(szBuffer,p+8);
        p = strchr(szBuffer,'&');
        if (p) *p = '\0';
        liHowMany = atol(szBuffer);
        if (liHowMany < 1) liHowMany = 1;
        if (liHowMany > 999) liHowMany = 999;
    }
 }
    
// The script's entry point

void main() {

    char    *pRequestMethod;    // pointer to REQUEST_METHOD
    char    szOurPath[128];     // our script's path
    char    szScriptName[80];   // exe name of script
    char    *p;                 // generic pointer

    // Figure out where the config file is.  We have defined
    // it to be in the same directory as the script, and with
    // the same first name as the script.  Its last name is
    // .ini.

    // Use C's _pgmptr variable to get the script's path
    
    strcpy(szOurPath,_pgmptr);

    // Find the last slash in our name, which will be the one
    // separating the path from the filename

    p = strrchr(szOurPath,'\\');

    // If slash found, we have both the path and
    // the script's exe name handy
    if (p)
    {
        // first, terminate the path name
        *p = '\0';

        // what remains is the exe name
        strcpy(szScriptName,++p);
    }
    else
    {
        // Otherwise, no path, just script name
        strcpy(szScriptName,szOurPath);
        *szOurPath = '\0';
    }

    // If path doesn't end with a slash, add one
    if (szOurPath[strlen(szOurPath)] != '\\')
        strcat(szOurPath,"\\");
    
    // Remove the extension from the script name
    p = strrchr(szScriptName,'.');
    if (p) *p = '\0';        
    
    // Now we have the path, so make the config
    // file name, and the data file name

    sprintf(szINIFile,"%s%s.ini",
        szOurPath,
        szScriptName
        );
    
    sprintf(szDataFile,"%s%s.dat",
        szOurPath,
        szScriptName);

    // Now read in the values from the config file
    GetINIValues();

    // Set STDOUT to unbuffered

    setvbuf(stdout,NULL,_IONBF,0);

    // Zero out the global variables

    ZeroMemory(szEmail,sizeof(szEmail));
    ZeroMemory(szComments,sizeof(szComments));
    ZeroMemory(szName,sizeof(szName));
        
    // Figure out how we were invoked, and determine what
    // to do based on that

    pRequestMethod = getenv("REQUEST_METHOD");

    if (pRequestMethod==NULL) {

        // No request method; must have been invoked from
        // command line.  Print a message and terminate.

        printf("This program is designed to run as a CGI script, "
               "not from the command line.\n");

    }
    
    else if (stricmp(pRequestMethod,"GET")==0) {

        // Request-method was GET; this means we should
        // print out the guestbook

        PrintMIMEHeader();      // Print MIME header
        PrintHTMLHeader();      // Print HTML header

        // We can do two things on a GET -- either
        // print out the form (a "sign" operation),
        // or print out the guestbook's entries (a
        // "view" operation).  We figure out which
        // by looking at the QUERY_STRING environment
        // variable

        DecodeQueryString();    // decode QUERY_STRING

        if (iOperation==Op_SignBook)
            PrintForm();
        
        else if (iOperation==Op_ViewBook)
            PrintGBEntries();
        
        else
            printf("Unknown operation specified.");
                
        PrintHTMLTrailer();     // Print HTML trailer
    }

    else if (stricmp(pRequestMethod,"POST")==0) {

        // Request-method was POST; this means we should
        // parse the input and create a new entry in
        // the guestbook

        PrintMIMEHeader();      // Print MIME header
        PrintHTMLHeader();      // Print HTML header
        GetPOSTData();          // Get POST data to szBuffer
        ProcessPOSTData();      // Process the POST data
        PrintHTMLTrailer();     // Print HTML trailer
    }

    else
    {

        // Request-method wasn't null, but wasn't GET or
        // POST either.  Output an error message and die

        PrintMIMEHeader();      // Print MIME header
        PrintHTMLHeader();      // Print HTML header
        printf("Only GET and POST methods supported.\n");
        PrintHTMLTrailer();     // Print HTML trailer
    }

    // Finally, flush the output & terminate

    fflush(stdout);
    return;
}
