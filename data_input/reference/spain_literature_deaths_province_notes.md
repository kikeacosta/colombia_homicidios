# Published figures on Spanish civil-war and postwar deaths, by province: source notes

Companion to `spain_literature_deaths_province.csv` (316 rows, one number per row). Province names follow the INE spelling used in `intl_spain_excess_male_1936-1946.csv` (Alava, Avila, Castellón de la Plana, Coruña (La), Logroño, Oviedo, Palmas (Las), Santander, ...). A number from a regional table is only written to a province row when the region is a single province (Asturias = Oviedo, Cantabria = Santander, La Rioja = Logroño, Madrid, Murcia, Navarra, Baleares). Regional totals for regions with several provinces are listed below, or kept as `other` / `TOTAL` rows with a note saying so. No number was interpolated or derived.

Every row was taken from a document read in this session. Where the original book was not available and the number comes from a Wikipedia table or text, the `citation` says so ("as reproduced in ..." / "as given in ...").

## 1. Salas Larrazábal (1977), *Pérdidas de la guerra* → concept `violent_registered`

- **What it measures.** Salas counted deaths entered in the civil registries and published in the INE *Movimiento natural de la población* for 1936-1950 and later years. He then classified them as war wounds (military operations), executions and homicides in the "zona nacional", executions and homicides in the "zona gubernamental", and excess mortality. The province is the province of registration. Late registrations (1939-1960s) are folded back into the war. He assumed that every war death was eventually registered and that causes were recorded honestly. Later research rejects this: in Sevilla, only 32% of the 13,122 people killed by the rebels were ever entered in the registry death books (García Márquez 2012).
- **Closest to your estimate.** This is the closest published analogue to your measure (registered deaths by province). Two differences matter. Salas uses registered *causes* of death, while you use excess male deaths. Salas also reassigns late registrations to the war, while you keep the year of registration.
- **What was obtained.** Two 50-province tables, as reproduced in the Spanish Wikipedia annex "Mortalidad en la guerra civil española, por inscripción en juzgados":
  - **Military operations ("heridas de guerra")**: 50 provinces, summing exactly to the printed total of 136,913. The top provinces are Madrid 22,139, Oviedo 11,548, Barcelona 11,284, Zaragoza 6,960, Badajoz 5,760, Vizcaya 5,622 and Tarragona 5,473.
  - **Executions and homicides in the Nationalist zone**: 50 provinces, printed total 57,662. The Soria row (143) is probably a transcription error. It repeats the Soria value from the other table, and the rows sum to 57,793, which would make Soria 12. This is flagged in the CSV.
  - **Summary table**: provincial totals 266,919 (136,913 + 72,344 + 57,662). The grand total is 296,944, which adds Ceuta-Melilla, drowned and burned, maquis, guerrilleros and 25,500 foreigners.
- **Missing.** Salas's provincial table of Republican-zone executions (national total 72,344) was not found online. Neither was his provincial excess-mortality analysis.
- **Inconsistency between secondary summaries.** English Wikipedia ("Historiography ... (numbers)") says Salas gave 35,500 Nationalist and 72,500 Republican killings. The Spanish annex and the Spanish article "Represión en la zona sublevada" give 57,662 for the war, plus about 23,000 in the postwar. The CSV uses the Spanish tables.
- **National excess mortality** (as cited by Ortega & Silvestre 2005): 343,500 for 1936-1939 and 567,000 up to 1942.

## 2. Francoist repression → concept `francoist_repression`

**Espinosa Maestre (2008), *Informe sobre la represión franquista. Estado de la cuestión*.** This is the report Espinosa wrote for Judge Garzón's case (Diligencias Previas 399/2006-E). It is the best provincial table found online, read directly from the PDF.
- Cuadro 1 covers provinces "studied completely": total 111,063, written as 110,246 + 300 + 517. Cuadro 2 covers provinces studied only in part: 18,409, mostly single towns or capitals, all marked `incomplete_research`. The grand total is 129,472.
- The figures cover the war and the postwar (into the 1940s-1950s). They are counts of documented, named victims attributed to the province, usually by place of death and registration plus military and cemetery archives.
- Some rows are regional: Canarias 2,000, Castilla-León 14,660, Galicia 3,588, País Vasco 1,900, Ceuta-Melilla-Protectorado 768. These are not written as provinces, except the Castilla-León footnote breakdown into nine provinces. That footnote says the figures are minimums except for Segovia and Soria.
- The table has internal overlaps. Valladolid appears both on its own (3,430) and inside Castilla-León (3,000). Canarias 2,000 appears next to Las Palmas 1,000 and Tenerife 1,600. The extracted rows of Cuadro 1 sum to 109,671, not the printed 110,246.
- Galicia, the Basque provinces, Cuenca, Guadalajara, Lugo, Orense, Pontevedra, Coruña and Vizcaya have no provincial figure in this table.

**Espinosa & Ledesma (2012), "La violencia y sus mitos", in Viñas (ed.), *En el combate por la historia*, pp. 495-496.** This is the reference "latest" synthesis: 130,199 Francoist and 49,272 Republican victims.
- Only the table *by current autonomous community* was found, reproduced in Spanish Wikipedia. Provincial rows are written only for single-province communities.
- One Wikipedia article cites this work for Sevilla = 12,507 (p. 495), so the original table is probably provincial. The book was not accessible.
- The authors flag 16 provinces as incompletely studied for Francoist repression: Albacete, Avila, Burgos, Cádiz, Ciudad Real, Cuenca, Guadalajara, Las Palmas, León, Madrid, Murcia, Palencia, Salamanca, Tenerife, Valladolid and Zamora.
- The Francoist column includes the immediate postwar in zones occupied at the end of the war (Madrid, Valencia, Castilla-La Mancha, Murcia, parts of Andalucía).

Regional values (Francoist / Republican):

| Region | Francoist | Republican |
|---|---|---|
| Andalucía | 47,399 | 8,367 |
| Aragón | 8,523 | 3,901 |
| Asturias | 5,952 | 2,000 |
| Baleares | 2,300 | 323 |
| Canarias | 2,600 | - |
| Cantabria | 2,535 | 1,283 |
| Castilla-La Mancha | 10,358 | 7,524 |
| Castilla y León | 14,660 | 575 |
| Cataluña | 3,688 | 8,352 |
| Ceuta-Melilla-Protectorado | 768 | - |
| Extremadura | 10,594 | 1,567 |
| Galicia | 4,265 | - |
| Madrid | 3,204 | 8,815 |
| Murcia | 1,251 | 740 |
| Navarra | 3,280 | - |
| País Vasco | 1,900 | 945 |
| La Rioja | 2,000 | - |
| Comunidad Valenciana | 4,922 | 4,880 |
| **Total** | **130,199** | **49,272** |

**Other Francoist sources:**
- **Cobo Romero (coord.) 2012, Centro de Estudios Andaluces.** The eight Andalusian provinces for 1936-1951, total 50,093, sourced to Espinosa 2009 and García Márquez 2005. Sevilla is broken down into 10,590 killed under bandos de guerra, 664 executed by courts-martial and 1,255 disappeared, totalling 12,509. A further 465 died in prison and are not in that total.
- **García Márquez 2012, Sevilla 1936-1963.** 12,854 residents killed; 13,122 killed in the province including non-residents; 14,018 including deaths in prison. It also gives 517 victims of the left. Read directly.
- **UPNA Fondo Documental 2021, Navarra 1936-1948.** 3,507 deaths: 2,934 killings, 448 deaths in captivity and 125 other. It counts residents and people killed in Navarra. Read from the news report of the report's presentation.
- **Provincial monographs.** These come from the English Wikipedia table "Victims of the White Terror (Spain)". That table lists several competing numbers per province. Only numbers with an inline citation to a named study were transcribed, and the originals were **not** consulted. With these, all 50 provinces have at least one Francoist figure, but many are partial (one city, or a few towns) and are marked `incomplete_research`.
- **National.**
  - Juliá (coord.) 1999: 72,527 in the 24 provinces studied (Republican side: 37,843 in 22 provinces). The editors suggested doubling the Francoist figure and about 50,000 for the Republican side.
  - Casanova 2002: at least 50,000 postwar executions, over 35,000 counted in 33 provinces, and 4,663 prison deaths in 13 provinces.
  - Preston 2011: 130,199 is "the most reliable though provisional" figure, and probably not below 150,000.

**Comparability with your registration-based estimate.** These repression counts are mostly by date of death and by place of death or residence, depending on the study. Many victims of 1936 were never registered, or were registered years later. A count by year of registration will therefore place some of them in 1939-1945. Studies also differ in whether they include deaths in prison, and whether they run to 1945, 1950 or 1963.

## 3. Republican-zone repression → concept `republican_repression`

- **Espinosa 2008, Cuadro 3.** 32 provinces plus Cataluña as a region (8,352, from Solé i Sabaté & Villarroya); total 38,563. Provinces that stayed in the Nationalist zone appear as 0 (taken from Salas).
  - Main figures: Madrid 8,815 (Casas de la Vega), Valencia 2,844, Málaga 2,607, Ciudad Real 2,186, Córdoba 2,060, Teruel 1,702, Badajoz 1,416 (Causa General), Jaén 1,368, Santander 1,144 and Castellón 1,031.
  - The Zaragoza row (192) seems excluded from the printed total.
  - Missing from the table: Asturias, Vizcaya, Guipúzcoa, Toledo, Cuenca, Guadalajara and Huesca. The four Catalan provinces appear only as the regional figure for Cataluña.
- **Espinosa & Ledesma 2012.** National 49,272. The regional table is above.
- **Provincial monographs (via the English Wikipedia table):** Almería 465, Huesca 1,160, Jaén 1,924, Cuenca 516 and Lleida 1,232.
- **Not obtained.** No province-by-province table of the *Causa General* (85,940 claimed in its conclusions), Martín Rubio (1997, "Paz, piedad, perdón... y verdad"), or Salas's Republican-zone table was found online. Ortega & Silvestre (2005) report that Martín Rubio corrects Salas by about -15,000 in the Republican zone and +17,000 in the Nationalist zone, with no provincial detail.

## 4. Excess mortality → concept `excess_deaths`

- **Ortega & Silvestre (2005 conference version; 2006 in Martín Aceña & Martínez Ruiz (eds.), *La economía de la guerra civil*).**
  - **Method.** Observed deaths minus deaths expected from extrapolating 1926-1935 patterns, computed by province and provincial capital, then aggregated *by zone* (Nationalist / Republican, Cuadro 1 classification). Data are INE MNP definitive figures by year of registration, ages 1+, by sex. This is methodologically the closest published work to yours.
  - **Male excess:** 37,716 (1936); 68,917 (1937); 80,343 (1938); 77,263 (1939); 42,462 (1940); 77,243 (1941); 22,639 (1942). That is 264,240 for 1936-39 (Nationalist zone 110,685, Republican zone 153,555) and 406,584 for 1936-42.
  - **Female excess:** 81,694 for 1936-39 and 133,006 for 1936-42.
  - **Both sexes:** about 346,000 (1936-39) and 540,000 (1936-42).
  - **No provincial figures.** The paper says the provincial disaggregation would be published separately and posted as an Excel file on the author's Salamanca web page. The Wayback Machine has the paper and a seminar poster but not the Excel file. No provincial version was found.
  - **For your comparison.** Their 1940-42 male excess sums to 142,344, against your 98,000 (sum computed here, not published).
- **Del Arco Blanco (2021), "Famine in Spain During Franco's Dictatorship, 1939-52", *Journal of Contemporary History*.** The article itself could not be fetched; the repository blocks bots. In an interview the author gives about 200,000 famine deaths in 1939-1942, estimated as excess mortality. No provincial figures were seen. His 2006 article "Morir de hambre" (*Pasado y Memoria* 5) was read and has no provincial death table.
- **Moradiellos 2016** (via Spanish Wikipedia): 346,000-380,000 deaths from disease, hunger and privation during the war.
- **Gil Alonso & García Soler (2009, REIS 127).** Child mortality by province during the war, estimated from the 1940 census using the Brass method. Not recorded, because it gives rates for children, not death counts.
- **Not found.** No study by Ramiro Fariñas, Blanco or others giving provincial excess deaths for 1936-1945 was found online.

## 5. Military deaths → concept `military_deaths`

- No study giving soldiers' deaths by province of origin or death was found online.
- The nearest provincial series is Salas's "heridas de guerra" table (section 1, concept `violent_registered`). It is by province of *registration*, which concentrates on front and hospital provinces such as Madrid, Oviedo, Teruel, Zaragoza and Castellón. It is not the soldiers' home province.
- **National totals:**
  - Salas 165,764 deaths from war wounds, including 25,500 foreigners.
  - Thomas 1976 about 200,000 at the front (90,000 Nationalist, 110,000 Republican).
  - Gil Andrés 2014: 150,000-200,000.
  - All via Spanish Wikipedia, except Salas.

## Important sources not accessed

- **Espinosa & Ledesma 2012** (pp. 495-496) and **Espinosa (ed.) 2010, *Violencia roja y azul*** (pp. 77-78). These contain the up-to-date provincial tables for both repressions. Only the regional version and scattered provincial numbers were found.
- **Juliá (coord.) 1999, *Víctimas de la guerra civil*, appendix.** Provincial tables; only the national totals were found.
- **Preston 2011, *El holocausto español*.** No provincial appendix was found. The national figures come from the prologue as quoted in Wikipedia.
- **Salas 1977.** The Republican-zone provincial table and the provincial excess-mortality analysis.
- **Causa General and Martín Rubio (1997/1999).** Provincial tables.
- **Ortega & Silvestre.** The provincial Excel file.
- **Del Arco Blanco 2021.** The full text, blocked by the repository.
- **Ledesma's thesis** (EUI 2014, *Las justicias del pueblo*). Returned 403.
- **Solé i Sabaté & Villarroya.** The Catalan breakdown by province for both repressions.
- **Galicia: Nomes e Voces report.** 404; only the figures quoted in Wikipedia were used.

## Caveats

1. Repression studies count by **date and place of death (or residence)**, often of named victims. Salas and your estimate use **registration**. Many 1936-37 killings were registered late (1939-1941) or never.
2. Province attribution differs between studies:
   - Martín Rubio counts by place of death.
   - Espinosa and Navarra-UPNA count by residence, or by residence plus place of death.
   - García Márquez separates residents from non-residents.
3. The Francoist series mix wartime and postwar killings (to 1945, 1948, 1950 or 1963). The Republican series cover 1936-1939, concentrated in 1936.
4. National totals for the same author change over time:
   - Espinosa 2008: 129,472.
   - Espinosa & Ledesma 2012: 130,199.
   - Espinosa 2022: about 140,000 (via English Wikipedia; not recorded).
   - Juliá 1999: about 145,000 (implied).
