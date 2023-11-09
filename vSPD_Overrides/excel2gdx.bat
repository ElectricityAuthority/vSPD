cd /D "%~dp0"
gdxxrw vSPD_Overrides.xlsx output="../Override/vSPD_Overrides" squeeze=n @howtoread.inc

del "*.lst"
del "*.lxi"
del "*.log"
del "*.put"
del "*.txt"
*pause