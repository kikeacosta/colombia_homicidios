# Spain 1936-1939: published deaths from bombings, by province

`spain_bombing_deaths_province.csv`, used by `code/85_intl_spain_bombing.R`. Compiled 2026-11-24 from public web pages.

## What it is

- No source gives deaths from bombings by province. The main work, Solé i Sabaté and Villarroya, *España en llamas: la guerra civil desde el aire* (2003), and *Catalunya sota les bombes* (1986), is not online. Most figures come from it at second hand: Wikipedia ES and EN, Enciclopèdia.cat, the press and municipal archives.
- Each row adds up the towns with a published figure. Most provinces are therefore a floor, with only the named raids.
- The figures include artillery where the source does (Madrid, Valencia, Castellón, Cartagena, Almería). Madrid is mostly artillery during the siege.
- `deaths_low` and `deaths_high` are figures from other sources, or from a partial count. They are not intervals.

## National totals, for reference

| Total | What it covers | Source |
|---|---|---|
| about 9,000 | Republican zone | Wikipedia ES, from Solé i Sabaté and Villarroya (2003) and partial studies |
| 1,088 dead and 2,231 wounded | Nationalist zone | a postwar Francoist count cited by Solé i Sabaté and Villarroya (2003) |
| about 10,000 | both sides | Hugh Thomas, without a source |

The sum of this file is about 9,300.

## Left out

- **The road from Málaga to Almería, February 1937:** 3,000-5,000 dead among fleeing civilians, from aircraft and warships. This is a disputed figure, deaths along a road across three provinces, and not a bombing of a town.
- **The sieges of Oviedo and Gijón:** artillery, without a figure. The registry gives Oviedo 1,737 women among violent deaths in 1936-1939, 13 % of victims, the highest share outside Barcelona.
- **Bilbao, Aragón, the Nationalist-zone cities other than Cabra, and the towns of Catalonia** without a figure of their own.

## Share of women

There is no systematic figure.

- Alicante, Mercado raid of 25 May 1938: 100 men, 56 women and 10 children among the identified victims (Wikipedia EN), so 34 % women.
- Granollers, 31 May 1938: 111 women and 68 men, from a summary that could not be verified.
- The registry gives Barcelona in 1938, item 197 ("execution of civilians by the belligerent armies"): 1,301 men and 848 women, 39 % women. The bombings of March 1938 seem to be registered there.

Script 85 uses 0.40 where the source gives no share.
