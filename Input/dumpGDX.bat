rem	Dump all GDX files in the current directory into .gms files

for %%f in (*.gdx) do gdxdump "%%f" > "%%~nf.gms"
