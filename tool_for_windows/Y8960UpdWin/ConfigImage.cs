// -----------------------------------------------------------------------------
//	Y8960UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
using System;
using System.IO;
using System.Text;

namespace Y8960UpdWin
{
	// Update images: +0 signature (32 bytes), +32 version (16 bytes), +48 payload.
	// Byte 31 is the format marker: 0 = raw payload (legacy), 1 = ZX0 block
	// compressed payload (see DecompressPayload). Any other value is invalid.
	internal sealed class ConfigImage
	{
		public const int SignatureSize = 32;
		public const int VersionSize = 16;
		public const int HeaderSize = SignatureSize + VersionSize;
		public const int MaxDataSize = 0x7D0000;
		public const int MaxBlockSize = 0x4000;
		public const int VersionBlockAddress = 0x7D0000;
		public const int VersionBlockSize = 0x10000;
		public const int VersionAddress = 0x7DFF00;
		public const int BiosAddress = 0x7E0000;
		public const int BiosDataSize = 0x20000;
		public const int BiosVersionAddress = 0x7DFF10;

		private static readonly byte[] ConfigSignature = MakeSignature( "Y8960_TP25K_CARTRIDGE" );
		private static readonly byte[] BiosSignature = MakeSignature( "Y8960_BIOS_IMAGE" );

		public byte[] Data { get; private set; }
		public byte[] VersionBytes { get; private set; }
		public string VersionText { get { return DecodeVersion( VersionBytes ); } }

		private ConfigImage() { }

		public static ConfigImage Load( string path, bool bios, out string error )
		{
			error = null;
			byte[] image;
			try {
				image = File.ReadAllBytes( path );
			}
			catch( IOException ) {
				error = "Cannot open the file.";
				return null;
			}
			catch( UnauthorizedAccessException ) {
				error = "Cannot open the file.";
				return null;
			}
			return Parse( image, bios, out error );
		}

		public static ConfigImage Parse( byte[] image, bool bios, out string error )
		{
			error = null;
			byte[] signature = bios ? BiosSignature : ConfigSignature;
			string invalidImage = bios ? "This file is not a valid Y8960 BIOS image."
				: "This file is not a valid Y8960 Config image.";
			if( image == null || image.Length < SignatureSize ) {
				error = invalidImage;
				return null;
			}
			// Bytes 0..30 must match the signature; byte 31 is the format marker.
			for( int i = 0; i < SignatureSize - 1; i++ ) {
				if( image[ i ] != signature[ i ] ) {
					error = invalidImage;
					return null;
				}
			}
			byte marker = image[ SignatureSize - 1 ];
			if( marker != 0 && marker != 1 ) {
				error = invalidImage;
				return null;
			}

			byte[] data;
			if( marker == 0 ) {
				int dataSize = image.Length - HeaderSize;
				if( bios ? dataSize != BiosDataSize : dataSize < 1 || dataSize > MaxDataSize ) {
					error = "Invalid data size.";
					return null;
				}
				data = new byte[ dataSize ];
				Array.Copy( image, HeaderSize, data, 0, dataSize );
			}
			else {
				data = DecompressPayload( image, bios, invalidImage, out error );
				if( data == null ) {
					return null;
				}
			}

			var result = new ConfigImage();
			result.VersionBytes = new byte[ VersionSize ];
			Array.Copy( image, SignatureSize, result.VersionBytes, 0, VersionSize );
			result.Data = data;
			return result;
		}

		// Compressed payload: +48 original size (uint32 LE), +52 block size
		// (uint16 LE), then frames until the original size is produced.
		// Each frame starts with a uint16 LE word: bit 15 set = stored block
		// (low 15 bits are the length, which equals the block output length),
		// otherwise the word is the length of one independent ZX0 stream that
		// decompresses to the block output length. The image must end exactly
		// after the last frame.
		private static byte[] DecompressPayload( byte[] image, bool bios, string invalidImage, out string error )
		{
			error = null;
			if( image.Length < HeaderSize + 6 ) {
				error = invalidImage;
				return null;
			}
			long originalSize = (long)( (uint)image[ HeaderSize ]
				| ( (uint)image[ HeaderSize + 1 ] << 8 )
				| ( (uint)image[ HeaderSize + 2 ] << 16 )
				| ( (uint)image[ HeaderSize + 3 ] << 24 ) );
			int blockSize = image[ HeaderSize + 4 ] | ( image[ HeaderSize + 5 ] << 8 );
			if( blockSize < 1 || blockSize > MaxBlockSize ) {
				error = invalidImage;
				return null;
			}
			if( bios ? originalSize != BiosDataSize : originalSize < 1 || originalSize > MaxDataSize ) {
				error = "Invalid data size.";
				return null;
			}

			var data = new byte[ (int)originalSize ];
			int pos = HeaderSize + 6;
			int produced = 0;
			while( produced < data.Length ) {
				int expectedOut = Math.Min( blockSize, data.Length - produced );
				if( pos + 2 > image.Length ) {
					error = invalidImage;
					return null;
				}
				int word = image[ pos ] | ( image[ pos + 1 ] << 8 );
				pos += 2;
				if( ( word & 0x8000 ) != 0 ) {
					int length = word & 0x7FFF;
					if( length != expectedOut || pos + length > image.Length ) {
						error = invalidImage;
						return null;
					}
					Array.Copy( image, pos, data, produced, length );
					pos += length;
				}
				else {
					if( word < 1 || word > MaxBlockSize || pos + word > image.Length ) {
						error = invalidImage;
						return null;
					}
					byte[] block;
					try {
						block = Zx0.Decompress( image, pos, word, expectedOut );
					}
					catch( InvalidDataException ) {
						error = invalidImage;
						return null;
					}
					Array.Copy( block, 0, data, produced, expectedOut );
					pos += word;
				}
				produced += expectedOut;
			}
			if( pos != image.Length ) {
				error = invalidImage;
				return null;
			}
			return data;
		}

		// 64KB image for 7D0000h-7DFFFFh: all FFh except the version string at 7DFF00h.
		public byte[] CreateVersionBlock( ConfigImage bios )
		{
			if( bios == null ) {
				throw new ArgumentNullException( nameof( bios ) );
			}
			var block = new byte[ VersionBlockSize ];
			for( int i = 0; i < block.Length; i++ ) {
				block[ i ] = 0xFF;
			}
			Array.Copy( VersionBytes, 0, block, VersionAddress - VersionBlockAddress, VersionSize );
			Array.Copy( bios.VersionBytes, 0, block, BiosVersionAddress - VersionBlockAddress, VersionSize );
			return block;
		}

		public static string DecodeVersion( byte[] bytes )
		{
			var sb = new StringBuilder();
			foreach( byte b in bytes ) {
				if( b == 0x00 ) {
					break;
				}
				sb.Append( ( b >= 0x20 && b < 0x7F ) ? (char)b : '?' );
			}
			return sb.ToString();
		}

		private static byte[] MakeSignature( string text )
		{
			var result = new byte[ SignatureSize ];
			byte[] ascii = Encoding.ASCII.GetBytes( text );
			Array.Copy( ascii, result, ascii.Length );
			return result;
		}
	}
}
