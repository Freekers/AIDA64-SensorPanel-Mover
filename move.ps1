# --- SCRIPT ---

# 1. Check for Administrator Privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires administrator privileges to move the AIDA64 window."
    Write-Warning "Please re-run this script from an elevated PowerShell terminal (Right-click -> Run as Administrator)."
    # We don't write to the log here because it might be in a protected location.
    exit 1
}

# --- CONFIGURATION ---
$aida64Path = "C:\Program Files (x86)\FinalWire\AIDA64 Extreme\aida64.exe" # <-- UPDATE THIS PATH IF NEEDED
$targetResolution = "1280x800" # The resolution of your SensorPanel monitor
$windowTitle = "SensorPanel"

# Add required .NET assemblies for UI interaction
Add-Type -AssemblyName System.Windows.Forms

# 2. Check for RDP Session
if ([System.Windows.Forms.SystemInformation]::TerminalServerSession) {
    # We don't use Write-Log here as it might be the first run.
    Write-Host "RDP session detected. The script will not run."
    exit 2 # Using a different exit code for RDP detection
}

# Win32 API signatures for finding and moving windows
$signature = @'
public delegate bool EnumWindowsProc(System.IntPtr hWnd, System.IntPtr lParam);

[DllImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, System.IntPtr lParam);

[DllImport("user32.dll")]
public static extern int GetWindowThreadProcessId(System.IntPtr hWnd, out int lpdwProcessId);

[DllImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool IsWindowVisible(System.IntPtr hWnd);

[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern int GetWindowText(System.IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

public const uint SWP_NOSIZE = 0x0001;
public const uint SWP_NOZORDER = 0x0004;
'@
$api = Add-Type -MemberDefinition $signature -Name 'Win32' -Namespace 'Utils' -PassThru

function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path -Path $PSScriptRoot -ChildPath "SensorPanel.log"
    "[$timestamp] $message" | Out-File -FilePath $logFile -Append
    Write-Host "[$timestamp] $message"
}

function Find-SensorPanelWindow($processId, $title) {
    Write-Log "Searching for window with title '$title' for process ID $processId..."
    $script:foundWindow = $null
    $enumWindowsCallback = {
        param($hWnd, $lParam)

        $windowPid = 0
        [Utils.Win32]::GetWindowThreadProcessId($hWnd, [ref]$windowPid) | Out-Null

        if ($windowPid -eq $processId -and [Utils.Win32]::IsWindowVisible($hWnd)) {
            $sb = New-Object System.Text.StringBuilder 256
            [Utils.Win32]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
            $wTitle = $sb.ToString()

            if ($wTitle -like "*$title*") {
                Write-Log "Found matching window: Handle=$hWnd, Title='$wTitle'"
                $script:foundWindow = $hWnd
                return $false # Stop enumerating
            }
        }
        return $true # Continue enumerating
    }

    $delegate = [Utils.Win32+EnumWindowsProc]$enumWindowsCallback
    [Utils.Win32]::EnumWindows($delegate, [System.IntPtr]::Zero) | Out-Null

    return $script:foundWindow
}

function Get-TargetMonitor($resolution) {
    Write-Log "Searching for a monitor with resolution '$resolution'..."
    $screens = [System.Windows.Forms.Screen]::AllScreens
    foreach ($screen in $screens) {
        $currentRes = "$($screen.Bounds.Width)x$($screen.Bounds.Height)"
        Write-Log "Found monitor: $($screen.DeviceName) with resolution $currentRes"
        if ($currentRes -eq $resolution) {
            Write-Log "Target monitor found: $($screen.DeviceName)"
            return $screen
        }
    }
    Write-Log "Error: No monitor found with resolution '$resolution'."
    return $null
}

# --- MAIN EXECUTION ---

Write-Log "--- Script started ---"

# 0. Verify AIDA64 path
$monitor = Get-TargetMonitor -resolution $targetResolution
if (-not $monitor) {
    Write-Log "Exiting script because target monitor was not found."
    exit 1
}

# 2. Check if AIDA64 is running, if not, start it
$aidaProcess = Get-Process -Name "aida64" -ErrorAction SilentlyContinue
if (-not $aidaProcess) {
    Write-Log "AIDA64 not running. Starting it now from '$aida64Path'..."
    Start-Process -FilePath $aida64Path
    Start-Sleep -Seconds 10 # Give it time to initialize
    $aidaProcess = Get-Process -Name "aida64" -ErrorAction SilentlyContinue
}

if (-not $aidaProcess) {
    Write-Log "Error: Failed to start or find the AIDA64 process after waiting."
    exit 1
}

Write-Log "AIDA64 process found. PID: $($aidaProcess.Id)"

# 3. Find the SensorPanel window
$windowHandle = $null
$timeout = 30 # seconds
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
while ($stopwatch.Elapsed.TotalSeconds -lt $timeout) {
    $windowHandle = Find-SensorPanelWindow -processId $aidaProcess.Id -title $windowTitle
    if ($windowHandle -and $windowHandle -ne [System.IntPtr]::Zero) {
        Write-Log "Successfully found SensorPanel window handle: $windowHandle"
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $windowHandle -or $windowHandle -eq [System.IntPtr]::Zero) {
    Write-Log "Error: Timed out waiting for the SensorPanel window to appear."
    exit 1
}

# 4. Move the window to the target monitor
Write-Log "Moving window to monitor $($monitor.DeviceName) at coordinates X:$($monitor.Bounds.X), Y:$($monitor.Bounds.Y)"
$result = [Utils.Win32]::SetWindowPos($windowHandle, [System.IntPtr]::Zero, $monitor.Bounds.X, $monitor.Bounds.Y, 0, 0, ([Utils.Win32]::SWP_NOSIZE -bor [Utils.Win32]::SWP_NOZORDER))

if ($result) {
    Write-Log "Window moved successfully."
} else {
    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $errorMessage = New-Object System.ComponentModel.Win32Exception $lastError
    Write-Log "Error: Failed to move the window. Win32 Error Code: $lastError ($($errorMessage.Message))"
}

Write-Log "--- Script finished ---"