# AIDA64 SensorPanel Mover Script

This PowerShell script is designed to automatically move the AIDA64 SensorPanel window to a specific monitor upon user logon or workstation unlock. It is especially helpful for users with multi-monitor setups or for those who find the SensorPanel's position is unexpectedly reset after a graphics driver update or a Remote Desktop (RDP) session.

The script uses native PowerShell and .NET methods, eliminating the need for third-party tools.

## Features

-   **Auto-Start AIDA64**: If AIDA64 is not already running, the script will start it. You should disable the "Start with Windows" option within AIDA64 itself to avoid conflicts.
-   **Target by Resolution**: Identifies the target monitor based on its screen resolution. **NOTE:** This does require the display running your SensorPanel to have a unique resolution compared to your other monitors, but that's often the case, as these are usually lower-resolution screens.
-   **Window Positioning**: Moves the AIDA64 "SensorPanel" window to the top-left corner (0,0) of the target monitor.
-   **Admin Privileges Check**: Ensures the script is run with administrator rights, which is required to move application windows.
-   **RDP Session Detection**: The script will not run if an active Remote Desktop Protocol (RDP) session is detected, as RDP sessions disable additional monitors, making it unnecessary to run the script in that scenario.
-   **Logging**: Creates a `move.log` file in the same directory as the script for troubleshooting.

## Configuration

Before running the script, you must configure two variables at the top of `move.ps1`:

1.  `$aida64Path`: Set this to the full path of your `aida64.exe` executable.
    ```powershell
    $aida64Path = "C:\Program Files (x86)\AIDA64 Extreme\aida64.exe"
    ```

2.  `$targetResolution`: Set this to the resolution of the monitor where you want the SensorPanel to be displayed, in the format `"WIDTHxHEIGHT"`.
    ```powershell
    $targetResolution = "1280x800"
    ```

## How to Schedule the Script

To make the script run automatically, you need to create a task in Windows Task Scheduler that triggers on both user logon and workstation unlock.

### Step 1: Open Task Scheduler

-   Press `Win + R`, type `taskschd.msc`, and press Enter.

### Step 2: Create a New Task

1.  In the right-hand pane, click **Create Task...** (not *Create Basic Task*).

2.  **General Tab**:
    -   **Name**: Give it a descriptive name, like `Move AIDA64 SensorPanel`.
    -   **Security options**: Select **Run whether user is logged on or not**.
    -   Check the **Run with highest privileges** box. This is critical for the script to work.
    -   Click **Change User or Group...** and enter `SYSTEM` as the object name, then click OK. The task will run under the `SYSTEM` account.

3.  **Triggers Tab**:
    -   Click **New...** to add the first trigger.
        -   **Begin the task**: `At log on`
        -   Select **Any user**.
        -   Click **OK**.
    -   Click **New...** again to add the second trigger.
        -   **Begin the task**: `On workstation unlock`
        -   Select **Any user**.
        -   Click **OK**.

4.  **Actions Tab**:
    -   Click **New...**.
    -   **Action**: `Start a program`.
    -   **Program/script**: `powershell.exe`
    -   **Add arguments (optional)**: `-ExecutionPolicy Bypass -File "d:\AIDA64_FIX\move.ps1"`
        -   **Important**: Replace `d:\AIDA64_FIX\move.ps1` with the actual full path to your script.
    -   Click **OK**.

5.  **Conditions Tab**:
    -   (Optional) You can uncheck **Start the task only if the computer is on AC power** if you are using a laptop and want it to run on battery.

6.  **Settings Tab**:
    -   Ensure **Allow task to be run on demand** is checked.
    -   (Optional) You can set **Stop the task if it runs longer than:** to `1 hour`.

7.  Click **OK** to save the task. You may be prompted to enter your password.

Now, the script will automatically run whenever you log on or unlock your workstation, positioning the AIDA64 SensorPanel on your desired monitor.

## License

This project is licensed under the [Creative Commons Attribution-NonCommercial 4.0 International License](LICENSE). See the `LICENSE` file for details.