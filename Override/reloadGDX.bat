rem	Convert or reload all .gms files in the current directory to GDX files

for %%f in (*.gms) do gams "%%f" gdx="%%~nf.gdx"
del *.lst
