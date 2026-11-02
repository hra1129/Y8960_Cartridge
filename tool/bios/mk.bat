if exist y8960bas.rom (
	..\zx0pack.exe header.bin y8960bas.rom MSXSSE.ROM
	copy /B header.bin+y8960bas.rom MSXSSE_UNCOMPRESS.ROM
) else (
	copy /B dummy.bin MSXSSE.ROM
)
