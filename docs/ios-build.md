# Sådan får du Astro Ball ind på din iPhone

Skrevet til én, der aldrig har lavet et iOS-build før. Følg den i
rækkefølge. Der er tre ting, der skal på plads, og de kan alle gøres
gratis: Godots eksportskabeloner, Xcode, og en gratis Apple-konto.

Du kan lægge spillet på din **egen** telefon uden at betale noget. Vil du
lægge det i App Store, koster et Apple Developer Program 99 dollars om
året. Det er ikke nødvendigt endnu.

---

## 0. Hvad du skal bruge

| | |
|---|---|
| En Mac | Xcode findes kun til macOS |
| Xcode | Gratis i Mac App Store, ca. 8 GB |
| Godot 4.7 | Du har den i `/Applications/Godot.app` |
| Godots eksportskabeloner til 4.7 | Hentes fra Godot, se trin 1 |
| Et Apple-ID | Det du bruger til App Store, gratis |
| Et USB-kabel | Wi-Fi virker også, men kabel er nemmere første gang |

En app signeret med en gratis konto **udløber efter 7 dage**. Så skal du
køre trin 6 igen. Det er Apples regel, ikke vores.

---

## 1. Hent Godots eksportskabeloner

Uden dem siger Godot "Export templates for this platform are missing".

1. Åbn Godot og luk projektlisten op.
2. **Editor → Manage Export Templates → Download and Install.**
3. Vent. Det er omkring 1 GB, og der er ingen fremdriftsbjælke det meste
   af tiden.

Skabelonerne skal matche din Godot-version præcis. Har du 4.7.2, skal
skabelonerne være 4.7.2.

---

## 2. Installer Xcode og accepter licensen

1. Installer Xcode fra Mac App Store.
2. Åbn Xcode én gang og lad den installere sine ekstra komponenter.
3. Kør i en terminal:

```
sudo xcodebuild -license accept
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## 3. Læg dit Apple-ID ind i Xcode

1. **Xcode → Settings → Accounts → +→ Apple ID.**
2. Log ind med dit almindelige Apple-ID.
3. Du får et team, der hedder noget i retning af
   *Dit Navn (Personal Team)*. Det er det, du skal bruge.

---

## 3b. Luk Godot, før noget redigeres udefra

Editoren ejer `project.godot` og `export_presets.cfg`, så længe den
kører. Ændrer nogen filerne på disken imens, skriver editoren dem tilbage
fra sin egen hukommelse, og ændringerne er væk uden en fejlmeddelelse.
Luk med ⌘Q, ikke bare vinduet.

---

## 4. Eksportér fra Godot

Projektet har allerede en iOS-preset. Den hedder **iOS** og peger på
`build/ios/AstroBall.ipa`.

Fra editoren:

1. **Project → Export.**
2. Vælg **iOS** i listen.
3. **App Store Team ID** står allerede i presetten. Skal du finde et
   andet, ligger det i certifikatet:

   ```
   security find-certificate -a -c "Apple Development" -p \
     | openssl x509 -noout -subject | tr ',' '\n' | grep OU=
   ```

   Feltet må ikke være tomt. Godot afviser eksporten uden det.
4. **Export Project** (ikke "Export PCK/Zip"). Vælg en mappe. Godot
   laver et helt Xcode-projekt, ikke en færdig app.

Fra kommandolinjen, hvis du hellere vil:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path "$(pwd)" --export-debug "iOS" build/ios/AstroBall.ipa
```

Første gang fejler den, hvis skabelonerne fra trin 1 mangler. Fejlteksten
siger det direkte.

Eksporten lægger omkring 430 MB i `build/ios/`. Den mappe er ignoreret af
git: et eksporteret Xcode-projekt er output, ikke kildekode.

---

## 5. Åbn i Xcode og vælg dit team

1. Åbn `astro_ball.xcodeproj` i den mappe, Godot eksporterede til.
2. Klik projektet øverst i venstre panel.
3. Fanen **Signing & Capabilities**.
4. Sæt flueben i **Automatically manage signing**.
5. Vælg dit **Team** i rullelisten. Det er *(Personal Team)*.
6. **Bundle Identifier** skal være unik på verdensplan. Vores er
   `com.alius.astroball`. Er den taget, sætter du noget efter, for
   eksempel `com.alius.astroball.ali`. Ændrer du den her, så ændr den
   også i Godots preset, så de to ikke driver fra hinanden.

Ser du rødt her, står grunden altid i teksten under feltet. De to
almindelige er: intet team valgt, eller et bundle-id, en anden allerede
har taget.

---

## 6. Kør på telefonen

1. Sæt iPhonen i med kablet.
2. Lås den op og svar **Trust** på "Trust This Computer?".
3. Øverst i Xcode, i enhedsvælgeren ved siden af play-knappen, vælger du
   din telefon i stedet for en simulator.
4. Tryk **play** (⌘R).

Første gang stopper telefonen appen med
*"Untrusted Developer"*. Det er forventet:

- På telefonen: **Indstillinger → Generelt → VPN og enhedsadministration**
- Tryk på din udviklerprofil
- **Trust**

Kør så ⌘R igen.

---

## 7. Når det ikke virker

**"Cannot export project ... due to configuration errors:" uden noget efter kolonet**
Kommandolinjen udskriver ikke selve fejlen. Åbn **Project → Export** i
editoren: dialogen viser den med rødt nederst. De tre, der ramte os:

- *Target platform requires 'ETC2/ASTC' texture compression.* Slås til i
  `project.godot` som `textures/vram_compression/import_etc2_astc=true`,
  eller med knappen **Show Project Setting** i selve fejlen. iOS
  accepterer ikke andet.
- *App Store Team ID not specified.* Se trin 3.
- *Invalid Identifier: Identifier is missing.* Bundle-id'et er tomt.

Sagde dialogen "mangler" om noget, du er sikker på at have skrevet ind,
så læs 3b: editoren har overskrevet det.

**"Export templates for this platform are missing"**
Trin 1. Og tjek at skabelonernes version er præcis den samme som
Godots. Kun `ios.zip` og `version.txt` er nødvendige for iOS; de øvrige
3 GB til Android, Windows, Linux og web behøver ikke ligge der.

**"Signing for ... requires a development team"**
Trin 5. Team er ikke valgt.

**"Unable to install ... The maximum number of apps for free development profiles has been reached"**
En gratis konto må have tre apps på telefonen ad gangen. Slet en af de
andre.

**Appen starter og lukker med det samme**
Kør den fra Xcode og se konsollen nederst. Godot skriver sine egne fejl
derned, præcis som i editoren.

**Appen udløb efter en uge**
Sådan er gratis-signering. Kør trin 6 igen.

**Simulatoren vil ikke køre spillet**
Godot skal bygge et simulator-bibliotek, og presetten har
`generate_simulator_library_if_missing` slået til. Det tager tid første
gang. En rigtig telefon er hurtigere og mere ærlig, især for styring og
haptik, som simulatoren ikke kan gengive.

---

## Det, der skal mærkes efter, når den kører

Styringen er **relativ**: paddlen flytter sig med fingerens bevægelse, og
ikke hen til fingeren. Læg tommelfingeren lavt og til siden, hvor den
ikke dækker for noget, og træk.

Fire ting at holde øje med på selve telefonen, som ikke kan afgøres på en
computer:

1. **Følsomheden.** `TouchInput.SENSITIVITY` står på 1.0, altså 1 px
   finger giver 1 px paddle. Føles det tungt, skal det op.
2. **Accelerationen.** Et hurtigt kast bærer 20 procent længere end
   fingeren gik. `ACCEL_FROM` og `ACCEL_TO` afgør hvornår.
3. **Tap mod træk.** Grænsen er 150 ms og 8 px. Affyrer bolden, når du
   mente at styre, skal 8 px ned.
4. **Haptikken.** Slå den fra og til i indstillingerne og se, om den
   tilføjer noget eller bare støjer.
