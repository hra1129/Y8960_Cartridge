// -----------------------------------------------------------------------------
//	Y8960UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
using System;
using System.IO;

namespace Y8960UpdWin
{
	// ZX0 decompressor (standard format), ported from dzx0.c by Einar Saukas
	// (BSD 3-Clause License). Decompresses exactly one independent ZX0 stream:
	// the input slice must be consumed completely and must produce exactly
	// expectedOutputLength bytes, otherwise InvalidDataException is thrown.
	internal static class Zx0
	{
		public static byte[] Decompress( byte[] data, int offset, int length, int expectedOutputLength )
		{
			if( data == null ) {
				throw new ArgumentNullException( nameof( data ) );
			}
			if( offset < 0 || length < 0 || offset + length > data.Length || expectedOutputLength < 0 ) {
				throw new InvalidDataException( "ZX0 input is out of range." );
			}
			var decoder = new Decoder( data, offset, length, expectedOutputLength );
			return decoder.Decode();
		}

		private sealed class Decoder
		{
			private readonly byte[] _data;
			private readonly int _end;
			private readonly byte[] _output;
			private int _pos;
			private int _outPos;
			private int _bitMask;
			private int _bitValue;
			private int _lastByte;
			private bool _backtrack;

			public Decoder( byte[] data, int offset, int length, int expectedOutputLength )
			{
				_data = data;
				_pos = offset;
				_end = offset + length;
				_output = new byte[ expectedOutputLength ];
			}

			public byte[] Decode()
			{
				int lastOffset = 1;
				int length;

			CopyLiterals:
				length = ReadEliasGamma( false );
				for( int i = 0; i < length; i++ ) {
					WriteByte( ReadByte() );
				}
				if( ReadBit() != 0 ) {
					goto CopyFromNewOffset;
				}

				// Copy from last offset.
				length = ReadEliasGamma( false );
				CopyFromOffset( lastOffset, length );
				if( ReadBit() == 0 ) {
					goto CopyLiterals;
				}

			CopyFromNewOffset:
				lastOffset = ReadEliasGamma( true );
				if( lastOffset == 256 ) {
					// End marker: the stream and the output must end exactly here.
					if( _pos != _end ) {
						throw new InvalidDataException( "ZX0 input is not fully consumed." );
					}
					if( _outPos != _output.Length ) {
						throw new InvalidDataException( "ZX0 output is too short." );
					}
					return _output;
				}
				lastOffset = lastOffset * 128 - ( ReadByte() >> 1 );
				_backtrack = true;
				length = ReadEliasGamma( false ) + 1;
				CopyFromOffset( lastOffset, length );
				if( ReadBit() != 0 ) {
					goto CopyFromNewOffset;
				}
				goto CopyLiterals;
			}

			private int ReadByte()
			{
				if( _pos >= _end ) {
					throw new InvalidDataException( "ZX0 input overrun." );
				}
				_lastByte = _data[ _pos++ ];
				return _lastByte;
			}

			private int ReadBit()
			{
				if( _backtrack ) {
					_backtrack = false;
					return _lastByte & 1;
				}
				_bitMask >>= 1;
				if( _bitMask == 0 ) {
					_bitMask = 128;
					_bitValue = ReadByte();
				}
				return ( _bitValue & _bitMask ) != 0 ? 1 : 0;
			}

			// Interlaced Elias gamma coding (inverted only for the offset MSB).
			private int ReadEliasGamma( bool inverted )
			{
				int value = 1;
				while( ReadBit() == 0 ) {
					value = ( value << 1 ) | ( ReadBit() ^ ( inverted ? 1 : 0 ) );
					if( value > 0x100000 ) {
						throw new InvalidDataException( "ZX0 value is too large." );
					}
				}
				return value;
			}

			private void WriteByte( int value )
			{
				if( _outPos >= _output.Length ) {
					throw new InvalidDataException( "ZX0 output overrun." );
				}
				_output[ _outPos++ ] = (byte)value;
			}

			private void CopyFromOffset( int offset, int length )
			{
				if( offset < 1 || offset > _outPos ) {
					throw new InvalidDataException( "ZX0 offset is out of range." );
				}
				while( length-- > 0 ) {
					WriteByte( _output[ _outPos - offset ] );
				}
			}
		}
	}
}
