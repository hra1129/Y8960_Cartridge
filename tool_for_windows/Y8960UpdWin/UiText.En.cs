// -----------------------------------------------------------------------------
//	Y8960UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
//
//	UI text table, English build. UiText.Ja.cs declares exactly the same
//	members in Japanese; the project compiles only one of the two files,
//	selected by the UiLanguage MSBuild property (default: Ja).
//

namespace Y8960UpdWin
{
	internal static class UiText
	{
		// Font for the forms. "Segoe UI" ships with English Windows
		// installations, which may not have the Japanese font.
		public const string FontName = "Segoe UI";

		// Wizard navigation buttons.
		public const string BackButton = "< Back";
		public const string NextButton = "Next >";
		public const string CancelButton = "Cancel";
		public const string DoneButton = "Done";

		// Page 1: file selection.
		public const string FilePageTitle = "1. Select the Update Files";
		public const string FilePageCaption = "Select both the Config and BIOS files (both will be updated).\r\nType or drop a file into each field, or select it with [Browse...].";
		public const string BrowseButton = "Browse...";
		public const string SelectConfigFileTitle = "Select Y8960CFG.BIN";
		public const string SelectBiosFileTitle = "Select Y8960BIOS.BIN";
		public const string ConfigFileFilter = "Y8960 Config image (*.bin)|*.bin|All files (*.*)|*.*";
		public const string BiosFileFilter = "Y8960 BIOS image (*.bin;*.rom)|*.bin;*.rom|All files (*.*)|*.*";
		public const string ConfigFileNotFound = "The Config file was not found.";
		public const string BiosFileNotFound = "The BIOS file was not found.";
		public const string ConfigFileNotUsable = "This file cannot be used as the Config file.";
		public const string BiosFileNotUsable = "This file cannot be used as the BIOS file.";

		// Page 2: connection.
		public const string ConnectPageTitle = "2. Connect the Y8960 Cartridge";
		public const string ConnectPrompt = "Please connect the Y8960 Cartridge.";
		public const string ConnectCaption = "Connect the TangPrimer25K's USB connector to the PC with a USB cable, then click [Next].\r\nIf GOWIN Programmer (GUI) is running, close it before continuing.";
		public const string ChangeCliLink = "Change CLI...";
		public const string CheckingConnection = "Checking the connection...";

		// Page 3: write.
		public const string WritePageTitle = "3. Write";
		public const string WritePageCaption = "The Config, BIOS and both version data are erased, written and verified in this order.\r\nTurn the MSX power off and run on USB power. Do not unplug the USB cable until it finishes.";
		public const string StartWriteButton = "Start Write";
		public const string ConfigToWrite = "Config to write: ";
		public const string BiosToWrite = "BIOS to write: ";
		public const string WrittenConfig = "Written Config: ";
		public const string WrittenBios = "Written BIOS: ";
		public const string StepConnectionCheck = "Connection check";
		public const string StepVersion = "Version data";
		public const string StepReprogram = "FPGA restart";
		public const string WriteCompleted = "Write completed successfully.";
		public const string ReprogramFailedMessage = "The write completed successfully, but the FPGA restart failed.\r\nUnplug and reconnect the USB cable to restart the Y8960 Cartridge.";
		public const string UpdateFailed = "The update failed. The Flash contents may be incomplete.";
		public const string TempDeleteFailedPrefix = "Could not delete the temporary file: ";
		public const string WriteFailedFormat = "Failed to write the {0}. The version area was not updated.";
		public const string VersionWriteFailed = "Failed to write the version data.";
		public const string WriteFailedMessage = "The write failed.\r\nThe ConfigROM in Flash may be left incomplete, so try writing again, or write it with GOWIN Programmer.";
		public const string PhaseErasing = "Erasing";
		public const string PhaseWriting = "Writing";
		public const string PhaseVerifying = "Verifying";
		public const string PhasePreparing = "Preparing";

		// ProgrammerPathForm (programmer_cli.exe path dialog).
		public const string PathFormTitle = "Specify the GOWIN Programmer CLI";
		public const string PathFormMessage = "The GOWIN Programmer CLI (programmer_cli.exe) was not found.\r\nSpecify the programmer_cli.exe in the GOWIN Programmer installation folder.\r\nExample: C:\\Gowin\\Gowin_V1.9.12.03_x64\\Programmer\\bin\\programmer_cli.exe";
		public const string SelectCliTitle = "Select programmer_cli.exe";
		public const string CliFileFilter = "programmer_cli.exe|programmer_cli.exe|Executable files (*.exe)|*.exe";
		public const string CliNotFoundAtPath = "There is no programmer_cli.exe at the specified path.";

		// ProgrammerCli device check results and log lines.
		public const string DeviceNotFound = "The Y8960 Cartridge (TangPrimer25K) was not found.";
		public const string NotConfirmedFormat = "A TangPrimer25K (GW5A-25A) could not be confirmed.\r\nDetected: {0}{1}";
		public const string NoModelDetected = "(no FPGA model detected)";
		public const string CliStartFailedPrefix = "Error: Could not start programmer_cli: ";

		// Combines the two parts of an error dialog. Both parts are English
		// in this build: when the detail repeats the message (or is empty),
		// the message is shown once instead of twice.
		public static string FormatError( string message, string detail )
		{
			if( string.IsNullOrEmpty( detail ) || message == detail ) {
				return message;
			}
			return message + "\r\n\r\n" + detail;
		}
	}
}
