Attribute VB_Name = "ShopCart"
Option Explicit
DefInt A-Z


' ----- Some constants used throughout the script

Const txtTitle = "CGI by Example -- Shopping Cart Demo"
Const txtHeader = "<i>CGI by Example</i><br>Shopping Cart Demo<hr>"

' ----- A global variable, holding the choice made when
'       the user last clicked a button

Dim Choice As String


' ----- The type-declaration for our purchase array.
'       This array holds the purchase info while the
'       user is browsing around

Type PurchaseLine
    Item        As String
    Quantity    As Integer
    Price       As Currency
End Type

' ----- Declare a dynamic array of type PurchaseLine

Dim Purchases() As PurchaseLine

'
' Control comes here when a visitor clicks the
' "check out" button on any form.
'
Sub CheckOut()
    ' One local variable
    Dim OrderTotal As Currency
    
    ' Display the order and get the total
    OrderTotal = ShowOrders()
    
    ' Now print the form for user charge card
    ' info
    
    ' First the <form...> line
    Out "<form method=POST action="
    Out Q(cgiGetScript()) + ">" + vbCrLf
    
    ' Now the state information, if any.
    ' We include it again here because the
    ' visitor may decide to go back and change
    ' an item
    Out "<input type=hidden name=baggage value="
    PrintArray
    Out ">" + vbCrLf
    
    ' Now the total amount, since we don't want
    ' to have to calculate it again
    Out "<input type=hidden name=Amount value="
    Out Q(Format$(OrderTotal, "0.00"))
    Out ">" + vbCrLf
    
    ' Now the charge card info fields
    ' The visitor may have been to this screen
    ' before, so examine the CGI environment
    ' variables and fill in any defaults we
    ' can
    
    Out "<pre>"
    
    Out "       Your Name: <input type=text "
    Out "name=name size=30 value="
    Out Q(cgiGetEnv("name")) + "><br>"
    
    Out "    Your Address: <input type=text "
    Out "name=addr size=30 value="
    Out Q(cgiGetEnv("addr")) + "><br>"
    
    Out "Your Credit Card: <select name=card>:"
    Out "<option>Visa"
    Out "<option>Mastercard"
    Out "<option>Discover"
    Out "</select><br>"
    
    Out " Expiration Date: <input type=text "
    Out "name=expd size=5 value="
    Out Q(cgiGetEnv("expd")) + "><br>"

    Out "     Card Number: <input type=text "
    Out "name=numb size=30 value="
    Out Q(cgiGetEnv("numb")) + "><br>"

    Out "</pre>"
        
    ' Now the submit buttons
    Out "<input type=submit name=Choice value="
    Out Q(" I Want to Change My Order ") + ">" + vbCrLf
    
    Out "<input type=submit name=Choice value="
    Out Q(" Charge My Credit Card ") + ">" + vbCrLf
    
    ' End the form
    Out "</form>"
    
End Sub

'
' Control comes here after the visitor has clicked
' the "charge me!" button on the check out form
'
Sub Finishup()

    ' Some local variables to hold the input
    ' from the check out form
    
    Dim Name As String
    Dim Addr As String
    Dim Card As String
    Dim Expd As String
    Dim Numb As String
    Dim Amount As Currency
    
    ' A local variable to hold error messages
    Dim ErrMsg As String
        
    ' Retrieve the variable values
    
    Name = cgiGetEnv("Name")
    Addr = cgiGetEnv("Addr")
    Card = cgiGetEnv("Card")
    Expd = cgiGetEnv("Expd")
    Numb = cgiGetEnv("Numb")
    Amount = Val(cgiGetEnv("Amount"))
    
    ' Let's do some validation before going on
    
    If Amount = 0 Then
        ErrMsg = "Order is for zero dollars."
    
    ElseIf Name = "" Then
        ErrMsg = "You didn't fill in your name."
        
    ElseIf Addr = "" Then
        ErrMsg = "You didn't fill in your address."
        
    ElseIf Card = "" Then
        ErrMsg = "You didn't select a credit card."
        
    ElseIf Expd = "" Then
        ErrMsg = "You didn't fill in your "
        ErrMsg = ErrMsg + " card's expiration date."
        
    ElseIf Numb = "" Then
        ErrMsg = "You didn't give your card number."
        
    End If
    
    ' A real shopping cart system would want to
    ' validate the expiration date, and run some
    ' consistency checks against the credit card
    ' number before going on.
    
    If ErrMsg <> "" Then
        ErrMsg = ErrMsg + "<br>Please correct the "
        ErrMsg = ErrMsg + "problem and try again."
        cgiHeader ErrMsg, 2
        CheckOut
    Else
        cgiHeader "Thanks!", 2
        Out "Thanks for using our online Fresh "
        Out "Fruit Order form!  We will charge your "
        Out Card + " card in the amount of "
        Out Format$(Amount, "$0.00") + " and "
        Out "deliver your fruit to " + Addr
        Out " within 24 hours."
    End If
End Sub

'
' This routine takes all the entries in the
' Purchases() array and prints them out as
' one long string.  This is the baggage we
' carry with us from form to form.
'
Sub PrintArray()
    Dim x As Integer
    
    ' Put the baggage in quotation marks
    Out Chr$(34)
    
    ' Loop through the array, appending
    ' each bit of each element of the array
    ' so that we can undecode it later on
    
    For x = 1 To UBound(Purchases, 1)
        ' Don't print out deleted items!
        ' Deleted items are marked by having
        ' the Item be blank
        If Purchases(x).Item > "" Then
            ' Quantity plus a slash
            Out Format$(Purchases(x).Quantity) + "/"
            ' Price plus a comma
            Out Format$(Purchases(x).Price) + "/"
            ' Item description plus a semi-colon
            Out "" + Purchases(x).Item + ";"
        End If
    Next x
    
    ' Closing quotation mark, please
    Out Chr$(34)
End Sub

'
' This routine retrieves the state information (baggage)
' and pops it into our dynamic Purchases() array.
'
Sub BaggageToArray()

    ' Some local variables
    
    Dim x As Integer
    Dim Thing As String
    Dim Quantity As Integer
    Dim Tmp As String
    Dim TotItems As Integer
    Dim Price As Currency
    
    ' No items so far, and the array has zero elements
    
    TotItems = 0
    ReDim Purchases(TotItems)
    
    ' Grab the state information baggage from the CGI
    ' environment variable called 'baggage'
    
    Tmp = cgiGetEnv("Baggage")
       
    ' While any baggage left, process it....
    
    While Len(Tmp)
    
        ' Look for a record separator (a semi-colon)
        x = InStr(Tmp, ";")
        
        ' If found, split out the record
        
        If x Then
            ' What thing is this?
            Thing = Left(Tmp, x - 1)
            
            ' Remove the thing from the baggage
            Tmp = Trim(Mid(Tmp, x + 1))
            
            ' Default quantity and price
            Quantity = 1
            Price = 0
            
            ' Look through the item desc for a slash
            x = InStr(Thing, "/")
            
            ' The first one we find separates the
            ' quantity from the price
            If x Then
                Quantity = Val(Left(Thing, x - 1))
                Thing = Mid(Thing, x + 1)
            End If
            
            ' Find the next slash
            x = InStr(Thing, "/")
            
            ' This one separates the price from
            ' the item description
            If x Then
                Price = Val(Left(Thing, x - 1))
                Thing = Mid(Thing, x + 1)
            End If
            
            ' Add another item to the array of
            ' items
            TotItems = TotItems + 1
            ReDim Preserve Purchases(TotItems)
            Purchases(TotItems).Quantity = Quantity
            Purchases(TotItems).Item = Thing
            Purchases(TotItems).Price = Price
        End If
    Wend
End Sub

'
' Control comes here on a GET operation (the first
' time the script is invoked.  Control also comes
' here every time a POST operation decides to print
' the order form again.
'
Sub CreateForm()

    ' First, show the current orders
    ShowOrders
        
    ' Now print the order form, so the visitor
    ' can pick items to order
    
    ' First the <form...> line
    Out "<form method=POST action="
    Out Q(cgiGetScript()) + ">" + vbCrLf
    
    ' Now the state information, if any
    Out "<input type=hidden name=baggage value="
    PrintArray
    Out ">" + vbCrLf
        
    Out "Fresh Fruits you can buy:<br>"
    ' Now the Fruit options
    Out "<select name=Item>"
    Out "<option>Apple $0.25 ea"
    Out "<option>Orange $0.24 ea"
    Out "<option>Mango $0.75 ea"
    Out "<option>Banana $0.23 ea"
    Out "<option>Kiwi $1.19 ea"
    Out "<option>Plastic Bag (free)"
    Out "</select>"
    
    ' Now the quantity
    Out "  How many? "
    Out "<input type=text name=Quantity "
    Out "size=3 value=1 maxlength=3>"
    Out "<p>"
    
    ' Now the submit buttons
    Out "<input type=submit name=Choice value="
    Out Q(" Add to Cart ") + ">" + vbCrLf
    
    Out "<input type=submit name=Choice value="
    Out Q(" Remove from Cart ") + ">" + vbCrLf
    
    Out "<input type=submit name=Choice value="
    Out Q(" Check Out ") + ">" + vbCrLf
    
    ' End the form
    Out "</form>"
    
    
End Sub
Sub Main()
    Dim x As Integer
    
    ' Standard startup stuff
    
    cgiStartup
    
    ' Output the title
    
    cgiTitle txtTitle
    
    ' Output the body tag
    
    Out "<body>" + vbCrLf
    
    ' Output the level 1 header
    
    cgiHeader txtHeader
    
    
    ' If this is a POST operation, then
    ' the CGI variable 'Choice' will reflect
    ' the caption of the button last clicked.
    ' Retrieve that variable now, and trim
    ' all but the first word
    
    Choice = Trim(cgiGetEnv("Choice"))
    x = InStr(Choice, " ")
    If x Then Choice = Left(Choice, x - 1)
    Choice = UCase(Choice)
    
    ' If this is a repeat operation of any
    ' sort, then we'll have all sorts of state
    ' information baggage tucked up inside the
    ' form.  Get it out of the CGI variable and
    ' into an array where we can deal with it
    ' decently and in order
    
    BaggageToArray
        
    ' Now, depending on how the script was
    ' invoked, go do something with all this
    ' information!
    
    Select Case UCase(cgiGetEnv("REQUEST_METHOD"))
        Case "GET"
            CreateForm
        Case "POST"
            ProcessForm
    End Select
    
    ' Do the standard shutdown stuff
    
    cgiShutdown
End Sub

'
' Control comes here any time the script is invoked
' with the POST method.  Depending on what button was
' clicked to cause the POST, this routine does
' different things
'
Sub ProcessForm()

    ' Some local variables used for handling
    ' the input and manipulating the Purchases()
    ' array
    Dim Items As Integer
    Dim Thing As String
    Dim Bucks As Currency
    Dim x As Integer
    Dim FoundInCart As Integer
    Dim Qty As Integer
 
    
    ' Examine the CGI environment variable 'choice'
    ' and take appropriate action.  This variable is
    ' set by clicking on a button, and the Main()
    ' routine cleans it up for us.
    
    If Choice = "ADD" Then

        ' Visitor selected something and clicked on
        ' Add to Cart, so do that thing
        
        Items = UBound(Purchases, 1)
       
        ' What thing does the visitor want to buy?
        
        Thing = cgiGetEnv("Item")
        
        ' How many of 'em?
        
        Qty = Val(cgiGetEnv("Quantity"))
        
        ' Did tricksy visitor say zero or negative?
        ' If not, go ahead, otherwise ignore
        
        If Qty > 0 Then
            ' Item descriptions contain the price
            ' (if there is a price) and indicate it
            ' with a dollar sign
            
            x = InStr(Thing, "$")   ' Free item?
            
            ' Item is not free if $ is present
            If x Then
                Bucks = Val(Mid(Thing, x + 1))
                Thing = Trim(Left(Thing, x - 1))
            Else
                Bucks = 0
            End If
            
            ' See if visitor already has some of
            ' this thing; if so, just adjust the
            ' quantity
            
            FoundInCart = False
            For x = 1 To Items
                If Purchases(x).Item = Thing Then
                    Purchases(x).Quantity = Purchases(x).Quantity + Qty
                    FoundInCart = True
                    Exit For
                End If
            Next x
             
            ' If not Found In Cart, then add a new
            ' item to the Purchases() array
            
            If Not FoundInCart Then
                Items = Items + 1
                ReDim Preserve Purchases(Items)
                Purchases(Items).Item = Thing
                Purchases(Items).Price = Bucks
                Purchases(Items).Quantity = Qty
            End If
            
        End If
        CreateForm  ' back for more
    
    ElseIf Choice = "REMOVE" Then
    
        ' Visitor selected some item and clicked
        ' Remove from Cart, so let's do that
        
        Items = UBound(Purchases, 1)
       
        ' What thing shall we remove?
        
        Thing = cgiGetEnv("Item")
        
        ' How many must go away?
        Qty = Val(cgiGetEnv("Quantity"))
        
        ' Say, is that a positive number > zero?
        
        If Qty > 0 Then
            ' If so, see if the thing is in the
            ' cart already; otherwise ignore
            
            x = InStr(Thing, "$")
            If x Then Thing = Trim(Left(Thing, x - 1))
            
            For x = 1 To Items
                If Purchases(x).Item = Thing Then
                    Purchases(x).Quantity _
                        = Purchases(x).Quantity - Qty
                    If Purchases(x).Quantity < 1 _
                        Then Purchases(x).Item = ""
                    Exit For
                End If
            Next x
        End If
        CreateForm  ' back for more

    ElseIf Choice = "CHECK" Then
        ' Visitor is done shopping and wants to
        ' check out.  Go do that thing
        CheckOut
        
    ElseIf Choice = "CHARGE" Then
        ' Visitor filled in the Check Out form
        ' and said "Charge me, Momma!"
        ' Go validate the input and take his
        ' money away from him!
        Finishup
        
    Else
        ' ignore unknown choices
        ' just reprint the form
        CreateForm
    End If
End Sub

'
' This routine prints out a table showing all the
' pending line items in the order, and also
' calculates the subtotal, tax, and grand total.
'
Function ShowOrders() As Currency

    ' A few local variables
    Dim x As Integer
    Dim Items As Integer
    Dim Total As Currency
    Dim LineTotal As Currency
    Dim SubTotal As Currency
    Dim Tax As Currency
    Dim TaxRate As Single
    
    ' A hard-coded tax rate!
    TaxRate = 0.0525
    
    ' Initialize the variables
    Total = 0
    SubTotal = 0
    Tax = 0
    
    Items = UBound(Purchases, 1)
    
    ' Output the table headers
    Out "<table border=3 cellpadding=3 width=90%>"
    Out "<caption>"
    Out "Fresh Fruits in Your Shopping Cart"
    Out "</caption>"
    Out "<tr>"
    Out "<th align=center>Qty</th>"
    Out "<th align=left width=30>Item</th>"
    Out "<th align=right>Unit Price</th>"
    Out "<th align=right>Subtotal</th>"
    Out "<p></tr>"
    
    ' Loop through the items in the array
    ' and print each line item
    For x = 1 To Items
        ' Don't print deleted items!
        If Purchases(x).Item > "" Then
            
            ' Calculate the total for this line
            ' (Quantity * Price each)
            LineTotal = _
                Purchases(x).Price * Purchases(x).Quantity
            
            ' Keep a running subtotal of all line
            ' items so far
            SubTotal = SubTotal + LineTotal
            
            ' Print the table row for this line
            ' item
            
            Out "<tr>"
            
            Out "<td align=center>"
            Out Format$(Purchases(x).Quantity)
            Out "</td>"
            
            Out "<td align=left>"
            Out Purchases(x).Item
            Out "</td>"
            
            Out "<td align=right>"
            Out Format$(Purchases(x).Price, "$0.00")
            Out "</td>"
            
            Out "<td align=right>"
            Out Format$(LineTotal, "$0.00")
            Out "</td>"
            
            Out "<p></tr>"
            
        End If
    Next x
    
    ' If the tax rate isn't zero, then we have to
    ' calculate the tax and show three lines --
    ' subtotal, tax, and grand total
    
    If TaxRate > 0 Then
        Tax = SubTotal * TaxRate
        Total = SubTotal + Tax

        Out "<tr>"
        Out "<td align=right colspan=3>"
        Out "SubTotal</td>"
        Out "<td align=right>"
        Out Format$(SubTotal, "$0.00")
        Out "</td>"
        Out "<p></tr>"
    
        Out "<tr>"
        Out "<td align=right colspan=3>"
        Out "Tax ("
        Out Format$(TaxRate, "0.0##%")
        Out ")</td>"
        Out "<td align=right>"
        Out Format$(Tax, "$0.00")
        Out "</td>"
        Out "<p></tr>"
    Else
        Total = SubTotal
    End If
    
    Out "<tr>"
    Out "<td align=right colspan=3>"
    Out "<b>Total</b></td>"
    Out "<td align=right><b>"
    Out Format$(Total, "$0.00")
    Out "</b></td>"
    Out "<p></tr>"
    Out "</table>"
    
    ShowOrders = Total
End Function


