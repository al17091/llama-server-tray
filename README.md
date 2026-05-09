# llama-server Windows Service & Tray Manager

This tool allows you to run `llama-server` (llama.cpp) as a Windows service in the background stably and manage it easily (start, stop, check logs) from the system tray.

## 🌟 Key Features

* **Background Execution**: No need to keep a command prompt window open.

* **Tray Icon Management**: Control the server with a single click from the taskbar tray icon (bottom right of your screen).

* **Automated Log Management**: Outputs logs to the `logs` folder and automatically rotates them every 10MB (keeps the last 5 generations).

* **Safe Shutdown**: Clicking "Quit" safely stops the background service before exiting the manager.

## 📂 Preparation

After cloning or downloading this repository, please prepare the following in the project folder:

1. **Setup WinSW and Folders**

   * Download `WinSW-x64.exe` from [WinSW (Windows Service Wrapper)](https://github.com/winsw/winsw/releases).

   * Rename the downloaded file to `llama-service.exe` and place it in the same folder as the scripts in this repository.

   * **Manually create an empty folder named `logs` in the same directory for log outputs.**

2. **Configuration (Optional)**

   * Modify `llama-service.xml` according to your environment (model path, arguments `<arguments>`, port, etc.).

## 🚀 Installation (First Time Only!)

1. Open a terminal (such as PowerShell) with Administrator privileges and navigate to this folder.

2. Run the following command to register it as a Windows service:


```

.\llama-service.exe install

```

> **⚠️ Note:** The `install` command only needs to be run **once**. If you run it when it is already installed, you will see an error saying `A service with ID 'llama-server' already exists.` - this is completely normal.

## 🎮 Usage

### Starting the Manager

Right-click `llama-manager.ps1` and select **"Run with PowerShell"**.
*(Note: You will be prompted for Administrator privileges (UAC) because the script needs to control Windows services. Click "Yes".)*

### Menu Operations

Right-click the tray icon to perform the following actions:

* **Start Server**: Starts llama-server in the background.

* **Stop Server**: Stops llama-server.

* **Show Log (Notepad)**: Opens the latest operation log in the `logs` folder with Notepad.

* **Quit**: Exits the manager. **(This will automatically stop the llama-server service as well.)**

## ⚙️ How to Apply Configuration Changes

If you change the model or arguments (`<arguments>`), **reinstallation is not required**. Just restarting the service will apply the changes.

1. Click **Stop Server** from the tray icon to stop the server.

2. Edit `llama-service.xml` with Notepad, update the values, and save the file.

3. Click **Start Server** from the tray icon to start it again.

### 🔄 Re-registering the Service (When changing log settings, etc.)

If you change **structural XML settings** like `<logpath>`, you must update the Windows service registration by reinstalling it.

1. Click **Stop Server** from the manager to completely stop the server.

2. Edit and save your `llama-service.xml`.

3. Open PowerShell as Administrator in the management folder and run the following commands sequentially:


```

.\llama-service.exe uninstall
.\llama-service.exe install

```

4. Click **Start Server** from the manager to restart.

## 🗑️ Complete Uninstallation (Removal)

If you no longer want to use this tool or wish to completely remove the service registration, open PowerShell as Administrator in the management folder and run the following commands:


```

# Stop the service first

.\llama-service.exe stop

# Remove the service registration

.\llama-service.exe uninstall

```

This will cleanly remove it from the Windows Services list.

## 💡 Bonus: Auto-start on PC Boot

You don't have to manually run the script every time. You can set the manager to automatically appear in the tray when the PC boots (while hiding the black console window).

1. Right-click `llama-manager.ps1` and select "Create shortcut".

2. Right-click the created shortcut and open "Properties".

3. Add `powershell.exe -WindowStyle Hidden -File ` to the very beginning of the "Target" field.
   *(Example: `powershell.exe -WindowStyle Hidden -File "C:\MyLLM\Manager\llama-manager.ps1"`)*

4. Press `Win + R`, type `shell:startup`, and press Enter.

5. Move the modified shortcut into the Startup folder that opened.

