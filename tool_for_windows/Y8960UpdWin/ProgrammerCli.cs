// -----------------------------------------------------------------------------
//	Y8960UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace Y8960UpdWin
{
	internal sealed class CliResult
	{
		public int ExitCode;
		public string Output;
		public string CommandLine;

		public bool HasErrorText
		{
			get {
				string text = Output ?? "";
				return Regex.IsMatch( text, @"\bError\b|\bERROR\b" )
					|| Regex.IsMatch( text, @"\b(verify|verifying|program|programming|erase|erasing|write|read)\w*\s+(is\s+)?fail", RegexOptions.IgnoreCase );
			}
		}

		public bool Succeeded
		{
			get { return ExitCode == 0 && !HasErrorText; }
		}

		public string Tail( int lines )
		{
			string[] all = ( Output ?? "" ).Split( new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries )
				.Select( s => s.Trim() ).Where( s => s.Length > 0 ).ToArray();
			return string.Join( Environment.NewLine, all.Skip( Math.Max( 0, all.Length - lines ) ) );
		}
	}

	internal sealed class ProgrammerCli
	{
		public const string Device = "GW5A-25A";
		public const string Frequency = "2.5MHz";

		// Use the bitstream path, verified with operation 66, rather than the RISC-V C Bin path.
		private const int OpExFlashEraseProgramVerifyAroraV = 54;
		private const int OpReprogram = 1;

		public string Path { get; private set; }

		public ProgrammerCli( string path )
		{
			Path = path;
		}

		public Task<CliResult> ScanAsync( Action<string> onLine )
		{
			return RunAsync( "--scan", onLine );
		}

		public Task<CliResult> WriteBinaryAsync( string binFile, int address, Action<string> onLine )
		{
			string args = string.Format( "--device {0} --frequency {1} --run {2} --fsFile \"{3}\" --spiaddr 0x{4:X6}",
				Device, Frequency, OpExFlashEraseProgramVerifyAroraV, binFile, address );
			return RunAsync( args, onLine );
		}

		public Task<CliResult> ReprogramAsync( Action<string> onLine )
		{
			string args = string.Format( "--device {0} --frequency {1} --run {2}", Device, Frequency, OpReprogram );
			return RunAsync( args, onLine );
		}

		// Require an unambiguous single supported FPGA before allowing writes.
		public static bool IsTargetDevice( CliResult scan, out string reason )
		{
			reason = null;
			if( !scan.Succeeded ) {
				reason = UiText.DeviceNotFound;
				return false;
			}
			var names = Regex.Matches( scan.Output, @"\bGW\d[A-Z]*-\d+[A-Z0-9]*\b", RegexOptions.IgnoreCase )
				.Cast<Match>().Select( m => m.Value.ToUpperInvariant() ).Distinct().ToArray();
			// programmer_cli lists every IDCODE-compatible name of one device, e.g.
			// "Name: GW5A-25A GW5A-25B GW5AS-25A ... (One of them)".
			bool sameFamily = names.All( n => Regex.IsMatch( n, @"^GW5A[RS]?-25[AB]$" ) );
			var count = Regex.Match( scan.Output, @"(\d+)\s+device\(s\)\s+found", RegexOptions.IgnoreCase );
			bool single = !count.Success || count.Groups[ 1 ].Value == "1";
			if( !names.Contains( Device ) || !sameFamily || !single ) {
				reason = string.Format( UiText.NotConfirmedFormat,
					names.Length == 0 ? UiText.NoModelDetected : string.Join( ", ", names ),
					count.Success ? "\r\n" + count.Value : "" );
				return false;
			}
			return true;
		}

		private Task<CliResult> RunAsync( string arguments, Action<string> onLine )
		{
			return Task.Run( () => Run( arguments, onLine ) );
		}

		private CliResult Run( string arguments, Action<string> onLine )
		{
			string workDir = System.IO.Path.Combine( System.IO.Path.GetTempPath(), "Y8960UpdWin" );
			Directory.CreateDirectory( workDir );

			var psi = new ProcessStartInfo( Path, arguments ) {
				UseShellExecute = false,
				CreateNoWindow = true,
				RedirectStandardOutput = true,
				RedirectStandardError = true,
				WorkingDirectory = workDir,
				StandardOutputEncoding = Encoding.Default,
				StandardErrorEncoding = Encoding.Default,
			};
			// programmer_cli is a frozen Python program; ask it not to buffer piped progress output.
			psi.EnvironmentVariables[ "PYTHONUNBUFFERED" ] = "1";

			var output = new StringBuilder();
			var sync = new object();
			Action<string> emit = line => {
				lock( sync ) {
					output.AppendLine( line );
				}
				if( onLine != null ) {
					onLine( line );
				}
			};

			var result = new CliResult { CommandLine = "\"" + Path + "\" " + arguments };
			try {
				using( var process = Process.Start( psi ) ) {
					var stdout = Task.Run( () => Pump( process.StandardOutput, emit ) );
					var stderr = Task.Run( () => Pump( process.StandardError, emit ) );
					process.WaitForExit();
					Task.WaitAll( stdout, stderr );
					result.ExitCode = process.ExitCode;
				}
			}
			catch( Exception ex ) {
				emit( UiText.CliStartFailedPrefix + ex.Message );
				result.ExitCode = -1;
			}
			lock( sync ) {
				result.Output = output.ToString();
			}
			return result;
		}

		// Splits on CR as well as LF so that "\r"-updated progress lines are seen as they arrive.
		private static void Pump( StreamReader reader, Action<string> emit )
		{
			var line = new StringBuilder();
			var buffer = new char[ 256 ];
			int count;
			while( ( count = reader.Read( buffer, 0, buffer.Length ) ) > 0 ) {
				for( int i = 0; i < count; i++ ) {
					char c = buffer[ i ];
					if( c == '\r' || c == '\n' ) {
						if( line.Length > 0 ) {
							emit( line.ToString() );
							line.Clear();
						}
					}
					else {
						line.Append( c );
					}
				}
			}
			if( line.Length > 0 ) {
				emit( line.ToString() );
			}
		}
	}
}
