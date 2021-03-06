<################################################################
 | Name: ScriptManager.ps1                                      |
 | Author: Alex Christensen                                     |
 | Date: 02/28/2017                                             |
 | Purpose: Organizes powershell scripts. Provides detailed     |
 |          descriptions of their functions. Also allows the    |
 |          creation of playlists of scripts.                   |
 | Usage: Run in powershell.                                    |
 |                                                              |
 |--------------------------------------------------------------|
 | Update History                                               |
 |                                                              |
 | 02/28/2017 AC: Created Script.                               |
 | 03/06/2017 AC: All initial Functionality Added.              |
 | 03/08/2017 AC: Created Generic Version of this script.       |
 | 06/28/2017 AC: Fixed issue with loading playlists.           |
 |                                                              |
 ################################################################>

#region /* Load External References */

# Adds the abilily to hide the console window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
 
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);

[DllImport("user32.dll")]
public static extern void DisableProcessWindowsGhosting();

'

# imports the Windows Forms and Drawing Functions
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')


# Called function to hide the console
function HideConsole(){
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0)

    #also disables the Not responding timeout
    [Console.Window]::DisableProcessWindowsGhosting()
}

#endregion /* Load External References */

#region /* Script Data Objects */

# Creates an empty Data Object
function NewDataObject($id, $name, $description, $psFileName, $isFlagged)
{
    $emptyDataObject= New-Object psobject -Property @{
        "ID" = $id
        "Name" = $name
        "Description" = $description
        "PSFileName" = $psFileName
        "Flagged" = $isFlagged
    }

    return $emptyDataObject
}

# Creates a empty Playlist Object
function NewPlaylistObject($id, $name)
{
    $emptyPlaylistObject= New-Object psobject -Property @{
        "ID" = $id
        "Name" = $name
        "LastUpdated" = Get-Date
        "ScriptNameList" = @()
    }

    return $emptyPlaylistObject
}

#endregion /* Script Data Objects */

#region /* Global Form Objects */

$mainForm = New-Object System.Windows.Forms.Form
$scriptComboBox = New-Object System.Windows.Forms.ComboBox
$descriptionTextBox = New-Object System.Windows.Forms.TextBox
$flagWarningLabel = New-Object System.Windows.Forms.Label
$scriptRunButton = New-Object System.Windows.Forms.Button
$scriptAddToPlaylistButton = New-Object System.Windows.Forms.Button
$playlistListBox = New-Object System.Windows.Forms.ListBox
$playlistNameTextBox = New-Object System.Windows.Forms.TextBox
$playlistRunButton = New-Object System.Windows.Forms.Button
$playlistRemoveButton = New-Object System.Windows.Forms.Button
$errorTextBox = New-Object System.Windows.Forms.RichTextBox
$labelFont = New-Object System.Drawing.Font("MS Sans Serif", 10)
$labelFontBig = New-Object System.Drawing.Font("MS Sans Serif", 16)

$mainLoadForm = New-Object System.Windows.Forms.Form
$loadComboBox = New-Object System.Windows.Forms.ComboBox

$mainScriptForm = New-Object System.Windows.Forms.Form
$scriptNameTextBox = New-Object System.Windows.Forms.TextBox
$scriptNewNameTextBox = New-Object System.Windows.Forms.TextBox
$scriptFileNameTextBox = New-Object System.Windows.Forms.TextBox
$scriptDescriptionTextBox = New-Object System.Windows.Forms.TextBox
$scriptFlaggedCheckBox = New-Object System.Windows.Forms.CheckBox

$mainAboutForm = New-Object System.Windows.Forms.Form

$iconPath = "$($PSScriptRoot)\Data\DefaultIcon.ico"

#endregion /* Global Form Objects */

#region /* Rich Text Box Write Functions */

# writes in color to a text box
function WriteToErrorTextBox($textBox, $text, $color, $newLine, $addDate)
{
    if($addDate)
    {
        $textBox.AppendText("$(Get-Date -f "MM/dd/yyyy hh:mm:ss") - ")
    }

    if($color -eq "Default")
    {
        $textBox.SelectionColor = $textBox.ForeColor
    }
    else
    {
        $textBox.SelectionColor = $color
    }

    $textBox.SelectionStart = $textBox.TextLength
    $textBox.SelectionLength = 0

    if($newline)
    {
        $textBox.AppendText("$($text)`n")
    }
    else
    {
        $textBox.AppendText("$($text)")
    }

    $textBox.SelectionColor = $textBox.ForeColor

    $textBox.ScrollToCaret()
}

# Writes a action
function WriteTextBoxAction($textBox, $text, $optionalText)
{
    WriteToErrorTextBox $textBox $text "cyan" $false $true

    if($optionalText -ne "" -and $optionalText -ne $null)
    {
        WriteToErrorTextBox $textBox " $($optionalText)" "yellow" $false $false
    }
}

# writes a success statement
function WriteTextBoxSuccess($textBox)
{
    WriteToErrorTextBox $textBox " - " "cyan" $false $false
    WriteToErrorTextBox $textBox "Success" "Default" $true $false
}

# writes a error statement
function WriteTextBoxError($textBox, $eMessage)
{
    WriteToErrorTextBox $textBox " - " "cyan" $false $false
    WriteToErrorTextBox $textBox "Error" "red" $true $false
    WriteToErrorTextBox $textBox "$($eMessage)" "red" $true $true
}

# writes some informaiton to the textbox
function WriteTextBoxInformation($textBox, $text1, $text2)
{
    if($text2 -eq $null -or $test2 -eq "")
    {
        WriteToErrorTextBox $textBox "$($text1)" "cyan" $true $true
    }
    else
    {
        WriteToErrorTextBox $textBox "$($text1)" "cyan" $false $true
        WriteToErrorTextBox $textBox "$($text2)" "yellow" $true $false
    }
}

# Writes a line across the output box to seperate chunks
function WriteTextBoxSeperator($textBox, $color)
{
    WriteToErrorTextBox $textBox "<!--------------------------------------------------------------------------------!>" $color $true $true
}
#endregion  /* Rich Text Box Write Functions */

#region /* Shared Functions */

# creates a user Yes/No popup box
function YesNoPopupBox($boxTitle, $boxQuestion)
{
    return [Microsoft.VisualBasic.Interaction]::MsgBox($boxQuestion, [Microsoft.VisualBasic.MsgBoxStyle]::YesNo, $boxTitle)
}

#endregion /* Shared Functions */

#region /* Windows Forms Functions */

function MainGUIConstructor()
{
    $mainForm.FormBorderStyle = 'Fixed3D'
    $mainForm.MaximizeBox = $false
    $mainForm.KeyPreview = $true
    $mainForm.Add_KeyDown({MainFormKeyDown})
    $mainForm.ClientSize = New-Object System.Drawing.Size(850,500)
    $mainForm.Text = "Script Manager"
    $mainForm.Icon = New-Object System.Drawing.Icon $iconPath
    $mainForm.Add_FormClosing({})

    # Menu Code
    $mainMenu = New-Object System.Windows.Forms.MenuStrip
    $mainForm.Controls.Add($mainMenu)

    $mainMenuFile = New-Object System.Windows.Forms.ToolStripMenuItem
    $mainMenuFile.Text = "File"
    $mainMenu.Items.Add($mainMenuFile) | Out-Null

    $mainMenuPlaylist = New-Object System.Windows.Forms.ToolStripMenuItem
    $mainMenuPlaylist.Text = "Playlist"
    $mainMenu.Items.Add($mainMenuPlaylist) | Out-Null

    $mainMenuScript = New-Object System.Windows.Forms.ToolStripMenuItem
    $mainMenuScript.Text = "Script"
    $mainMenu.Items.Add($mainMenuScript) | Out-Null

    $menuOptionAbout = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOptionAbout.Text = "About"
    $menuOptionAbout.Add_Click({$mainAboutForm.ShowDialog()})
    $menuOptionAbout.ShortcutKeys = "Control, A"
    $mainMenuFile.DropDownItems.Add($menuOptionAbout) | Out-Null

    $menuOptionExit = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOptionExit.Text = "Exit"
    $menuOptionExit.Add_Click({$mainForm.Close()})
    $menuOptionExit.ShortcutKeys = "Control, X"
    $mainMenuFile.DropDownItems.Add($menuOptionExit) | Out-Null

    $menuOptionNew = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOptionNew.Text = "New"
    $menuOptionNew.Add_Click({ClearPlaylist})
    $menuOptionNew.ShortcutKeys = "Control, N"
    $mainMenuPlaylist.DropDownItems.Add($menuOptionNew) | Out-Null

    $menuOptionLoad = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOptionLoad.Text = "Load"
    $menuOptionLoad.Add_Click({PlaylistLoadButtonAction})
    $menuOptionLoad.ShortcutKeys = "Control, L"
    $mainMenuPlaylist.DropDownItems.Add($menuOptionLoad) | Out-Null

    $menuOptionSave = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOptionSave.Text = "Save"
    $menuOptionSave.Add_Click({PlaylistSaveButtonAction})
    $menuOptionSave.ShortcutKeys = "Control, S"
    $mainMenuPlaylist.DropDownItems.Add($menuOptionSave) | Out-Null

    $menuOptionDelete = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOptionDelete.Text = "Delete"
    $menuOptionDelete.Add_Click({PlaylistDeleteButtonAction})
    $menuOptionDelete.ShortcutKeys = "Control, D"
    $mainMenuPlaylist.DropDownItems.Add($menuOptionDelete) | Out-Null

    $menuOptionNewScript = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOptionNewScript.Text = "New"
    $menuOptionNewScript.Add_Click({RunNewScriptAction})
    $menuOptionNewScript.ShortcutKeys = "Alt, N"
    $mainMenuScript.DropDownItems.Add($menuOptionNewScript) | Out-Null

    $menuOptionEditScript = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOptionEditScript.Text = "Edit"
    $menuOptionEditScript.Add_Click({RunEditScriptAction})
    $menuOptionEditScript.ShortcutKeys = "Alt, E"
    $mainMenuScript.DropDownItems.Add($menuOptionEditScript) | Out-Null

    $dropDownLabel = New-Object System.Windows.Forms.Label
    $dropDownLabel.Text = "Script"
    $dropDownLabel.Size = New-Object System.Drawing.Size(55,25)
    $dropDownLabel.Location = New-Object System.Drawing.Point(13,32)
    $dropDownLabel.Font = $labelFont
    $mainForm.Controls.Add($dropDownLabel)

    $scriptComboBox.Location = New-Object System.Drawing.Point(68,30)
    $scriptComboBox.Size = New-Object System.Drawing.Size(385,25)
    $scriptComboBox.DisplayMember = "Name"
    $scriptComboBox.ValueMember = "ID"
    $scriptComboBox.DropDownWidth = 196
    AddScriptComboBoxValues ""
    $scriptComboBox.AutoCompleteMode = 'Append'
    $scriptComboBox.AutoCompleteSource = 'ListItems'
    $scriptComboBox.DropDownStyle = "DropDownList"
    $scriptComboBox.Add_SelectedIndexChanged({AddScriptDropDownChange})
    $mainForm.Controls.Add($scriptComboBox)

    $descriptionGroupBox = New-Object System.Windows.Forms.GroupBox
    $descriptionGroupBox.Text = "Description"
    $descriptionGroupBox.Size = New-Object System.Drawing.Size(450,250)
    $descriptionGroupBox.Location = New-Object System.Drawing.Point(5,60)
    $descriptionGroupBox.Font = $labelFont
    $mainForm.Controls.Add($descriptionGroupBox)
    $descriptionTextBox.Size = New-Object System.Drawing.Size(440,225)
    $descriptionTextBox.Location = New-Object System.Drawing.Point(5,20)
    $descriptionTextBox.Multiline = $true
    $descriptionTextBox.ReadOnly = $true
    $descriptionTextBox.Text = "$($scriptComboBox.SelectedItem.Description)"
    $descriptionTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $descriptionGroupBox.Controls.Add($descriptionTextBox)

    $flagWarningLabel.Text = "Script Flagged - USE WITH CAUTION!"
    $flagWarningLabel.Size = New-Object System.Drawing.Size(245,25)
    $flagWarningLabel.Location = New-Object System.Drawing.Point(5,315)
    $flagWarningLabel.Font = $labelFont
    $flagWarningLabel.BackColor = "Red"
    $flagWarningLabel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $flagWarningLabel.Visible = $scriptComboBox.SelectedItem.Flagged
    $mainForm.Controls.Add($flagWarningLabel)

    $scriptRunButton.Size = New-Object System.Drawing.Size(75,25)
    $scriptRunButton.Location = New-Object System.Drawing.Point(300,315)
    $scriptRunButton.Text = "Run"
    $scriptRunButton.Add_Click({ScriptRunButtonAction})
    $scriptRunButton.Font = $labelFont
    $mainForm.Controls.Add($scriptRunButton)

    $scriptAddToPlaylistButton.Size = New-Object System.Drawing.Size(75,25)
    $scriptAddToPlaylistButton.Location = New-Object System.Drawing.Point(380,315)
    $scriptAddToPlaylistButton.Text = "Add"
    $scriptAddToPlaylistButton.Add_Click({ScriptAddButtonAction})
    $scriptAddToPlaylistButton.Font = $labelFont
    $mainForm.Controls.Add($scriptAddToPlaylistButton)

    $dividerGroupBox = New-Object System.Windows.Forms.GroupBox
    $dividerGroupBox.Text = ""
    $dividerGroupBox.Size = New-Object System.Drawing.Size(2,310)
    $dividerGroupBox.Location = New-Object System.Drawing.Point(462,30)
    $mainForm.Controls.Add($dividerGroupBox)

    $playlistGroupBox = New-Object System.Windows.Forms.GroupBox
    $playlistGroupBox.Text = "Playlist"
    $playlistGroupBox.Size = New-Object System.Drawing.Size(375,315)
    $playlistGroupBox.Location = New-Object System.Drawing.Point(470,30)
    $playlistGroupBox.Font = $labelFont
    $mainForm.Controls.Add($playlistGroupBox)

    $playlistListBox.Size = New-Object System.Drawing.Size(205,290)
    $playlistListBox.Location = New-Object System.Drawing.Point(5,20)
    $playlistListBox.Add_MouseDown({On_Playlist_MouseDown})
    $playlistListBox.Add_DragOver({On_Playlist_DragOver})
    $playlistListBox.Add_DragDrop({On_Playlist_DragDrop})
    $playlistListBox.AllowDrop = $true
    $playlistListBox.Add_KeyDown({On_Playlist_KeyDown})
    $playlistGroupBox.Controls.Add($playlistListBox)

    $playlistNameLabel = New-Object System.Windows.Forms.Label
    $playlistNameLabel.Text = "Playlist Name"
    $playlistNameLabel.Size = New-Object System.Drawing.Size(150,20)
    $playlistNameLabel.Location = New-Object System.Drawing.Point(215,20)
    $playlistNameLabel.Font = $labelFont
    $playlistGroupBox.Controls.Add($playlistNameLabel)

    $playlistNameTextBox.Size = New-Object System.Drawing.Size(155,25)
    $playlistNameTextBox.Location = New-Object System.Drawing.Point(215,40)
    $playlistNameTextBox.Text = ""
    $playlistGroupBox.Controls.Add($playlistNameTextBox)

    $playlistRunButton.Size = New-Object System.Drawing.Size(75,25)
    $playlistRunButton.Location = New-Object System.Drawing.Point(215,285)
    $playlistRunButton.Text = "Run"
    $playlistRunButton.Add_Click({PlaylistRunButtonAction})
    $playlistRunButton.Font = $labelFont
    $playlistGroupBox.Controls.Add($playlistRunButton)

    $playlistRemoveButton.Size = New-Object System.Drawing.Size(75,25)
    $playlistRemoveButton.Location = New-Object System.Drawing.Point(295,285)
    $playlistRemoveButton.Text = "Remove"
    $playlistRemoveButton.Add_Click({Playlist_Remove_Selected})
    $playlistRemoveButton.Font = $labelFont
    $playlistGroupBox.Controls.Add($playlistRemoveButton)

    $errorGroupBox = New-Object System.Windows.Forms.GroupBox
    $errorGroupBox.Text = "Output"
    $errorGroupBox.Size = New-Object System.Drawing.Size(840,145)
    $errorGroupBox.Location = New-Object System.Drawing.Point(5,350)
    $errorGroupBox.Font = $labelFont
    $mainForm.Controls.Add($errorGroupBox)

    $errorTextBox.Size = New-Object System.Drawing.Size(830,120)
    $errorTextBox.Location = New-Object System.Drawing.Point(5,20)
    $errorTextBox.Multiline = $true
    $errorTextBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $errorTextBox.Font = $labelFont #New-Object System.Drawing.Font("Consolas", 8)
    $errorTextBox.ReadOnly = $true
    $errorTextBox.BackColor = "Black"
    $errorTextBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#39FF14")
    $errorGroupBox.Controls.Add($errorTextBox)
}

# Populates the script DropDown
function AddScriptComboBoxValues($name)
{
    $scriptComboBox.Items.Clear()
    $tempItems = Import-Clixml '.\Data\ScriptDescriptionData.xml'
    foreach($script in $tempItems)
    {
        [void]$scriptComboBox.Items.Add($script)
    }

    # find the index of the item with a name of $name
    $index = 0 
    for($i = 0; $i -lt $scriptComboBox.Items.Count; $i++)
    {
        if($scriptComboBox.Items[$i].Name -eq $name)
        {
            $index = $i
            break
        }
    }

    $scriptComboBox.SelectedIndex = $index
}

# called when the script dropdown changes
function AddScriptDropDownChange()
{
    $descriptionTextBox.Text = "$($scriptComboBox.SelectedItem.Description)"
    $flagWarningLabel.Visible = $scriptComboBox.SelectedItem.Flagged
}


# runs the mouse down event for the Listview
function  On_Playlist_MouseDown()
{
    if($playlistListBox.SelectedItem -eq $null)
    {
        return
    }
    else
    {
        $playlistListBox.DoDragDrop($playlistListBox.SelectedItem, [System.Windows.Forms.DragDropEffects]::Move)
    }
}

# runs the mouse down event for the Listview
function  On_Playlist_DragOver()
{
    $_.Effect = [System.Windows.Forms.DragDropEffects]::Move
}

# runs the mouse down event for the Listview
function  On_Playlist_DragDrop()
{
    
    $index = $playlistListBox.IndexFromPoint($playlistListBox.PointToClient((New-Object System.Drawing.Point(($_.X), ($_.Y)))))
    if($index -lt 0)
    {
        $index = $playlistListBox.Items.Count - 1
    }

    $tempData = $playlistListBox.SelectedItem
    $playlistListBox.Items.Remove($tempData)
    $playlistListBox.Items.Insert($index, $tempData)
    RecalculateNumbersOnPlaylist
}

# On the playlist keydown
function On_Playlist_KeyDown()
{
    # Remove items on 'Delete' or 'R' Key
    if($_.KeyCode -eq [System.Windows.Forms.Keys]::Delete -or $_.KeyCode -eq [System.Windows.Forms.Keys]::R)
    {
        Playlist_Remove_Selected
    }
}

# Removes the selected Items on the playlist
function Playlist_Remove_Selected()
{
    $playlistListBox.Items.Remove($playlistListBox.SelectedItem)
    RecalculateNumbersOnPlaylist
}

# recalculates the index number on the playlistListBox
function RecalculateNumbersOnPlaylist()
{
    for($i = 0; $i -lt $playlistListBox.Items.Count; $i++)
    {
        $playlistListBox.Items[$i] = "$($i + 1).$($playlistListBox.Items[$i].split(".")[1])"
    }
}

# Performs the mainform keydown actions
function MainFormKeyDown()
{
    if($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape)
    {
        $mainForm.Close()
    }
}

#endregion /* Windows Forms Functions */

#region /* Windows Load Popup Functions */

#Add values to the load Combo box
function AddLoadComboBoxValues($loadComboBox)
{
    try
    {
        $playlistDataObjects = Import-Clixml ".\Data\ScriptManagerPlaylists.xml"
        [void]$loadComboBox.Items.Clear()
        foreach($playlist in $playlistDataObjects)
        {
            [void]$loadComboBox.Items.Add($playlist)
        }
    }
    catch
    {
        # no playlists or the file failed to load
        # just display no scripts
    }
}

#performs the load Button Action
function LoadFormLoadButtonAction()
{
    try
    {
        WriteTextBoxAction $errorTextBox "Loading Playlist:" "$($loadComboBox.SelectedItem.Name)"
        $playlistDataObjects = Import-Clixml ".\Data\ScriptManagerPlaylists.xml"

        foreach($playlist in $playlistDataObjects)
        {
            if($playlist.Name -eq $loadComboBox.SelectedItem.Name)
            {
                $playlistListBox.Items.Clear()
                $playlistNameTextBox.Text = $playlist.Name
                foreach($script in $playlist.ScriptNameList)
                {
                    $playlistListBox.Items.Add("-1. $($script)") | Out-Null
                    RecalculateNumbersOnPlaylist
                }
                break;
                
            }
        }
        WriteTextBoxSuccess $errorTextBox

    }
    catch
    {
        WriteTextBoxError $errorTextBox "Failed To Load Playlist - $($loadComboBox.SelectedItem.Value)"
    }

    $mainLoadForm.Close()
}

#Creates the load popup box
function BuildLoadPopupBox()
{
    $mainLoadForm.FormBorderStyle = 'Fixed3D'
    $mainLoadForm.MaximizeBox = $false
    $mainLoadForm.KeyPreview = $true
    $mainLoadForm.ClientSize = New-Object System.Drawing.Size(300,65)
    $mainLoadForm.Text = "Script Manager - Load"
    $mainLoadForm.Name = "mainLoadForm"
    $mainLoadForm.Icon = New-Object System.Drawing.Icon $iconPath

    $loadDropDownLabel = New-Object System.Windows.Forms.Label
    $loadDropDownLabel.Text = "Load Playlist"
    $loadDropDownLabel.Size = New-Object System.Drawing.Size(90,25)
    $loadDropDownLabel.Location = New-Object System.Drawing.Point(5,7)
    $loadDropDownLabel.Font = $labelFont
    $mainLoadForm.Controls.Add($loadDropDownLabel)

    $loadComboBox.Location = New-Object System.Drawing.Point(95,5)
    $loadComboBox.Size = New-Object System.Drawing.Size(200,25)
    $loadComboBox.DisplayMember = "Name"
    $loadComboBox.ValueMember = "ID"
    $loadComboBox.DropDownWidth = 200
    $loadComboBox.AutoCompleteMode = 'Append'
    $loadComboBox.AutoCompleteSource = 'ListItems'
    $loadComboBox.DropDownStyle = "DropDownList"
    $mainLoadForm.Controls.Add($loadComboBox)

    $loadFormLoadButton = New-Object System.Windows.Forms.Button
    $loadFormLoadButton.Size = New-Object System.Drawing.Size(75,25)
    $loadFormLoadButton.Location = New-Object System.Drawing.Point(220,35)
    $loadFormLoadButton.Text = "Load"
    $loadFormLoadButton.Add_Click({LoadFormLoadButtonAction})
    $loadFormLoadButton.Font = $labelFont
    $mainLoadForm.Controls.Add($loadFormLoadButton)

    $loadFormCancelButton = New-Object System.Windows.Forms.Button
    $loadFormCancelButton.Size = New-Object System.Drawing.Size(75,25)
    $loadFormCancelButton.Location = New-Object System.Drawing.Point(140,35)
    $loadFormCancelButton.Text = "Cancel"
    $loadFormCancelButton.Add_Click({$mainLoadForm.Close()})
    $loadFormCancelButton.Font = $labelFont
    $mainLoadForm.Controls.Add($loadFormCancelButton)
}


#endregion /* Windows Load Popup Functions */

#region /* Windows Script Popup Functions */

# build the load popup box
function BuildScriptPopupBox()
{
    $mainScriptForm.FormBorderStyle = 'Fixed3D'
    $mainScriptForm.MaximizeBox = $false
    $mainScriptForm.KeyPreview = $true
    $mainScriptForm.ClientSize = New-Object System.Drawing.Size(450,385)
    $mainScriptForm.Text = "Script Manager - Script Editor"
    $mainScriptForm.Icon = New-Object System.Drawing.Icon $iconPath
    $mainScriptForm.Add_FormClosing({AddScriptComboBoxValues $scriptNewNameTextBox.Text})

    $scriptNameLabel = New-Object System.Windows.Forms.Label
    $scriptNameLabel.Text = "Name.............:"
    $scriptNameLabel.Size = New-Object System.Drawing.Size(95,20)
    $scriptNameLabel.Location = New-Object System.Drawing.Point(5,7)
    $scriptNameLabel.Font = $labelFont
    $mainScriptForm.Controls.Add($scriptNameLabel)

    $scriptNameTextBox.Size = New-Object System.Drawing.Size(340,25)
    $scriptNameTextBox.Location = New-Object System.Drawing.Point(100,5)
    $scriptNameTextBox.ReadOnly = $true
    $mainScriptForm.Controls.Add($scriptNameTextBox)

    $scriptNewNameLabel = New-Object System.Windows.Forms.Label
    $scriptNewNameLabel.Text = "New Name....:"
    $scriptNewNameLabel.Size = New-Object System.Drawing.Size(95,20)
    $scriptNewNameLabel.Location = New-Object System.Drawing.Point(5,37)
    $scriptNewNameLabel.Font = $labelFont
    $mainScriptForm.Controls.Add($scriptNewNameLabel)

    $scriptNewNameTextBox.Size = New-Object System.Drawing.Size(340,25)
    $scriptNewNameTextBox.Location = New-Object System.Drawing.Point(100,35)
    $mainScriptForm.Controls.Add($scriptNewNameTextBox)

    $scriptFileNameLabel = New-Object System.Windows.Forms.Label
    $scriptFileNameLabel.Text = "File Name......:"
    $scriptFileNameLabel.Size = New-Object System.Drawing.Size(95,20)
    $scriptFileNameLabel.Location = New-Object System.Drawing.Point(5,67)
    $scriptFileNameLabel.Font = $labelFont
    $mainScriptForm.Controls.Add($scriptFileNameLabel)

    $scriptFileNameTextBox.Size = New-Object System.Drawing.Size(340,25)
    $scriptFileNameTextBox.Location = New-Object System.Drawing.Point(100,65)
    $mainScriptForm.Controls.Add($scriptFileNameTextBox)

    $scriptDescriptionLabel = New-Object System.Windows.Forms.Label
    $scriptDescriptionLabel.Text = "Description"
    $scriptDescriptionLabel.Size = New-Object System.Drawing.Size(150,20)
    $scriptDescriptionLabel.Location = New-Object System.Drawing.Point(5,95)
    $scriptDescriptionLabel.Font = $labelFont
    $mainScriptForm.Controls.Add($scriptDescriptionLabel)

    $scriptDescriptionTextBox.Size = New-Object System.Drawing.Size(440,225)
    $scriptDescriptionTextBox.Location = New-Object System.Drawing.Point(5,125)
    $scriptDescriptionTextBox.Multiline = $true
    $scriptDescriptionTextBox.Font = $labelFont
    $scriptDescriptionTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $mainScriptForm.Controls.Add($scriptDescriptionTextBox)

    $scriptPopupSaveButton = New-Object System.Windows.Forms.Button
    $scriptPopupSaveButton.Size = New-Object System.Drawing.Size(75,25)
    $scriptPopupSaveButton.Location = New-Object System.Drawing.Point(210,355)
    $scriptPopupSaveButton.Text = "Save"
    $scriptPopupSaveButton.Add_Click({RunSaveScriptAction})
    $scriptPopupSaveButton.Font = $labelFont
    $mainScriptForm.Controls.Add($scriptPopupSaveButton)

    $scriptFlaggedLabel = New-Object System.Windows.Forms.Label
    $scriptFlaggedLabel.Text = "Flagged"
    $scriptFlaggedLabel.Size = New-Object System.Drawing.Size(70,20)
    $scriptFlaggedLabel.Location = New-Object System.Drawing.Point(5,360)
    $scriptFlaggedLabel.Font = $labelFont
    $mainScriptForm.Controls.Add($scriptFlaggedLabel)

    $scriptFlaggedCheckBox.Location = New-Object System.Drawing.Point(75, 358)
    $mainScriptForm.Controls.Add($scriptFlaggedCheckBox)

    $scriptPopupDeleteButton = New-Object System.Windows.Forms.Button
    $scriptPopupDeleteButton.Size = New-Object System.Drawing.Size(75,25)
    $scriptPopupDeleteButton.Location = New-Object System.Drawing.Point(290,355)
    $scriptPopupDeleteButton.Text = "Delete"
    $scriptPopupDeleteButton.Add_Click({RunDeleteScriptAction})
    $scriptPopupDeleteButton.Font = $labelFont
    $mainScriptForm.Controls.Add($scriptPopupDeleteButton)

    $scriptPopupCancelButton = New-Object System.Windows.Forms.Button
    $scriptPopupCancelButton.Size = New-Object System.Drawing.Size(75,25)
    $scriptPopupCancelButton.Location = New-Object System.Drawing.Point(370,355)
    $scriptPopupCancelButton.Text = "Cancel"
    $scriptPopupCancelButton.Add_Click({$mainScriptForm.Close()})
    $scriptPopupCancelButton.Font = $labelFont
    $mainScriptForm.Controls.Add($scriptPopupCancelButton)
}

# clears the scriptform
function ClearScriptForm()
{
    $scriptNameTextBox.Text = ""
    $scriptNewNameTextBox.Text = ""
    $scriptFileNameTextBox.Text = ""
    $scriptDescriptionTextBox.Text = ""
    $scriptFlaggedCheckBox.Checked = $false
}

# run when the new script action is selected
function RunNewScriptAction()
{
    ClearScriptForm
    $mainScriptForm.ShowDialog()
}

# run when the edit script action is selected
function RunEditScriptAction()
{
    ClearScriptForm
    $scriptNameTextBox.Text = "$($scriptComboBox.SelectedItem.Name)"
    $scriptNewNameTextBox.Text = "$($scriptComboBox.SelectedItem.Name)"
    $scriptFileNameTextBox.Text = "$($scriptComboBox.SelectedItem.PSFileName)"
    $scriptDescriptionTextBox.Text = "$($scriptComboBox.SelectedItem.Description)"
    $scriptFlaggedCheckBox.Checked = $scriptComboBox.SelectedItem.Flagged
    $mainScriptForm.ShowDialog()
}

# runs the Save button on the script form
function RunSaveScriptAction()
{
    if($scriptNameTextBox.Text -eq "")
    {
        $scriptNameTextBox.Text = $scriptNewNameTextBox.Text.Trim()
    }

    # if the script data exists update the file
    if(Test-Path ".\Data\ScriptDescriptionData.xml")
    {
        #import the playlist data
        $scriptDescriptionObject = Import-Clixml ".\Data\ScriptDescriptionData.xml"
        $inlist = $false

        foreach($script in $scriptDescriptionObject)
        {
            if($script.Name -eq $scriptNameTextBox.Text.Trim() -and !$inList)
            {
                $script.Name = $scriptNewNameTextBox.Text.Trim()
                $script.PSFileName = $scriptFileNameTextBox.Text.Trim()
                $script.Description = $scriptDescriptionTextBox.Text
                $script.Flagged = $scriptFlaggedCheckBox.Checked

                $inList = $true
                break
            }
        }

        if(!$inList)
        {
            $newID = 0
            foreach($script in $scriptDescriptionObject)
            {
                if($script.ID -ge $newID)
                {
                    $newID = $script.ID + 1
                }
            }

            $nScriptDescription = NewDataObject $newID $scriptNewNameTextBox.Text.Trim() $scriptDescriptionTextBox.Text $scriptFileNameTextBox.Text.Trim() $scriptFlaggedCheckBox.Checked

            if($scriptDescriptionObject.count -eq $null)
            {
                $nScriptDescriptionObject = @()
                $nScriptDescriptionObject += $scriptDescriptionObject

                $scriptDescriptionObject = $nScriptDescriptionObject
            }

            $scriptDescriptionObject += $nScriptDescription
        }

        try
        {
            
            if($inlist)
            {
                WriteTextBoxAction $errorTextBox "Updated Script:" "$($scriptNameTextBox.Text.Trim())"
            }
            else
            {
                WriteTextBoxAction $errorTextBox "Added Script:" "$($scriptNameTextBox.Text.Trim())"
            }
            $scriptDescriptionObject | Sort-Object -Property Name | Export-Clixml ".\Data\ScriptDescriptionData.xml"

            WriteTextBoxSuccess $errorTextBox
            $mainScriptForm.Close()
        }
        catch
        {
            if($inlist)
            {
                WriteTextBoxError $errorTextBox "Failed to Update Script: $($scriptNameTextBox.Text.Trim())"
            }
            else
            {
                WriteTextBoxError $errorTextBox "Failed to Add Script: $($scriptNameTextBox.Text.Trim())"
            }
        }
    }
    else
    {
        # otherwise create a new one
        $scriptDescriptionObject = @()

        $nScriptDescription = NewDataObject 0 $scriptNameTextBox.Text.Trim() $scriptDescriptionTextBox.Text $scriptFileNameTextBox.Text.Trim() $scriptFlaggedCheckBox.Checked

        $scriptDescriptionObject += $nScriptDescription

        try
        {
            WriteTextBoxAction $errorTextBox "Added Script Description:" "$($scriptNameTextBox.Text.Trim())"
            $scriptDescriptionObject | Export-Clixml ".\Data\ScriptDescriptionData.xml"
            WriteTextBoxSuccess $errorTextBox
            $mainScriptForm.Close()
        }
        catch
        {
            WriteTextBoxError $errorTextBox "Failed to Add Script Description: $($scriptNameTextBox.Text.Trim())"
        } 
    }

    
}

# runs the delete button on the script form
function RunDeleteScriptAction()
{
    $deleteScript = YesNoPopupBox "Script Manager - Delete Script" "Delete $($scriptNameTextBox.Text.Trim())?"

    if($deleteScript -eq "Yes")
    {
        try
        {
            WriteTextBoxAction $errorTextBox "Deleting Script:" "$($scriptNameTextBox.Text.Trim())"
            $scriptDescriptionObject = Import-Clixml ".\Data\ScriptDescriptionData.xml"

            $nScriptList = @()
            foreach($script in $scriptDescriptionObject)
            {
                if($script.Name -ne $scriptNameTextBox.Text.Trim())
                {
                    $nScriptList += $script
                }
            }
            $nScriptList | Sort-Object -Property Name | Export-Clixml ".\Data\ScriptDescriptionData.xml"
            WriteTextBoxSuccess $errorTextBox

            $mainScriptForm.Close()
        }
        catch
        {
            WriteTextBoxError $errorTextBox "Failed to Delete Script: $($scriptNameTextBox.Text.Trim())"
        } 
    }

}

#endregion /* Windows Script Popup Functions */

#region /* Windows About Popup Functions */

# Builds the About Popup
function BuildAboutPopupBox()
{
    $mainAboutForm.FormBorderStyle = 'Fixed3D'
    $mainAboutForm.MaximizeBox = $false
    $mainAboutForm.ClientSize = New-Object System.Drawing.Size(300,130)
    $mainAboutForm.Text = "Script Manager - About"
    $mainAboutForm.Icon = New-Object System.Drawing.Icon $iconPath
    $mainAboutForm.Add_FormClosing({})

    $aboutScriptName = New-Object System.Windows.Forms.Label
    $aboutScriptName.Text = "Script Manager"
    $aboutScriptName.Size = New-Object System.Drawing.Size(160,25)
    $aboutScriptName.Location = New-Object System.Drawing.Point(75,5)
    $aboutScriptName.Font = $labelFontBig
    $mainAboutForm.Controls.Add($aboutScriptName)

    $aboutDivider = New-Object System.Windows.Forms.GroupBox
    $aboutDivider.Text = ""
    $aboutDivider.Size = New-Object System.Drawing.Size(290,2)
    $aboutDivider.Location = New-Object System.Drawing.Point(5,32)
    $mainAboutForm.Controls.Add($aboutDivider)

    $aboutScriptLastUpdate = New-Object System.Windows.Forms.Label
    $aboutScriptLastUpdate.Text = "Last Updated: 03/09/2017"
    $aboutScriptLastUpdate.Size = New-Object System.Drawing.Size(180,25)
    $aboutScriptLastUpdate.Location = New-Object System.Drawing.Point(75,40)
    $aboutScriptLastUpdate.Font = $labelFont
    $mainAboutForm.Controls.Add($aboutScriptLastUpdate)

    $aboutScriptName = New-Object System.Windows.Forms.Label
    $aboutScriptName.Text = "Support@FakeEmail.com"
    $aboutScriptName.Size = New-Object System.Drawing.Size(220,25)
    $aboutScriptName.Location = New-Object System.Drawing.Point(75,70)
    $aboutScriptName.Font = $labelFont
    $mainAboutForm.Controls.Add($aboutScriptName)

    $aboutOkButton = New-Object System.Windows.Forms.Button
    $aboutOkButton.Size = New-Object System.Drawing.Size(75,25)
    $aboutOkButton.Location = New-Object System.Drawing.Point(112,100)
    $aboutOkButton.Text = "Ok"
    $aboutOkButton.Add_Click({$mainAboutForm.Close()})
    $aboutOkButton.Font = $labelFont
    $mainAboutForm.Controls.Add($aboutOkButton)
}

#endregion /* Windows About Popup Functions */

#region /* Windows Forms Button Actions */

# Clears the playlist window
function ClearPlaylist()
{
    $playlistListBox.Items.Clear()
    $playlistNameTextBox.Text = ""
}

# Runs the action for the Script Run Button
function ScriptRunButtonAction()
{
    WriteTextBoxAction $errorTextBox "Running Script:" "$($scriptComboBox.SelectedItem.Name)"

    Start-Process -FilePath powershell.exe -ArgumentList ".\$($scriptComboBox.SelectedItem.PSFileName)" -Wait
    
    WriteTextBoxSuccess $errorTextBox     
}

# Runs the action for the Script Add Button
function ScriptAddButtonAction()
{
    $playlistListBox.Items.Add("-1. $($scriptComboBox.SelectedItem.Name)") | Out-Null
    RecalculateNumbersOnPlaylist
}

# Runs the action for the Playlist Save Button
function PlaylistSaveButtonAction()
{
    # if the playlist data exists update the file
    if(Test-Path ".\Data\ScriptManagerPlaylists.xml")
    {
        #import the playlist data
        $scriptPlaylistDataObject = Import-Clixml ".\Data\ScriptManagerPlaylists.xml"
        $inlist = $false
        foreach($playlist in $scriptPlaylistDataObject)
        {
            if($playlist.Name -eq $playlistNameTextBox.Text.Trim() -and !$inList)
            {
                $playlist.LastUpdated = Get-Date
                $playlist.ScriptNameList = @()
                foreach($item in $playlistListBox.Items)
                {
                    $playlist.ScriptNameList += "$($item.split(".")[1].Trim())"
                }

                $inList = $true
            }
        }

        if(!$inList)
        {
            $newID = 0
            foreach($playlist in $scriptPlaylistDataObject)
            {
                if($playlist.ID -ge $newID)
                {
                    $newID = $playlist.ID + 1
                }
            }

            $nPlaylist = NewPlaylistObject $newID $playlistNameTextBox.Text.Trim()

            foreach($item in $playlistListBox.Items)
            {
                $nPlaylist.ScriptNameList += "$($item.split(".")[1].Trim())"
            }

            if($scriptPlaylistDataObject.count -eq $null)
            {
                $nPlaylistDataObjects = @()
                $nPlaylistDataObjects += $scriptPlaylistDataObject

                $scriptPlaylistDataObject = $nPlaylistDataObjects
            }

            $scriptPlaylistDataObject += $nPlaylist
        }

        try
        {
            
            if($inlist)
            {
                WriteTextBoxAction $errorTextBox "Updated Playlist:" "$($playlistNameTextBox.Text.Trim())"
            }
            else
            {
                WriteTextBoxAction $errorTextBox "Added Playlist:" "$($playlistNameTextBox.Text.Trim())"
            }
            $scriptPlaylistDataObject | Export-Clixml ".\Data\ScriptManagerPlaylists.xml"

            WriteTextBoxSuccess $errorTextBox
        }
        catch
        {
            if($inlist)
            {
                WriteTextBoxError $errorTextBox "Failed to Update Playlist: $($playlistNameTextBox.Text.Trim())"
            }
            else
            {
                WriteTextBoxError $errorTextBox "Failed to Add Playlist: $($playlistNameTextBox.Text.Trim())"
            }
        }
    }
    else
    {
        # otherwise create a new one
        $scriptPlaylistDataObject = @()

        $nPlaylist = NewPlaylistObject 0 $playlistNameTextBox.Text.Trim()

        foreach($item in $playlistListBox.Items)
        {
            $nPlaylist.ScriptNameList += "$($item.split(".")[1].Trim())"
        }

        $scriptPlaylistDataObject += $nPlaylist

        try
        {
            WriteTextBoxAction $errorTextBox "Added Playlist:" "$($playlistNameTextBox.Text.Trim())"
            $scriptPlaylistDataObject | Export-Clixml ".\Data\ScriptManagerPlaylists.xml"
            WriteTextBoxSuccess $errorTextBox
        }
        catch
        {
            WriteTextBoxError $errorTextBox "Failed to Add Playlist: $($playlistNameTextBox.Text.Trim())"
        } 
    }

}

# Runs the action for the Playlist Load Button
function PlaylistLoadButtonAction()
{
    $loadComboBox.Items.Clear()
    AddLoadComboBoxValues $loadComboBox
    $loadComboBox.SelectedIndex = 0
    $mainLoadForm.ShowDialog()
}

# Runs the action for the Playlist Run Button
function PlaylistRunButtonAction()
{
    WriteTextBoxSeperator $errorTextBox "cyan"
    WriteTextBoxInformation $errorTextBox "Running Playlist - " "$($playlistNameTextBox.Text.Trim())"
    foreach($item in $playlistListBox.Items)
    {

        $currentScriptName = "$($item.split(".")[1].Trim())"
        WriteTextBoxAction $errorTextBox "Running Script:" "$($currentScriptName)"

        $foundScript = $false
        foreach($scriptObject in $scriptComboBox.Items)
        {
            if($scriptObject.Name -eq $currentScriptName)
            {
                
                Start-Process -FilePath powershell.exe -ArgumentList ".\$($scriptObject.PSFileName)" -Wait
                
                WriteTextBoxSuccess $errorTextBox
                $foundScript = $true
                break
            }
        }

        if(!$foundScript)
        {
            WriteTextBoxError $errorTextBox "Script Not Found!"
        }

    }

    WriteTextBoxInformation $errorTextBox "Run Completed"
    WriteTextBoxSeperator $errorTextBox "cyan"
}

# Runs the action for the Playlist Delete Button
function PlaylistDeleteButtonAction()
{
    $deletePlaylist = YesNoPopupBox "Script Manager - Delete Playlist" "Delete $($playlistNameTextBox.Text.Trim())?"

    if($deletePlaylist -eq "Yes")
    {
        try
        {
            WriteTextBoxAction $errorTextBox "Deleting Playlist:" "$($playlistNameTextBox.Text.Trim())"
            $playlistDataObjects = Import-Clixml ".\Data\ScriptManagerPlaylists.xml"

            $nPlaylists = @()
            foreach($playlist in $playlistDataObjects)
            {
                if($playlist.Name -ne $playlistNameTextBox.Text.Trim())
                {
                    $nPlaylists += $playlist
                }
            }

            $nPlaylists | Export-Clixml ".\Data\ScriptManagerPlaylists.xml"
            WriteTextBoxSuccess $errorTextBox

            ClearPlaylist
        }
        catch
        {
            WriteTextBoxError $errorTextBox "Failed to Delete Playlist: $($playlistNameTextBox.Text.Trim())"
        } 
    }
}

#endregion /* Windows Forms Button Actions */


<#--- Main Script Function ---#>

HideConsole

MainGUIConstructor

BuildLoadPopupBox

BuildScriptPopupBox

BuildAboutPopupBox

WriteTextBoxInformation $errorTextBox "Script Manager Started Successfully"

$mainForm.ShowDialog()