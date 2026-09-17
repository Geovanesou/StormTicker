param(
    [int]    $Index     = 1,
    [string] $FType     = "url",
    [string] $FeedsPath = ""
)

# Mutex to prevent multiple windows for the same field
$mutexName = "StormTickerEdit_${Index}_${FType}"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
if (-not $mutex.WaitOne(0, $false)) {
    # Already running
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

$varName = if ($FType -eq "url") { "FeedURL$Index" } else { "FeedTag$Index" }
$title   = if ($FType -eq "url") { "URL do RSS - Canal $Index" } else { "Tag - Canal $Index" }
$label   = if ($FType -eq "url") { "Cole ou edite a URL do feed RSS (Ctrl+V):" } else { "Edite o nome curto do canal:" }

$currentVal = ""
if ($FeedsPath -ne "" -and (Test-Path $FeedsPath)) {
    $content = [System.IO.File]::ReadAllText($FeedsPath, [System.Text.Encoding]::Unicode)
    if ($content -match "(?m)^$varName=(.+)") {
        $currentVal = $matches[1].Trim('"').Trim()
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text            = "StormTicker Pro - $title"
$form.StartPosition = 'Manual'
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$form.Location = New-Object System.Drawing.Point( [math]::Round(($screen.Width - 450) / 2), [math]::Round($screen.Height - 300) )
$form.Size            = New-Object System.Drawing.Size(520, 140)
$form.StartPosition   = "CenterScreen"
$form.TopMost         = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false
$form.BackColor       = [System.Drawing.Color]::FromArgb(15, 23, 42)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text      = $label
$lbl.Location  = New-Object System.Drawing.Point(10, 12)
$lbl.Size      = New-Object System.Drawing.Size(490, 20)
$lbl.ForeColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
$lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($lbl)

$txt = New-Object System.Windows.Forms.TextBox
$txt.Text      = $currentVal
$txt.Location  = New-Object System.Drawing.Point(10, 36)
$txt.Size      = New-Object System.Drawing.Size(490, 24)
$txt.Font      = New-Object System.Drawing.Font("Consolas", 9)
$txt.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$txt.ForeColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
$txt.SelectAll()
$form.Controls.Add($txt)

$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Text         = "OK - Salvar"
$btnOK.Location     = New-Object System.Drawing.Point(320, 68)
$btnOK.Size         = New-Object System.Drawing.Size(90, 28)
$btnOK.DialogResult = "OK"
$btnOK.FlatStyle    = "Flat"
$btnOK.BackColor    = [System.Drawing.Color]::FromArgb(14, 165, 233)
$btnOK.ForeColor    = [System.Drawing.Color]::White
$form.Controls.Add($btnOK)
$form.AcceptButton = $btnOK

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text         = "Cancelar"
$btnCancel.Location     = New-Object System.Drawing.Point(418, 68)
$btnCancel.Size         = New-Object System.Drawing.Size(82, 28)
$btnCancel.DialogResult = "Cancel"
$btnCancel.FlatStyle    = "Flat"
$btnCancel.BackColor    = [System.Drawing.Color]::FromArgb(30, 41, 59)
$btnCancel.ForeColor    = [System.Drawing.Color]::FromArgb(148, 163, 184)
$form.Controls.Add($btnCancel)
$form.CancelButton = $btnCancel

$form.Add_Shown({ 
    [Win32]::SetForegroundWindow($form.Handle)
    $txt.SelectAll()
    $txt.Focus() 
})

$result = $form.ShowDialog()

if ($result -eq "OK" -and $txt.Text.Trim() -ne "") {
    $newVal = $txt.Text.Trim()
    $content = [System.IO.File]::ReadAllText($FeedsPath, [System.Text.Encoding]::Unicode)
    $content = $content -replace "(?m)^$varName=.*", "$varName=$newVal"
    [System.IO.File]::WriteAllText($FeedsPath, $content, [System.Text.Encoding]::Unicode)

    $rm = (Get-Process Rainmeter -ErrorAction SilentlyContinue | Select-Object -First 1).Path
    if ($rm) {
        Start-Process -FilePath $rm -ArgumentList '!Refresh "StormTicker" "StormTicker.ini"' -NoNewWindow
        Start-Process -FilePath $rm -ArgumentList '!Refresh "StormTicker\Settings" "Settings.ini"' -NoNewWindow
    }
}

$mutex.ReleaseMutex()


