Attribute VB_Name = "modConfig"
'
'
'
Public iniFileName As String

'
' Loads categories from the main .ini file
'
Public Function LoadCategories( _
  tvTree As TreeView, _
  Optional strRoot As String = "root", _
  Optional tvParentNode As Node = Nothing _
) As Long

  On Error GoTo Error

  ' Empty the categories tree
  tvTree.Nodes.Clear

  ' Load top-level categories, skipping the first (root) level category
  LoadCategory tvTree, "cat.root", Nothing, 1

  LoadCategories = 0
  Exit Function

Error:
  modError.ReportError "Unable to load categories from '" & iniFileName & "'."
Error_silent:
  LoadCategories = -1
End Function

'
'
'
Private Sub LoadCategory( _
  tvTree As TreeView, _
  strKey As String, _
  tvParentNode As Node, _
  ByVal lngSkip As Long _
)
  ' Get the category's name
  Dim strText As String
  strText = StrDecode(modIniFile.ReadIniString(iniFileName, strKey, "name"))

  ' Create this category in the tree (unless we have to skip some levels)
  Dim tvThisNode As Node
  If lngSkip > 0 Then
    lngSkip = lngSkip - 1
    Set tvThisNode = tvParentNode
  Else
    Set tvThisNode = modTreeUtil.AddNode(tvTree, tvParentNode, strText, strKey)
  End If

  ' Get the number of sub-elements that exist
  Dim numItems As Long
  numItems = Val(modIniFile.ReadIniString(iniFileName, strKey, "count"))

  ' Create each sub-category
  For i = 0 To numItems - 1
    Dim itemValue As String
    itemValue = modIniFile.ReadIniString(iniFileName, strKey, "item" & Format$(i))

    If LCase$(Left$(itemValue, 4)) = "cat." Then
      LoadCategory tvTree, itemValue, tvThisNode, lngSkip
    End If
  Next
End Sub

'
'
'
Public Function GetLastSelectedCategory( _
  tvTree As TreeView _
) As Node
  Set GetLastSelectedCategory = modTreeUtil.GetNodeByKey(tvTree, modIniFile.ReadIniString(modConfig.iniFileName, "general", "lastCat"))
End Function

'
' Allocates a uniquely identifying key (for either categories or
'  applications, based on prefix) inside the main INI file
'
Private Function AllocateKey( _
  strPrefix As String _
)

  Dim strKey As String

  For i = 0 To &H7FFFFFFF
    strKey = Hex(i)
    strKey = Mid$("00000000", Len(strKey) + 1) & strKey

    If Len(ReadIniSection(iniFileName, strPrefix & strKey)) < 1 Then
      AllocateKey = strPrefix & strKey
      Exit Function
    End If
  Next

  AlloateKey = ""
  Exit Function
End Function

'
' Adds a category to the category tree and main INI file
'
Public Function AddCategory( _
  tvTree As TreeView, _
  tvParentNode As Node, _
  strText As String _
) As Node

  On Error GoTo Error

  Dim strKey As String
  strKey = modConfig.AllocateKey("cat.")

  modIniFile.WriteIniString iniFileName, strKey, "count", "0"
  modIniFile.WriteIniString iniFileName, strKey, "name", StrEncode(strText)
  
  Dim strParentKey As String
  If tvParentNode Is Nothing Then
    strParentKey = "cat.root"
  Else
    strParentKey = tvParentNode.Key
  End If

  Dim numItems As Long
  numItems = Val(modIniFile.ReadIniString(iniFileName, strParentKey, "count"))
  modIniFile.WriteIniString iniFileName, strParentKey, "count", Format$(numItems + 1)
  modIniFile.WriteIniString iniFileName, strParentKey, "item" & Format$(numItems), strKey

  Set AddCategory = modTreeUtil.AddNode(tvTree, tvParentNode, strText, strKey)
  Exit Function

Error:
  modError.ReportError "Unable to create category '" & strText & "'."
  Set AddCategory = Nothing
End Function

'
' Attempts to rename a category.  If the function is successful, the
'  function returns zero, otherwise (e.g. if the category name already
'  exists), it returns a non-zero value.
' If the renaming is successful, it is mirrored in the .ini configuration file.
'
Public Function RenameCategory( _
  tvTree As TreeView, _
  tvNode As Node, _
  ByVal strNewText As String _
) As Integer

  Dim strOldText As String
  strOldText = tvNode.Text

  On Error GoTo Error

  ' Attempt to rename the current node (assuming the new key is unique)
  If modTreeUtil.RenameNode(tvTree, tvNode, strNewText) <> 0 Then
    RenameCategory = 1  ' return, duplicate name
  Else
    ' Rename category inside .ini file
    modIniFile.WriteIniString iniFileName, tvNode.Key, "name", StrEncode(strNewText)

    RenameCategory = 0  ' return, the node was successfully renamed
  End If
  Exit Function

Error:
  modError.ReportError "Unable to rename category to '" & strNewText & "'."
  On Error Resume Next
  modTreeUtil.RenameNode tvTree, tvNode, strOldText ' roll back changes
  RenameCategory = -1
End Function

'
'
'
Public Function DeleteCategory( _
  tvTree As TreeView, _
  tvNode As Node _
) As Long

  On Error GoTo Error

  Dim strKey As String
  strKey = tvNode.Key

  Dim strParentKey As String

  If tvNode.Parent Is Nothing Then
    strParentKey = "cat.root"
  Else
    strParentKey = tvNode.Parent.Key
  End If

  If DeleteCategory_Helper(strKey, strParentKey) <> 0 Then
    LoadCategories tvTree ' an error resulted in only a partial delete, so we resynchronize
  Else
    modTreeUtil.RemoveNode tvTree, tvNode ' the delete was successful, remove the branch from the GUI
  End If
  Exit Function

Error:
  modError.ReportError "An error was encountered while deleting the category '" & strKey & "'."
  DeleteCategory = -1
End Function

'
'
'
Private Function DeleteCategory_Helper( _
  strKey As String, _
  strParentKey As String _
)

  On Error GoTo Error

  Dim numItems As Long
  Dim itemValue As String

  ' If a parent is specified then we have to locate and erase any reference
  '  it might have to this element, otherwise those references will point to
  '  non-existent sections in the INI file
  If strParentKey <> "" Then
    Dim isRefDeleted As Long
    isRefDeleted = 0

    Dim strLCaseKey As String
    strLCaseKey = LCase$(strKey)

    ' Remove references to this element from the parent category
    numItems = Val(modIniFile.ReadIniString(iniFileName, strParentKey, "count"))

    ' Make an inventory of the elements listed in the parent
    For i = 0 To numItems - 1
      itemValue = modIniFile.ReadIniString(iniFileName, strParentKey, "item" & Format$(i))

      If isRefDeleted <> 0 Then
        modIniFile.WriteIniString iniFileName, strParentKey, "item" & Format$(i - 1), itemValue
      ElseIf LCase$(itemValue) = strLCaseKey Then
        isRefDeleted = 1
      End If
    Next

    ' Finally remove the trailing element and shorten the children list by one
    If isRefDeleted <> 0 Then
      modIniFile.WriteIniString iniFileName, strParentKey, "count", Format$(numItems - 1)
      modIniFile.DeleteIniString iniFileName, strParentKey, "item" & Format$(numItems - 1)
    End If
  End If

  ' If dealing with a category we have to recursively delete any
  '  sub-categories or applications
  If LCase$(Left$(strKey, 4)) = "cat." Then
    ' Get the number of sub-elements that exist in this category
    numItems = Val(modIniFile.ReadIniString(iniFileName, strKey, "count"))

    ' Delete each sub-category and/or application listed
    For i = 0 To numItems - 1
      itemValue = modIniFile.ReadIniString(iniFileName, strKey, "item" & Format$(i))
      If DeleteCategory_Helper(itemValue, "") <> 0 Then GoTo Error
    Next
  End If

  ' Finally erase the element's section from the INI file
  modIniFile.DeleteIniSection iniFileName, strKey
  DeleteCategory_Helper = 0 ' return, success
  Exit Function

Error:
  DeleteCategory_Helper = -1  ' return, partial or complete failure
End Function

'
' Loads list of applications for a given category from the main .ini file
'
Public Function LoadApplications( _
  lvList As ListView, _
  strKey As String _
) As Long

  On Error GoTo Error

  ' Empty the applications list
  fMainForm.lvListView.ListItems.Clear

  ' Reset the application icons (detach image list from list view first)
  ResetApplicationsIcons lvList, 32, modMain.fMainForm.picMSDOS32
  ResetApplicationsIcons lvList, 16, modMain.fMainForm.picMSDOS16

  ' Get the number of sub-elements that exist
  Dim numItems As Long
  numItems = Val(modIniFile.ReadIniString(iniFileName, strKey, "count"))

  ' Create each application
  For i = 0 To numItems - 1
    Dim itemValue As String
    itemValue = modIniFile.ReadIniString(iniFileName, strKey, "item" & Format$(i))

    If LCase$(Left$(itemValue, 4)) = "app." Then
      LoadApplication lvList, itemValue
    End If
  Next
  LoadApplications = 0
  Exit Function

Error:
  modError.ReportError "Unable to load applications from '" & iniFileName & "'."
  LoadApplications = -1
End Function

'
'
'
Private Sub ResetApplicationsIcons( _
  lvList As ListView, _
  intSize As Integer, _
  icoDefault As Picture _
)
  Dim imlListIcons As ImageList

  Select Case intSize
    Case 32
      Set imlListIcons = lvList.Icons
      Set lvList.Icons = Nothing
    Case 16
      Set imlListIcons = lvList.SmallIcons
      Set lvList.SmallIcons = Nothing
    Case Else
      Err.Raise ccInvalidProcedureCall, "ResetApplicationsIcons", "Invalid icon size (" & intSize & ")"
  End Select

  imlListIcons.ListImages.Clear
  imlListIcons.ImageHeight = intSize
  imlListIcons.ImageWidth = intSize
  imlListIcons.ListImages.Add , "default", icoDefault

  Select Case intSize
    Case 32
      Set lvList.Icons = imlListIcons
    Case 16
      Set lvList.SmallIcons = imlListIcons
    Case Else
      Err.Raise ccInvalidProcedureCall, "ResetApplicationsIcons", "Invalid icon size (" & intSize & ")"
  End Select
End Sub

'
'
'
Private Sub LoadApplication( _
  lvList As ListView, _
  ByVal strKey As String _
)

  Dim icoKey As String
  icoKey = "default"

  On Error GoTo Error_UseDefaultIcon

  Dim strText As String
  strText = StrDecode(modIniFile.ReadIniString(iniFileName, strKey, "name"))

  Dim strIconPath As String
  strIconPath = modIniFile.ReadIniString(iniFileName, strKey, "icon")

  fMainForm.imlListIcons32.ListImages.Add , strKey, LoadPicture(strIconPath, , , 32, 32)
  fMainForm.imlListIcons16.ListImages.Add , strKey, LoadPicture(strIconPath, , , 16, 16)
  icoKey = strKey

Error_UseDefaultIcon:
  lvList.ListItems.Add , strKey, strText, icoKey, icoKey
End Sub

'
' Attempts to rename an application.  If the function is successful, the
'  function returns zero, otherwise (e.g. if the application name already
'  exists), it returns a non-zero value.
' If the renaming is successful, it is mirrored in the .ini configuration file.
'
Public Function RenameApplication( _
  lvList As ListView, _
  lvItem As ListItem, _
  ByVal strNewText As String _
) As Integer

  Dim strOldText As String
  strOldText = lvItem.Text

  On Error GoTo Error

  ' Attempt to rename the current node (assuming the new key is unique)
  If modListUtil.RenameItem(lvList, lvItem, strNewText) <> 0 Then
    RenameApplication = 1  ' return, duplicate name
  Else
    ' Rename category inside .ini file
    modIniFile.WriteIniString iniFileName, lvItem.Key, "name", StrEncode(strNewText)

    RenameApplication = 0  ' return, the item was successfully renamed
  End If
  Exit Function

Error:
  modError.ReportError "Unable to rename application to '" & strNewText & "'."
  On Error Resume Next
  modListUtil.RenameItem lvList, lvItem, strOldText ' roll back changes
  RenameApplication = -1
End Function

'
' Encodes all non-ANSI, non-alphanumeric characters using the
'  form '%xxxx', where 'xxxx' is the hexa-decimal representation
'  of the encoded character(s)
'
Public Function StrEncode( _
  ByVal strSrc As String _
) As String

  Dim retVal As String
  Dim curChr As String

  retVal = ""                     ' the return value

  For i = 1 To Len(strSrc)
    curChr = Mid$(strSrc, i, 1)   ' the character being currently processed

    If (Asc(curChr) >= Asc("0") And Asc(curChr) <= Asc("9")) Or _
       (Asc(curChr) >= Asc("A") And Asc(curChr) <= Asc("Z")) Or _
       (Asc(curChr) >= Asc("a") And Asc(curChr) <= Asc("z")) _
    Then                          ' an ANSI alphanumeric character
      retVal = retVal + curChr
    Else                          ' non-ANSI, non-alphanumeric: needs to be encoded!
      Dim strTmp As String        ' build the character's hex representation into this string
      strTmp = Hex(Asc(curChr))
      strTmp = Mid$("0000", Len(strTmp) + 1) + strTmp       ' 0-pad hex the representation to 4 figures
      retVal = retVal + "%" + strTmp                        ' prepend the 4 hex figures with '%' and put in return value
    End If
  Next

  StrEncode = retVal    ' return
End Function

'
' Decodes strings encoded using StrEncode
'
Public Function StrDecode( _
  ByVal strSrc As String _
) As String

  Dim retVal As String
  Dim curChr As String

  retVal = ""                     ' the return value

  For i = 1 To Len(strSrc)
    curChr = Mid$(strSrc, i, 1)   ' the character being currently processed

    If curChr <> "%" Then         ' non-encoded character
      retVal = retVal + curChr
    Else                          ' encoded character: must decode!
      Dim lngTmp As Long          ' hex value of the encoded character
      lngTmp = Val("&H" + Mid$(strSrc, i + 1, 4))
      retVal = retVal + Chr$(lngTmp)    ' append decoded character value to return value
      i = i + 4                   ' skip the following 4 characters because they are the 4 hex digits we just processed
    End If
  Next

  StrDecode = retVal    ' return
End Function
