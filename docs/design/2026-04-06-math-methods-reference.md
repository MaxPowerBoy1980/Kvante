# Matematiske metoder — referenceark for Kvante

> Kilde: [webmatematik.dk](https://www.webmatematik.dk/lektioner/7-9-klasse/) + whiteboard-fotos (Dropbox/Screenshots 2026-04-06)
> Formål: Definerer hvordan Kvante forklarer og animerer hvert emne.
> Hentet: 2026-04-06

---

## 1. Multiplikation

### 1a. Krydset (kryds-multiplikation)

**Kilde:** Whiteboard-foto (`Screenshot 2026-04-06 at 08.56.58.png`)

**Metode:** Flercifret x flercifret via krydsende linjer. Cifrene forbindes diagonalt, delprodukter summeres position for position.

**Eksempel:** 21 x 7
```
     (1)          <- mente
   5|1|
  18|4| = 147
  28|7|
      -> <- KOMMA (decimalplacering)
```

**Animation-trin:**
1. Tegn kryds-gitteret med cifrene
2. Highlight forste kryds-par, vis delprodukt
3. Highlight naeste kryds-par, vis delprodukt
4. Summer delprodukter per kolonne (med mente)
5. Vis slutresultat

**Ny visual type:** `cross_multiplication`
**Actions:** `setup_grid`, `highlight_cross`, `compute_partial`, `carry`, `reveal_result`

---

### 1b. Lang multiplikation (standard opstilling)

**Kilde:** Whiteboard-foto (`Screenshot 2026-04-06 at 08.49.51.png`)

**Metode:** Multiplicer med hvert ciffer separat, skriv delprodukter forskudt, summer til sidst.

**Eksempel:** 206 * 14
```
  206 * 14
  --------
     824    <- 206 x 4
   2060     <- 206 x 10
  --------
   2884
  ========
```

**Animation-trin:**
1. Setup: Vis 206 * 14 i opstilling
2. Multiplicer med enere (4): 206 x 4 = 824
3. Skriv 824 under stregen
4. Multiplicer med tiere (1): 206 x 1 = 206, forskyd til 2060
5. Skriv 2060 under 824
6. Tegn streg, summer: 824 + 2060 = 2884
7. Dobbelt understregning af resultat

**Kan udvide eksisterende:** `stacked_arithmetic` med nye actions
**Nye actions:** `write_partial_product`, `shift_left`, `sum_partials`, `double_underline`

---

## 2. Division

### 2a. Den gammeldags (lang division)

**Kilde:** Whiteboard-foto (`Screenshot 2026-04-06 at 08.52.18.png`)

**Metode:** Traditionel lang division med bracket. Divider/subtraher/ryk-ned cyklus.

**Eksempel:** 588 : 4 = 147
```
    147
  ------
  588 : 4
  4
  --
  18
  16
  ---
   28
   28
   --
    0
```

**Animation-trin:**
1. Setup: Skriv 588 : 4 med bracket og plads til kvotienten oven over
2. Fokuser pa forste ciffer: 5 / 4 = 1, skriv 1 i kvotienten
3. Skriv 4 under 5, tegn streg, subtraher: 5 - 4 = 1
4. Ryk naeste ciffer ned (8): far 18
5. 18 / 4 = 4, skriv 4 i kvotienten
6. Skriv 16 under 18, subtraher: 18 - 16 = 2
7. Ryk naeste ciffer ned (8): far 28
8. 28 / 4 = 7, skriv 7 i kvotienten
9. Skriv 28 under 28, subtraher: 28 - 28 = 0
10. Vis slutresultat: 588 : 4 = 147

**Ny visual type:** `long_division`
**Actions:** `setup_bracket`, `focus_digit`, `write_quotient_digit`, `write_product`, `subtract`, `bring_down`, `show_remainder`, `reveal_result`

---

### 2b. Den der ikke fylder (kort division)

**Kilde:** Whiteboard-foto (`Screenshot 2026-04-06 at 08.55.04.png`)

**Metode:** Kompakt inline notation. Kommaer separerer ciffergrupper der behandles venstre-til-hojre.

**Eksempel:** 588 : 4 = 147
```
  5,88 : 4 = 147
```

**Animation-trin:**
1. Skriv divisionen: 588 : 4
2. Indsaet kommaer: 5,88 (marker ciffergrupper)
3. 5 / 4 = 1 rest 1 -> skriv 1
4. 18 / 4 = 4 rest 2 -> skriv 4
5. 28 / 4 = 7 rest 0 -> skriv 7
6. Vis slutresultat: = 147

**Ny visual type:** `short_division`
**Actions:** `setup_inline`, `insert_commas`, `process_group`, `write_result_digit`, `reveal_result`

---

### 2c. Kort division med rest/decimal

**Kilde:** Whiteboard-foto (`Screenshot 2026-04-06 at 08.55.23.png`)

**Metode:** Udvidelse af kort division der handterer rest -> brok -> decimal.

**Eksempel:** 589 : 4 = 147 1/4 = 147,25
```
  5,89 : 4 = 147 1/4 = 147,25
```

**Animation-trin:**
1-5. Samme som kort division
6. Rest: 589 - 588 = 1
7. Vis rest som brok: 1/4 -> 147 1/4
8. Omregn brok til decimal: 1/4 = 0,25 -> 147,25

**Udvider:** `short_division` med nye actions
**Nye actions:** `show_remainder_fraction`, `convert_to_decimal`

---

## 3. Broker

> Kilde: webmatematik.dk/lektioner/7-9-klasse/broker/

### 3a. Hvad er en brok?

**Terminologi:**
- **Brokstreg** — den vandrette linje
- **Taeller** — tallet over stregen (numerator)
- **Naevner** — tallet under stregen (denominator)

**Paedagogik:** Kage/pizza-analogi. Pizza skaret i 8 stykker, Pia spiser 2 = 2/8. Aebler delt mellem tre personer: 5/3.

**Visual types:** `pie_chart` (allerede implementeret), `bar_model` (allerede implementeret)

### 3b. Brokers storrelse (sammenligning)

**Metode:** Find faellesnaevner -> forlaeng -> sammenlign taellere.

**Princip:** "Jo storre naevneren blir, des mindre blir broken" (med fast taeller).

**Eksempel:** 5/6 vs 3/4 -> forlaeng til 10/12 vs 9/12 -> 5/6 er storst.

**Terminologi:**
- **Forlaenge** — gang taeller og naevner med samme tal
- **Forkorte** — divider taeller og naevner med samme tal
- **Faellesnaevner** — faelles naevner for sammenligning

### 3c. Regneregler for broker

| Operation | Regel | Eksempel |
|-----------|-------|----------|
| Addition | Faellesnaevner, adder taellere | 2/3 + 1/4 = 8/12 + 3/12 = 11/12 |
| Subtraktion | Faellesnaevner, subtraher taellere | 4/7 - 3/14 = 8/14 - 3/14 = 5/14 |
| Multiplikation | Gang taellere, gang naevnere | 4/5 x 2/7 = 8/35 |
| Division | Vend divisor, gang | 1/5 / (3/4) = 1/5 x 4/3 = 4/15 |

**Hele tal:**
- a/b x c = (a x c)/b  (eksempel: 3 x 2/7 = 6/7)
- a/b / c = a/(b x c)  (eksempel: 5/6 / 2 = 5/12)
- c / (a/b) = c x b/a  (eksempel: 8 / (19/2) = 16/19)

### 3d. Delen af det hele

**Metode:** Brok x storrelse = resultat.

**Eksempler:**
- 3/8 af 16 m = (3 x 16)/8 = 48/8 = 6 m
- 5/8 af 60 min = 300/8 = 75/2 = 37,5 minutter

### 3e. Blandede tal

**Definition:** Et tal der indeholder bade hele tal og broker. Der er et "skjult plus" mellem heltallet og broken.

**Uaegte brok -> blandet tal:** 13/4 -> 4 gar i 13 tre gange, rest 1 -> 3 1/4

**Blandet tal -> uaegte brok:** 7 2/3 -> (7x3)/3 + 2/3 = 21/3 + 2/3 = 23/3

### 3f. Omregning: brok-procent-decimaltal

| Fra | Til | Metode | Eksempel |
|-----|-----|--------|----------|
| Brok -> Procent | Forlaeng til naevner=100 | 1/4 = 25/100 = 25% |
| Procent -> Brok | Skriv som x/100, forkort | 64% = 64/100 = 16/25 |
| Brok -> Decimal | Divider taeller med naevner | 5/8 = 0,625 |
| Decimal -> Brok | Tal uden komma / 10^n, forkort | 0,125 = 125/1000 = 1/8 |
| Procent -> Decimal | Flyt komma 2 pladser til venstre | 98% = 0,98 |
| Decimal -> Procent | Flyt komma 2 pladser til hojre | 0,17 = 17% |

**Periodiske decimaltal:** 0,4444... = 4/9 (gang med 9, 99, 999... afhangigt af periodens laengde)

---

## 4. Procenter

> Kilde: webmatematik.dk/lektioner/7-9-klasse/procenter/

### 4a. Hvad er procenter?

**Definition:** "Procent" kommer fra latin "Per Centum" = per hundrede. 42% = 42/100 = 0,42.

**Kerneindsigt:** Procent ER en brok. At forstå procent kraever at forstå broker.

### 4b. Regneregler

**Procentandel (forholdet mellem to tal):**
```
(Tal2 / Tal1) x 100%
```
Eksempel: 2.482.743 stemmer / 3.448.254 stemmeberettigede x 100% = 72%

**Procentvis aendring:**
```
|Tal2 - Tal1| / Tal1 x 100%
```
Absolutvaerdi sikrer positivt resultat. Sig "faldt med 18%" i stedet for "-18%".

### 4c. Regneeksempler

| Opgavetype | Eksempel | Beregning |
|------------|----------|-----------|
| Find procentsats | 13 af 28 elever har kaeledyr | (13/28) x 100% = 46% |
| Find vaerdi ud fra % | 45% skat af 25.000 kr | (25.000 x 45) / 100 = 11.250 kr |
| Find procentvis stigning | Aktie: 175 -> 225 | \|225-175\|/175 x 100% = 28,5% |
| Find procentvist fald | Aktie: 175 -> 150 | \|150-175\|/175 x 100% = 14% |
| Find oprindelig vaerdi | 25% rabat = 50 kr | (50/25) x 100 = 200 kr |

### 4d. Regn med procenter

**Procentandel:** x/y x 100%  (1200 af 2500 = 48%)

**Traek procent fra:** x x (100-y)/100  (975 minus 25% = 731,25)

**Laeg procent til:** x + x x y/100  (115 plus 12% = 128,8)

**Smart regel:** "X procent af Y = Y procent af X" (kommutativitet: 20% af 76 = 76% af 20 = 15,2)

### 4e. Promille

**Definition:** "Per tusinde" (symbolet 0/00). 10x mere granuleret end procent.

**Omregning:** 20% = 200 0/00. Brug 1000 i stedet for 100 i alle procentformler.

---

## 5. Algebra

> Kilde: webmatematik.dk/lektioner/7-9-klasse/algebra/

### 5a. Led og faktorer

**Led:** Dele af et udtryk adskilt af + eller -. (5+2+4 har 3 led)

**Faktorer:** Dele adskilt af gangetegn. (4 x 2 x 3 har 3 faktorer)

**Raekkefolgeregler:**
- Led kan byttes rundt (8-2+3 = 3+8-2) — minustegnet folger med
- Faktorer kan byttes rundt (4 x 2 x 3 = 2 x 3 x 4)

**Blandede udtryk:** 5+2+7 x 8 har 3 led, hvoraf et led (7 x 8) indeholder 2 faktorer.

### 5b. Regnearternes hierarki

**Raekkefolge (uden parenteser):**
1. Potenser og rodder
2. Gange og division
3. Plus og minus

**Parenteser** gar altid forst og overrider hierarkiet.

**Eksempler:**
- 1 + 2 x 3 = 7 (IKKE 9)
- 5 + 3 - 7 x 2 + 3 x 4 = 5 + 3 - 14 + 12 = 6

**Med bogstaver:** 5 + 3a + 7 x 2 x a - 2 = 3 + 17a (tal for sig, bogstaver for sig)

### 5c. Parenteser

**Gange ind i parentes:** Gang tallet ind pa hvert led.
- 3(8+2-4) = 3 x 8 + 3 x 2 - 3 x 4 = 24+6-12 = 18
- 5 x (2a+4) = 10a + 20
- -2(5-3+x) = -10+6-2x = -4-2x

**Plusparentes:** Fjern uden at aendre fortegn.
- +(5-2+8) = 5-2+8

**Minusparentes:** Alle fortegn byttes.
- -(2+5-3) = -2-5+3
- -(- 2+8x) = 2-8x
- 33-(4-8+y) = 33-4+8-y = 37-y

**Terminologi:** Fortegn (sign), ophaeve parentesen (remove parentheses)

### 5d. Negative tal

**Definition:** Tal mindre end nul. Pa tallinjen til venstre for 0. Termometer-analogi.

**Addition/subtraktion:**
- a + (-b) = a - b  (at laegge gaeld til = at traekke fra)
- a - (-b) = a + b
- a - (b + c) = a - b - c
- Eksempel: -4C - 3C = -7C

**Multiplikation:**
- (-a) x b = -ab (negativ x positiv = negativ)
- (-a) x (-b) = ab (negativ x negativ = positiv)
- **Huskeregel:** Lige antal minusser = positivt, ulige = negativt

**Division:** Samme fortegnsregler som multiplikation.
- (-a) / (-b) = positivt
- (-a) / b = negativt

### 5e. Reduktion (forenkling af udtryk)

**Tretrinsproces:**
1. **Ophaev parenteser** (plus- og minusparenteser)
2. **Organiser ens led** (konstanter, x-led, y-led etc.)
3. **Sammendrag** (adder/subtraher koefficienter)

**Eksempel:** 3+(8-2x)-(x+3y)+4y-5
-> 3+8-2x-x-3y+4y-5
-> (3+8-5) + (-2x-x) + (-3y+4y)
-> 6 - 3x + y

**Vigtigt:** Man kan IKKE sammendrage led med forskellige potenser (a og a^2 er ikke ens led).

### 5f. Kvadratrod

**Definition:** Kvadratroden af a er det tal der ganget med sig selv giver a. sqrt(9) = 3.

**Regler:**
- Altid positivt resultat (selvom bade 3 og -3 giver 9)
- Kan kun tages af positive tal
- Kvadrattallene: 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169

**Beregning af ikke-perfekte:** Tilnaermelse ved forsog. sqrt(45) ≈ 6,708 (test: 6,708^2 ≈ 45)

### 5g. Kubikrod og andre rodder

**Kubikrod:** Det tal der ganget med sig selv 3 gange giver resultatet.
- Kubikrod(8) = 2 (2 x 2 x 2 = 8)
- Kubikrod(64) = 4

**Forskel fra kvadratrod:** Kubikrodder KAN tages af negative tal.
- Kubikrod(-125) = -5 (fordi (-5) x (-5) x (-5) = -125)

**Hojere rodder:** 4. rod, 5. rod osv. folger samme princip.
- 4.rod(81) = 3 (3 x 3 x 3 x 3 = 81)

### 5h. Potenser

**Definition:** Forkortelse for gentagen multiplikation. 3^5 = 3 x 3 x 3 x 3 x 3.

**Terminologi:**
- **Grundtal** (base): tallet der ganges
- **Eksponent**: antal gange det ganges med sig selv

**Regneregler:**
| Regel | Formel | Eksempel |
|-------|--------|----------|
| Multiplikation | a^b x a^c = a^(b+c) | 5^2 x 5^6 = 5^8 |
| Division | a^b / a^c = a^(b-c) | 8^5 / 8^3 = 8^2 |
| Nulte potens | a^0 = 1 | 7^0 = 1 |
| Negativ eksponent | a^(-b) = 1/a^b | 2^(-3) = 1/8 |

### 5i. 10er-potenser

**Formaal:** Skrive enormt store og sma tal overskueligt.

**Monster:** Eksponenten = antal nuller efter 1.
- 10^1 = 10, 10^2 = 100, 10^3 = 1000

**Videnskabelig notation:** a x 10^b, hvor 0 < a < 10 og b er heltal.
- 28.000 = 2,8 x 10^4 (IKKE 28 x 10^3)
- Jordens masse: 6 x 10^24 kg

**Sma tal:** Negative eksponenter.
- 0,1 = 10^(-1), 0,01 = 10^(-2), 0,001 = 10^(-3)
- 0,005 = 5 x 10^(-3)
- Brintatomens masse: 1,7 x 10^(-27) kg

**Lommeregner-notation:** 6 x 10^24 = 6E24

---

## 6. Ligninger

> Kilde: webmatematik.dk/lektioner/7-9-klasse/ligninger/

### 6a. Losning af ligninger

**Definition:** En ligning er et matematisk udtryk med et lighedstegn og en ubekendt (ofte x).

**Vaegtmetoden (balance-princippet):**
Forestil dig en vaegt — hvad du gor pa den ene side, skal du ogsa gore pa den anden.
- Adder/subtraher pa begge sider
- Multiplicer/divider pa begge sider (ikke med 0)

**Systematisk fremgangsmade:**
1. Ophaev parenteser
2. Sammendrag ens led
3. Flyt alle x-led til den ene side
4. Flyt alle konstanter til den anden side
5. Isoler x ved at dividere med koefficienten

**Verifikation:** Indsaet losningen i den oprindelige ligning og tjek at begge sider er ens.

### 6b. Grafisk losning

**Metode:** Behandl begge sider af ligningen som separate funktioner. Tegn begge grafer. Skaerningspunktets x-koordinat er losningen.

**Eksempel 1:** 2x - 6 = x - 2
- V(x) = 2x - 6, H(x) = x - 2
- Graferne skaerer hinanden ved x = 4

**Eksempel 2:** 2(x - 4) = 3
- V(x) = 2x - 8, H(x) = 3
- Skaering ved x = 5,5

### 6c. To ligninger med to ubekendte

**Princip:** En ligning med to ubekendte kan ikke loses alene — der kraeves to ligninger.

**Substitutionsmetoden:**
1. Isoler en variabel i den ene ligning
2. Indsaet udtrykket i den anden ligning
3. Los den resulterende ligning med en ubekendt
4. Indsaet losningen tilbage for at finde den anden variabel

**Eksempel:**
- 3y = 6x - 3
- 2x = 7 - y
- Losning: (x,y) = (2,3)

**Verifikation:** Indsaet i begge oprindelige ligninger (9=9 og 4=4).

---

## 7. Funktioner

> Kilde: webmatematik.dk/lektioner/7-9-klasse/funktioner/

### 7a. Koordinatsystemet

**Opbygning:** To vinkelrette akser der skaerer hinanden i origo (0,0).
- **x-aksen** (forsteaksen): positiv til hojre, negativ til venstre
- **y-aksen** (andenaksen): positiv opad, negativ nedad

**Kvadranterne:** Nummereret 1-4, startende oppe til hojre, mod uret.

**Punkter:** Skrives som (x-koordinat, y-koordinat). Eksempel: punkt A = (3, 2).

### 7b. Hvad er en funktion?

**Definition:** En funktion beskriver sammenhaengen mellem to storrelser. Nar den ene aendrer sig, aendrer den anden sig ogsa.

**Variable:**
- **Uafhaengig variabel (x):** den vaerdi vi vaelger
- **Afhaengig variabel (y):** bestemt af funktionen

**Funktionsudtryk:** y = 6x (kartofler til 6 kr/kg: x = kg, y = pris)

**Sildeben (tabel):**
| x | 1 | 2 | 3 | 4 | 7 | 10 |
|---|---|---|---|---|---|---|
| y | 6 | 12 | 18 | 24 | 42 | 60 |

**Graf:** Plottes i koordinatsystem. Aflaes vaerdier ved at ga fra x-akse lodret op til kurven, derefter vandret til y-aksen.

### 7c. Lineaer funktion

**Formel:** y = a x x + b

**Parametre:**
- **a (haeldning):** bestemmer hvor stejlt linjen stiger/falder. Aflaes: ga 1 enhed til hojre pa x-aksen, maol lodret aendring = a.
- **b (skaering med y-aksen):** hvor grafen skaerer y-aksen.

---

## 8. Geometri

> Kilde: webmatematik.dk/lektioner/7-9-klasse/geometri/

### 8a. Trekanter

**Typer:**
| Type | Kendetegn |
|------|-----------|
| Retvinklet | En vinkel er 90 grader |
| Stumpvinklet | En vinkel over 90 grader |
| Spidsvinklet | Alle vinkler under 90 grader |
| Ligesidet | Alle sider lige lange, alle vinkler 60 grader |
| Ligebenet | To sider lige lange, to vinkler ens |

**Grundregel:** Vinkelsummen i enhver trekant er 180 grader.

**Specielle linjer:**
- **Median:** Fra hjorne til modstaende sides midtpunkt
- **Midtnormal:** Vinkelret linje ved sidens midtpunkt
- **Vinkelhalveringslinje:** Deler en vinkel i to lige store dele

**Cirkler:**
- **Omskrevet cirkel:** Rorer alle tre hjorner, centrum ved midtnormalernes skaering
- **Indskrevet cirkel:** Rorer alle tre sider, centrum ved vinkelhalveringslinernes skaering

### 8b. Ensvinklede trekanter (ligedannede)

**Definition:** To trekanter hvor der findes en skaleringsfaktor der kan transformere den ene til den anden.

**Laengdeforholdet (k):**
- For storre trekant: k = a'/a = b'/b = c'/c
- For mindre trekant: k = a/a' = b/b' = c/c'
- k_lille x k_stor = 1 (reciprokke)

### 8c. Retvinklede trekanter

**Terminologi:**
- **Hypotenuse:** Siden modsat den rette vinkel
- **Kateter:** De to sider der danner den rette vinkel

**Pythagoras:** a^2 + b^2 = c^2

**Udvidelse:** I enhver trekant kan man tegne en hojde der deler den i to retvinklede trekanter.

### 8d. Firkanter

**Grundregel:** Vinkelsummen er altid 360 grader. Alle firkanter har to diagonaler.

| Type | Egenskaber |
|------|------------|
| Rektangel | Alle vinkler 90 grader, parvist parallelle sider, diagonaler skaerer i midtpunkt |
| Kvadrat | Som rektangel + alle sider lige lange + diagonaler vinkelrette |
| Parallellogram | Modstaende vinkler summer til 180 grader, modstaende sider parallelle |
| Trapez | Kun et par parallelle sider |

**Kvadrat** er et specialtilfaelde af rektanglet.

### 8e. Cirkler

**Grundbegreber:**
- **Centrum:** Midtpunktet
- **Radius (r):** Afstand fra centrum til kanten
- **Diameter (d):** 2 x radius
- **Korde:** Linje mellem to punkter pa omkredsen
- **Tangent:** Linje der rorer cirklen i praecis et punkt

**Formler:**
- Omkreds: O = pi x d = 2 x pi x r
- Cirkeludsnit: O_udsnit = (pi x r / 180) x vinkel + 2r

**Ellipse:** En "strakt" cirkel med storakse og lilleakse.

---

## 9. Areal

> Kilde: webmatematik.dk/lektioner/7-9-klasse/areal/

### 9a. Arealenheder

**Princip:** Areal har 2 dimensioner, sa enhedsomregning skal kvadreres.
- 1 m^2 = 100 x 100 = 10.000 cm^2 (IKKE bare 100!)
- 1 km^2 = 1.000 x 1.000 = 1.000.000 m^2

### 9b. Rektangel

**Formel:** A = l x b (laengde gange bredde)

### 9c. Trekant

**Formel:** T = 1/2 x h x g (halvdelen af hojde gange grundlinje)

**Forklaring:** To ens trekanter danner et rektangel. Hojden deler enhver trekant i to retvinklede trekanter.

**Terminologi:** h = hojde, g = grundlinje

### 9d. Parallellogram

**Formel:** A = h x a (hojde gange grundlinje)

**Forklaring:** Forskyd en retvinklet trekant fra den ene side til den anden — parallelogrammet bliver et rektangel.

### 9e. Trapez

**Formel:** A = 1/2 x h x (a1 + a2)

**Forklaring:** Summer de to parallelle sider, gang med hojden, divider med 2. Kan udledes ved at dele trapezet i to trekanter.

### 9f. Cirkel

**Formel:** A = pi x r^2

**Forklaring:** Del cirklen i mange sma stykker — jo flere stykker, jo mere ligner det et rektangel med sider r og pi x r.

---

## 10. Rumfang og overfladeareal

> Kilde: webmatematik.dk/lektioner/7-9-klasse/rumfang-og-overfladeareal/

### 10a. Kasse (kvaeder)

**Rumfang:** V = l x b x h

**Overfladeareal:** A = 2(bh + lb + lh)

**Varianter:**
- Parallellogram-grundflade: V = b x g x h
- Trapez-grundflade: V = 1/2 x b x h x (a1 + a2)

### 10b. Cylinder

**Rumfang:** V = h x pi x r^2

**Krumme overflade:** O = 2 x pi x r x h

**Samlet overflade:** A = 2 x pi x r x (h + r)

### 10c. Kugle

**Rumfang:** V = 4/3 x pi x r^3

**Overfladeareal:** A = 4 x pi x r^2

### 10d. Kegle

**Rumfang:** V = (pi x h x r^2) / 3  (en tredjedel af cylinder)

**Krumme overflade:** O = pi x r x s  (s = sidelinje/skraahojde)

**Samlet overflade:** A = pi x r x (s + r)

### 10e. Pyramide

**Rumfang:** V = (A_grundflade x hojde) / 3

**Overflade:** A = A_grundflade + n x 1/2 x h_trekant x g
(n = antal sider, g = sidelaengde, h_trekant = trekant-sidernes hojde)

**Vigtigt:** Skelne mellem pyramidens hojde og trekant-sidernes hojde.

---

## 11. Trigonometri

> Kilde: webmatematik.dk/lektioner/7-9-klasse/trigonometri/

### 11a. Retvinklet trekant

**Grundlaeggende funktioner (vinkel v, ret vinkel i C):**
- cos(v) = hosliggende katete / hypotenuse
- sin(v) = modstaende katete / hypotenuse
- tan(v) = modstaende katete / hosliggende katete

**Terminologi:**
- Hosliggende katete = adjacent side
- Modstaende katete = opposite side

**Eksempler:**
- Givet a=5, vinkel A=30: sin(30)=5/c -> c=10
- Givet b=2, c=4: cos(A)=2/4 -> A=arccos(0,5) ≈ 60 grader

**Princip:** Med to kendte vaerdier kan den tredje beregnes.

---

## 12. Statistik og sandsynlighed

> Kilde: webmatematik.dk/lektioner/7-9-klasse/statistik-og-sandsynlighed/

### 12a. Statistik

**Grundbegreber:**
- **Observation:** Enkelt datapunkt
- **n:** Antal observationer
- **Hyppighed:** Antal gange en vaerdi forekommer
- **Frekvens (relativ hyppighed):** hyppighed/n (summer til 1)

**Centralmal:**
| Mal | Definition | Eksempel (25 karakterer) |
|-----|-----------|--------------------------|
| Typetal (mode) | Hyppigst forekommende | 7 (forekommer 8 gange) |
| Middelvaerdi (mean) | Sum / n | (2x2+7x4+8x7+5x10+3x12)/25 = 6,96 |
| Median | Midterste vaerdi (sorteret) | 13. vaerdi = 7 |

**Spredningsmal:**
- Mindstevaerdi (minimum)
- Storstevaerdi (maximum)
- Variationsbredde (range): max - min

**Diagramtyper:**
- Cirkeldiagram (lagkage)
- Kvadratdiagram (10x10 felt, hvert felt = 1%)
- Stabeldiagram (soejler)

### 12b. Sandsynlighedsregning

**Definition:** Forudsige sandsynligheden for at en haendelse indtraeffer.

**Formel (lige sandsynlige udfald):**
```
P(X) = antal gunstige udfald / antal mulige udfald
```

**Eksempler:**
- Terning: P(2 eller 3) = 2/6 = 1/3 ≈ 33%
- Kortspil: P(billedkort) = 12/52 ≈ 23%

**Terminologi:** Udfald (outcome), gunstige udfald (favorable), mulige udfald (possible), kuloer (suit)

---

## 13. Valutaomregning

> Kilde: webmatematik.dk/lektioner/7-9-klasse/valutaomregning/

**Kompetencer:**
1. Beregne udenlandsk valuta fra danske kroner
2. Omregne mellem to fremmede valutaer
3. Forsta bankens vekselkurser ved kortbetaling
4. Beregne procentvis kursaendring

**Terminologi:** Valutaomregning (currency conversion), kursen (exchange rate)

---

## Prioritering for Kvante-animationer

### Fase 1: Grundlaeggende regnearter (i gang)
- [x] Addition/subtraktion (stacked_arithmetic + object_collection)
- [ ] Lang multiplikation (1b) — udvid stacked_arithmetic
- [ ] Lang division (2a) — ny visual type
- [ ] Kort division (2b + 2c) — ny visual type
- [ ] Krydset (1a) — ny visual type

### Fase 2: Broker og procent
- [ ] Brok-visualisering (3a-3c) — udvid pie_chart/bar_model
- [ ] Blandede tal (3e)
- [ ] Brok-procent-decimal omregning (3f)

### Fase 3: Algebra
- [ ] Regnearternes hierarki (5b) — step-by-step highlight
- [ ] Parenteser (5c) — expand/collapse animation
- [ ] Negative tal (5d) — udvid number_line
- [ ] Reduktion (5e) — term-grouping animation

### Fase 4: Geometri og areal
- [ ] Trekanter, firkanter, cirkler (8a-8e) — tegne-animationer
- [ ] Arealformler (9b-9f) — visuelt bevis med flytning/ophaegning
- [ ] Pythagoras (8c) — klassisk visuelt bevis

### Fase 5: Funktioner og ligninger
- [ ] Koordinatsystem (7a) — allerede delvist implementeret
- [ ] Lineaer funktion (7c) — haeldning/skaering animation
- [ ] Vaegtmetoden for ligninger (6a) — balance-animation

### Fase 6: Avanceret
- [ ] Rumfang (10a-10e) — 3D-visualisering
- [ ] Trigonometri (11a) — trekant med vinkler
- [ ] Statistik (12a) — diagrammer
- [ ] Potenser og rodder (5f-5i)

---

## Screenshots-reference

| Fil | Metode |
|-----|--------|
| `Screenshot 2026-04-06 at 08.56.58.png` | Krydset (kryds-multiplikation) |
| `Screenshot 2026-04-06 at 08.49.51.png` | Lang multiplikation (206 * 14) |
| `Screenshot 2026-04-06 at 08.52.18.png` | Den gammeldags (lang division) |
| `Screenshot 2026-04-06 at 08.55.04.png` | Den der ikke fylder (kort division) |
| `Screenshot 2026-04-06 at 08.55.23.png` | Med rest/decimal (kort division udvidet) |
