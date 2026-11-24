#!/bin/bash
# all single-age pages that hold ages 15-44, by year
cd "C:/Users/kikep/AppData/Local/Temp/claude/26bb97bca44464b8/d65f9a45-e428-4f13-9fc0-de9e3574b4f1/scratchpad/spain_ocr2"
R="/c/Program Files/R/R-4.5.2/bin/Rscript.exe"
declare -A P=( [1933]=176,177,178 [1934]=29,30,31 [1935]=28,29,30 [1936]=29,30,31 [1937]=29,30,31 [1938]=29,30,31 [1939]=31,32,33 [1940]=29,30,31 [1941]=60,61,62,63,64,65 [1942]=60,61,62,63,64,65 [1943]=60,61,62,63,64,65 [1944]=60,61,62,63,64,65 [1945]=60,61,62,63,64,65 [1946]=60,61,62,63,64,65 )
for y in 1933 1934 1935 1936 1937 1938 1939 1940 1941 1942 1943 1944 1945 1946; do
  if [ $y -ge 1941 ]; then export OLDSTYLE=1; else export OLDSTYLE=0; fi
  "$R" step1.R $y ${P[$y]} tess 2>&1 | grep -E "^$y|Error"
  "$R" step2.R $y 2>&1 | grep -E "LOO|Error"
  "$R" step4.R $y 2>&1 | grep -v "built under\|^Warn" > step4_$y.log
  echo "$y: $(grep -A3 'by status' step4_$y.log | tail -2 | tr '\n' ' ')"
done
echo ALL DONE
