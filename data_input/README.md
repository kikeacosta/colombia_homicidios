# Input data

None of these files are versioned. Place them as below; script 01 expects
exactly the 45 files listed in `micro/`.

## micro/ (DANE EEVV, defunciones no fetales, 1979-2023)

Download from DANE's microdata catalogue, https://microdatos.dane.gov.co
(Estadísticas Vitales, Defunciones no fetales, one file per year).
Dictionaries are in `documents/metadata/`.

| file | bytes |
|---|---|
| Defun1979.txt | 4968113 |
| Defun1980.txt | 5650898 |
| Defun1981.txt | 6277838 |
| Defun1982.txt | 6195623 |
| Defun1983.txt | 6313253 |
| Defun1984.txt | 6173618 |
| Defun1985.txt | 6927728 |
| Defun1986.txt | 6585683 |
| Defun1987.txt | 6838178 |
| Defun1988.txt | 6888128 |
| Defun1989.txt | 6961343 |
| Defun1990.txt | 6960938 |
| Defun1991.txt | 7366253 |
| Defun1992.txt | 8890434 |
| Defun1993.txt | 8938368 |
| Defun1994.txt | 8934168 |
| Defun1995.txt | 9004415 |
| Defun1996.txt | 9195865 |
| Defun1997.txt | 9332447 |
| Defunciones 1998.txt | 19472282 |
| Defunciones_1999.txt | 20608162 |
| Defunciones_2000.txt | 23324715 |
| Defunciones_2001.txt | 24244415 |
| Defunciones_2002.txt | 24335638 |
| Defunciones_2003.txt | 24319617 |
| Defunciones_2004.txt | 23972210 |
| Defunciones_2005.txt | 24121859 |
| Defunciones_2006.txt | 24870190 |
| Defunciones_2007.txt | 25247079 |
| Defun_2008.txt | 36981185 |
| Defun_2009.txt | 38350992 |
| Defun_2010.txt | 42477168 |
| Defun_2011.txt | 45990164 |
| Defun_2012.txt | 47415969 |
| Defun_2013.txt | 48908425 |
| Defun_2014.txt | 49403024 |
| Defun_2015.txt | 51669592 |
| Nofetal_2016.txt | 53650053 |
| nofetal2017.csv | 36235677 |
| nofetal2018.csv | 37540563 |
| nofetal2019.csv | 35605603 |
| nofetal2020.csv | 72718654 |
| nofetal2021.csv | 89063048 |
| nofetal2022.csv | 69771386 |
| nofetal2023.csv | 65288762 |

## DANEpop/ (municipal population projections 1985-2017)

DANE, Proyecciones de población, municipal by area, sex and age:
`DCD-area-sexo-edad-proypoblacion-Mun-1985-1994.xlsx`,
`DCD-area-sexo-edad-proypoblacion-Mun-1995-2004.xlsx`,
`DCD-area-sexo-edad-proypoblacion-Mun-2005-2017_VP.xlsx`.

## ucdp/ (historical module only)

`GEDEvent_v25_1.csv` and `GEDEvent_v25_01_25_12.csv`, from
https://ucdp.uu.se/downloads/ (UCDP GED global version 25.1 and the
January-December 2025 monthly release).

## reference/ and historical/ (versioned)

`reference/`: DIVIPOLA municipality codes (DANE, March 2026).
`historical/`: series transcribed from DANE anuarios estadísticos, 1923-1984.
