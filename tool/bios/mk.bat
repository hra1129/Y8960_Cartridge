if exist y8960bas.rom (
	..\zx0pack.exe header.bin y8960bas.rom MSXSSE.ROM
) else (
	copy /B dummy.bin MSXSSE.ROM
)
