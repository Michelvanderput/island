# Island

Een Dynamic Island voor je Mac, nagebouwd naar het idee van [Canopy](https://getcanopy.pro/).
Native (Swift + SwiftUI), geen Dock-icoon, geen venster: het leeft in de notch.
Op Macs zonder notch en op externe schermen verschijnt het als zwarte pil bovenaan.

## Wat het doet

- **Muziek** – Spotify en Apple Music: hoes, titel, scrubber, vorige/afspelen/volgende.
  Tijdens afspelen zet de notch uit met de hoes links en een bewegende golfvorm rechts.
- **Songteksten** – tijdgesynchroniseerd via LRCLib; huidige regel in de speler, optioneel
  onder de notch, plus een apart tabblad dat meescrollt (tik op een regel om te springen).
- **Audio-uitgang** – wissel tussen speakers, AirPods, AirPlay enz. en regel het volume
  vanuit de notch.
- **Nummerwissel** – bij een nieuw nummer toont de notch kort titel en artiest.
- **AirPods / Bluetooth-audio** – melding bij verbinden en ontkoppelen, met batterij (links/rechts).
- **Batterij** – melding bij inpluggen/uittrekken en bij 20/10/5 %.
- **Weer** – temperatuur en verwachting via Open-Meteo (globale locatie of een stad naar keuze).
- **Bestandenlade** – sleep bestanden op de notch om ze te parkeren; sleep ze er later weer
  uit, open ze, of deel ze via AirDrop.
- **Instellingen** – starten bij inloggen; welk scherm; openen door aanwijzen of klikken;
  sneltoets ⌃⌥Spatie; grootte uitgeklapt; start-tabblad; voorkeursspeler; kleur uit de hoes;
  batterijdrempel; lade
  kopieert bestanden of leegt zich bij afsluiten; standaardinstellingen herstellen;
  diagnose-tab.

Alles is event driven (notificaties van Spotify/Muziek, IOKit, IOBluetooth); alleen het
weer wordt elk half uur ververst.

## Installeren

**Kant-en-klaar:** download `Island.zip` bij de laatste run onder
*Actions → Build Island.app → Artifacts*, pak uit en sleep `Island.app` naar Programma's.
De app is niet genotariseerd, dus de eerste keer: rechtsklik → **Open** → **Open**
(of `xattr -dr com.apple.quarantine /Applications/Island.app`).

**Zelf bouwen** (Xcode 15 of nieuwer, of de Command Line Tools):

```sh
./scripts/build-app.sh
open build/Island.app
```

Of tijdens ontwikkelen gewoon `swift run`.

Vereist macOS 14 Sonoma of nieuwer.

## Gebruik

- Wijs de notch aan → hij klapt uit. Muis weg → hij klapt in.
- Rechtsklik op het eiland of het capsule-icoon in de menubalk → Instellingen / Stop.
- Bij de eerste muziekbediening vraagt macOS om toestemming voor *Automatisering*,
  bij het weer om *Locatie*, bij AirPods om *Bluetooth*.

## Verschillen met Canopy

- Video in de browser (Netflix, YouTube) en Tidal worden niet gevolgd: daarvoor is het
  private MediaRemote-framework nodig, dat Apple sinds macOS 15.4 afschermt voor andere apps.
- Geen speler of widgets op het vergrendelscherm.
- Het hartje werkt alleen met Apple Music (Spotify heeft daar geen koppeling voor).
- Geen equalizer, geen Focus-widget en geen licentiesysteem.
