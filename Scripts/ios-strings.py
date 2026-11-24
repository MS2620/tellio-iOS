#!/usr/bin/env python3
"""Writes Resources/Localizable.xcstrings: the text only the iOS app has, in every language.

    Scripts/ios-strings.py

The Apple TV app's catalog (Vendor/tellio/Resources/Localizable.xcstrings) already covers
most of Tellio; this adds what the iPhone and iPad screens say on top. Edit the tables below
and run it again: Xcode isn't needed, and Scripts/localize.py builds both catalogs into the app.

Plain strings: key → (es, de, fr, pt-PT, pl).
Plurals: key → {language: (one, other)}; Polish has (one, few, many).
"""
import json
import os

LANGUAGES = ["es", "de", "fr", "pt-PT", "pl"]

PLAIN = {
    # Tabs (short, so the bar stays tidy)
    "tab.browse": ("Explorar", "Entdecken", "Explorer", "Explorar", "Przeglądaj"),
    "tab.sports": ("Deportes", "Sport", "Sports", "Desporto", "Sport"),
    "Browse": ("Explorar", "Entdecken", "Explorer", "Explorar", "Przeglądaj"),
    "Home": ("Inicio", "Start", "Accueil", "Início", "Start"),

    # Browse, Home and titles
    "Section": ("Sección", "Bereich", "Section", "Secção", "Sekcja"),
    "Season": ("Temporada", "Staffel", "Saison", "Temporada", "Sezon"),
    "Film": ("Película", "Film", "Film", "Filme", "Film"),
    "Add your TMDB token in Settings › Connections to browse films and series.": (
        "Añade tu token de TMDB en Ajustes › Conexiones para explorar películas y series.",
        "Füge dein TMDB-Token unter Einstellungen › Verbindungen hinzu, um Filme und Serien zu entdecken.",
        "Ajoutez votre jeton TMDB dans Réglages › Connexions pour explorer films et séries.",
        "Adicione o seu token TMDB em Definições › Ligações para explorar filmes e séries.",
        "Dodaj token TMDB w Ustawienia › Połączenia, aby przeglądać filmy i seriale."),
    "Add your TMDB token in Settings › Connections to see release dates.": (
        "Añade tu token de TMDB en Ajustes › Conexiones para ver las fechas de estreno.",
        "Füge dein TMDB-Token unter Einstellungen › Verbindungen hinzu, um Erscheinungstermine zu sehen.",
        "Ajoutez votre jeton TMDB dans Réglages › Connexions pour voir les dates de sortie.",
        "Adicione o seu token TMDB em Definições › Ligações para ver as datas de estreia.",
        "Dodaj token TMDB w Ustawienia › Połączenia, aby zobaczyć daty premier."),
    "Add series to My List to see when their new episodes come out.": (
        "Añade series a Mi lista para ver cuándo salen sus nuevos episodios.",
        "Füge Serien zu Meine Liste hinzu, um zu sehen, wann neue Folgen erscheinen.",
        "Ajoutez des séries à Ma liste pour savoir quand sortent leurs nouveaux épisodes.",
        "Adicione séries à Minha lista para ver quando saem os novos episódios.",
        "Dodaj seriale do Mojej listy, aby widzieć, kiedy wychodzą nowe odcinki."),
    "Remove from My List": ("Quitar de Mi lista", "Aus Meine Liste entfernen", "Retirer de Ma liste",
                            "Remover da Minha lista", "Usuń z Mojej listy"),
    "Add to My List": ("Añadir a Mi lista", "Zu Meine Liste hinzufügen", "Ajouter à Ma liste",
                       "Adicionar à Minha lista", "Dodaj do Mojej listy"),
    "Go to film": ("Ir a la película", "Zum Film", "Voir le film", "Ir para o filme", "Przejdź do filmu"),
    "Go to series": ("Ir a la serie", "Zur Serie", "Voir la série", "Ir para a série", "Przejdź do serialu"),
    "MY LIST": ("MI LISTA", "MEINE LISTE", "MA LISTE", "MINHA LISTA", "MOJA LISTA"),
    "TRENDING · FILM": ("TENDENCIA · PELÍCULA", "IM TREND · FILM", "TENDANCE · FILM",
                        "EM DESTAQUE · FILME", "NA CZASIE · FILM"),
    "TRENDING · SERIES": ("TENDENCIA · SERIE", "IM TREND · SERIE", "TENDANCE · SÉRIE",
                          "EM DESTAQUE · SÉRIE", "NA CZASIE · SERIAL"),
    "Bring your Apple TV setup across with a backup code, or add your accounts in Settings › Connections.": (
        "Trae la configuración de tu Apple TV con un código de copia de seguridad, o añade tus cuentas en Ajustes › Conexiones.",
        "Übernimm die Einrichtung deines Apple TV mit einem Backup-Code oder füge deine Konten unter Einstellungen › Verbindungen hinzu.",
        "Récupérez la configuration de votre Apple TV avec un code de sauvegarde, ou ajoutez vos comptes dans Réglages › Connexions.",
        "Traga a configuração da sua Apple TV com um código de cópia de segurança, ou adicione as suas contas em Definições › Ligações.",
        "Przenieś konfigurację z Apple TV kodem kopii zapasowej albo dodaj konta w Ustawienia › Połączenia."),
    "Open Settings": ("Abrir Ajustes", "Einstellungen öffnen", "Ouvrir les réglages", "Abrir Definições",
                      "Otwórz ustawienia"),
    "Details": ("Detalles", "Details", "Détails", "Detalhes", "Szczegóły"),
    "More like this": ("Más como esta", "Ähnliche Titel", "Titres similaires", "Mais como este", "Podobne"),
    "Can't be played: this title has no IMDb id for addons to look up.": (
        "No se puede reproducir: este título no tiene un id de IMDb para que los addons lo busquen.",
        "Nicht abspielbar: Dieser Titel hat keine IMDb-ID, nach der Add-ons suchen könnten.",
        "Lecture impossible : ce titre n'a pas d'identifiant IMDb que les add-ons pourraient rechercher.",
        "Não é possível reproduzir: este título não tem um id IMDb para os addons procurarem.",
        "Nie można odtworzyć: ten tytuł nie ma identyfikatora IMDb, po którym dodatki mogłyby szukać."),
    "Some addons are locked by parental controls.": (
        "Algunos addons están bloqueados por el control parental.",
        "Einige Add-ons sind durch die Kindersicherung gesperrt.",
        "Certains add-ons sont verrouillés par le contrôle parental.",
        "Alguns addons estão bloqueados pelo controlo parental.",
        "Niektóre dodatki są zablokowane przez kontrolę rodzicielską."),
    "No addons yet. Add one in Settings › Connections.": (
        "Aún no hay addons. Añade uno en Ajustes › Conexiones.",
        "Noch keine Add-ons. Füge eines unter Einstellungen › Verbindungen hinzu.",
        "Aucun add-on pour l'instant. Ajoutez-en un dans Réglages › Connexions.",
        "Ainda não há addons. Adicione um em Definições › Ligações.",
        "Brak dodatków. Dodaj jeden w Ustawienia › Połączenia."),
    "Best first": ("Mejor primero", "Beste zuerst", "Meilleurs d'abord", "Melhor primeiro", "Najlepsze najpierw"),

    # Live TV and the guide
    "Favourite": ("Favorito", "Favorit", "Favori", "Favorito", "Ulubiony"),
    "No guide information": ("Sin información de la guía", "Keine Programminformationen",
                             "Aucune information de programme", "Sem informação do guia", "Brak informacji z przewodnika"),
    "Reminder set": ("Recordatorio activado", "Erinnerung gesetzt", "Rappel activé", "Lembrete definido",
                     "Przypomnienie ustawione"),
    "No IPTV account": ("Sin cuenta IPTV", "Kein IPTV-Konto", "Aucun compte IPTV", "Sem conta IPTV", "Brak konta IPTV"),
    "Add one in Settings › Connections, or bring your Apple TV setup across from Settings.": (
        "Añade una en Ajustes › Conexiones, o trae la configuración de tu Apple TV desde Ajustes.",
        "Füge eines unter Einstellungen › Verbindungen hinzu oder übernimm die Einrichtung deines Apple TV in den Einstellungen.",
        "Ajoutez-en un dans Réglages › Connexions, ou récupérez la configuration de votre Apple TV depuis Réglages.",
        "Adicione uma em Definições › Ligações, ou traga a configuração da sua Apple TV a partir de Definições.",
        "Dodaj je w Ustawienia › Połączenia albo przenieś konfigurację z Apple TV w Ustawieniach."),
    "Can't load channels": ("No se pueden cargar los canales", "Sender können nicht geladen werden",
                            "Impossible de charger les chaînes", "Não é possível carregar os canais",
                            "Nie można wczytać kanałów"),
    "Try again": ("Reintentar", "Erneut versuchen", "Réessayer", "Tentar novamente", "Spróbuj ponownie"),
    "Unlock": ("Desbloquear", "Entsperren", "Déverrouiller", "Desbloquear", "Odblokuj"),
    "That PIN isn't right. Try again.": ("Ese PIN no es correcto. Inténtalo de nuevo.",
                                         "Diese PIN ist falsch. Versuch es noch einmal.",
                                         "Ce code PIN est incorrect. Réessayez.",
                                         "Esse PIN não está correto. Tente novamente.",
                                         "Ten PIN jest nieprawidłowy. Spróbuj ponownie."),
    "This group": ("Este grupo", "Diese Gruppe", "Ce groupe", "Este grupo", "Ta grupa"),
    "Your name is used everywhere and saved for this IPTV account.": (
        "Tu nombre se usa en todas partes y se guarda para esta cuenta IPTV.",
        "Dein Name wird überall verwendet und für dieses IPTV-Konto gespeichert.",
        "Votre nom est utilisé partout et enregistré pour ce compte IPTV.",
        "O seu nome é usado em todo o lado e guardado para esta conta IPTV.",
        "Twoja nazwa jest używana wszędzie i zapisana dla tego konta IPTV."),
    "Groups": ("Grupos", "Gruppen", "Groupes", "Grupos", "Grupy"),
    "Searching…": ("Buscando…", "Suche …", "Recherche…", "A pesquisar…", "Wyszukiwanie…"),
    "Long-press a channel and choose Add to Favourites.": (
        "Mantén pulsado un canal y elige Añadir a favoritos.",
        "Halte einen Sender gedrückt und wähle Zu Favoriten hinzufügen.",
        "Appuyez longuement sur une chaîne et choisissez Ajouter aux favoris.",
        "Mantenha premido um canal e escolha Adicionar aos favoritos.",
        "Przytrzymaj kanał i wybierz Dodaj do ulubionych."),
    "List view": ("Vista de lista", "Listenansicht", "Vue liste", "Vista de lista", "Widok listy"),
    "Guide view": ("Vista de guía", "Programmansicht", "Vue guide", "Vista de guia", "Widok przewodnika"),
    "Add to Multiview": ("Añadir a Multivista", "Zu Multiview hinzufügen", "Ajouter au multivue",
                         "Adicionar à Multivista", "Dodaj do Multiwidoku"),
    "Close": ("Cerrar", "Schließen", "Fermer", "Fechar", "Zamknij"),
    "Watch channel": ("Ver canal", "Sender ansehen", "Regarder la chaîne", "Ver canal", "Oglądaj kanał"),
    "Starting now": ("Empieza ahora", "Beginnt jetzt", "Commence maintenant", "A começar agora", "Zaczyna się teraz"),
    "Remove reminder": ("Quitar recordatorio", "Erinnerung entfernen", "Supprimer le rappel", "Remover lembrete",
                        "Usuń przypomnienie"),

    # Multiview and the player
    "Leave multiview": ("Salir de Multivista", "Multiview verlassen", "Quitter le multivue", "Sair da Multivista",
                        "Zamknij Multiwidok"),
    "Back to all channels": ("Volver a todos los canales", "Zurück zu allen Sendern", "Retour à toutes les chaînes",
                             "Voltar a todos os canais", "Wróć do wszystkich kanałów"),
    "Tap to hear · Double-tap for full screen": (
        "Toca para oír · Doble toque para pantalla completa",
        "Tippen zum Hören · Doppeltippen für Vollbild",
        "Touchez pour écouter · Touchez deux fois pour le plein écran",
        "Toque para ouvir · Toque duas vezes para ecrã inteiro",
        "Stuknij, aby słuchać · Stuknij dwa razy, aby otworzyć pełny ekran"),
    "Double-tap to go back": ("Doble toque para volver", "Doppeltippen zum Zurückgehen",
                              "Touchez deux fois pour revenir", "Toque duas vezes para voltar",
                              "Stuknij dwa razy, aby wrócić"),
    "Couldn't play this channel": ("No se pudo reproducir este canal", "Dieser Sender konnte nicht abgespielt werden",
                                   "Impossible de lire cette chaîne", "Não foi possível reproduzir este canal",
                                   "Nie udało się odtworzyć tego kanału"),
    "Your provider may only allow one stream at a time.": (
        "Puede que tu proveedor solo permita una emisión a la vez.",
        "Dein Anbieter erlaubt vielleicht nur einen Stream gleichzeitig.",
        "Votre fournisseur n'autorise peut-être qu'un flux à la fois.",
        "O seu fornecedor pode permitir apenas uma emissão de cada vez.",
        "Twój dostawca może pozwalać tylko na jeden strumień naraz."),
    "Add your IPTV login in Settings › Connections first.": (
        "Primero añade tu acceso IPTV en Ajustes › Conexiones.",
        "Füge zuerst deine IPTV-Zugangsdaten unter Einstellungen › Verbindungen hinzu.",
        "Ajoutez d'abord votre identifiant IPTV dans Réglages › Connexions.",
        "Adicione primeiro o seu acesso IPTV em Definições › Ligações.",
        "Najpierw dodaj dane logowania IPTV w Ustawienia › Połączenia."),
    "Recently watched": ("Vistos recientemente", "Zuletzt gesehen", "Regardées récemment", "Vistos recentemente",
                         "Ostatnio oglądane"),
    "Search for a channel to add.": ("Busca un canal para añadirlo.", "Suche einen Sender zum Hinzufügen.",
                                     "Recherchez une chaîne à ajouter.", "Pesquise um canal para adicionar.",
                                     "Wyszukaj kanał, aby go dodać."),
    "Search channels": ("Buscar canales", "Sender suchen", "Rechercher des chaînes", "Pesquisar canais",
                        "Szukaj kanałów"),
    "Multiview": ("Multivista", "Multiview", "Multivue", "Multivista", "Multiwidok"),
    "Picture in picture": ("Imagen en imagen", "Bild-in-Bild", "Image dans l'image", "Imagem na imagem",
                           "Obraz w obrazie"),
    "Previous channel": ("Canal anterior", "Vorheriger Sender", "Chaîne précédente", "Canal anterior",
                         "Poprzedni kanał"),
    "Next channel": ("Canal siguiente", "Nächster Sender", "Chaîne suivante", "Canal seguinte", "Następny kanał"),
    "Pause": ("Pausa", "Pause", "Pause", "Pausa", "Pauza"),
    "Audio and subtitles": ("Audio y subtítulos", "Audio und Untertitel", "Audio et sous-titres",
                            "Áudio e legendas", "Dźwięk i napisy"),
    "This stream couldn't be played": ("No se pudo reproducir esta emisión",
                                       "Dieser Stream konnte nicht abgespielt werden",
                                       "Impossible de lire ce flux", "Não foi possível reproduzir esta emissão",
                                       "Nie udało się odtworzyć tego strumienia"),
    "Stereo": ("Estéreo", "Stereo", "Stéréo", "Estéreo", "Stereo"),

    # Search
    "Find channels by name. Films and series are coming.": (
        "Busca canales por nombre. Las películas y series llegarán pronto.",
        "Finde Sender nach Namen. Filme und Serien folgen.",
        "Trouvez des chaînes par leur nom. Les films et séries arrivent bientôt.",
        "Encontre canais pelo nome. Filmes e séries vêm a caminho.",
        "Znajdź kanały po nazwie. Filmy i seriale wkrótce."),
    "Add an IPTV account in Settings › Connections to search channels.": (
        "Añade una cuenta IPTV en Ajustes › Conexiones para buscar canales.",
        "Füge ein IPTV-Konto unter Einstellungen › Verbindungen hinzu, um Sender zu suchen.",
        "Ajoutez un compte IPTV dans Réglages › Connexions pour rechercher des chaînes.",
        "Adicione uma conta IPTV em Definições › Ligações para pesquisar canais.",
        "Dodaj konto IPTV w Ustawienia › Połączenia, aby wyszukiwać kanały."),

    # Settings
    "Done": ("Hecho", "Fertig", "OK", "Concluído", "Gotowe"),
    "Kind": ("Tipo", "Art", "Type", "Tipo", "Rodzaj"),
    "Email or GitHub name (optional)": ("Email o nombre de GitHub (opcional)", "E-Mail oder GitHub-Name (optional)",
                                        "E-mail ou nom GitHub (facultatif)", "Email ou nome do GitHub (opcional)",
                                        "E-mail lub nazwa w GitHubie (opcjonalnie)"),
    "Your contact is only for a reply; it's kept private and never posted. Feedback never includes your logins, server or channel names.": (
        "Tu contacto solo sirve para responderte; se mantiene privado y nunca se publica. Los comentarios nunca incluyen tus accesos, tu servidor ni nombres de canales.",
        "Deine Kontaktangabe ist nur für eine Antwort; sie bleibt privat und wird nie veröffentlicht. Feedback enthält nie deine Zugangsdaten, deinen Server oder Sendernamen.",
        "Votre contact sert uniquement à vous répondre ; il reste privé et n'est jamais publié. Les retours n'incluent jamais vos identifiants, votre serveur ni les noms de chaînes.",
        "O seu contacto serve apenas para responder; é mantido privado e nunca é publicado. O feedback nunca inclui os seus acessos, servidor ou nomes de canais.",
        "Kontakt służy tylko do odpowiedzi; pozostaje prywatny i nigdy nie jest publikowany. Opinie nigdy nie zawierają danych logowania, serwera ani nazw kanałów."),
    "Feedback isn't available in this build. You can open an issue at github.com/MS2620/tellio-iOS/issues instead.": (
        "Los comentarios no están disponibles en esta versión. Puedes abrir una incidencia en github.com/MS2620/tellio-iOS/issues.",
        "Feedback ist in diesem Build nicht verfügbar. Du kannst stattdessen ein Issue unter github.com/MS2620/tellio-iOS/issues eröffnen.",
        "Les retours ne sont pas disponibles dans cette version. Vous pouvez ouvrir un ticket sur github.com/MS2620/tellio-iOS/issues.",
        "O feedback não está disponível nesta versão. Pode abrir um pedido em github.com/MS2620/tellio-iOS/issues.",
        "Opinie nie są dostępne w tej wersji. Możesz zgłosić problem na github.com/MS2620/tellio-iOS/issues."),
    "Software": ("Software", "Software", "Logiciels", "Software", "Oprogramowanie"),
    "Tap one to read its licence.": ("Toca uno para leer su licencia.", "Tippe auf einen Eintrag, um die Lizenz zu lesen.",
                                     "Touchez-en un pour lire sa licence.", "Toque num para ler a licença.",
                                     "Stuknij pozycję, aby przeczytać licencję."),
    "Backing up…": ("Haciendo copia…", "Sicherung läuft …", "Sauvegarde…", "A fazer cópia…", "Tworzenie kopii…"),
    "The same backup server and password as on your Apple TV.": (
        "El mismo servidor de copias y contraseña que en tu Apple TV.",
        "Derselbe Backup-Server und dasselbe Passwort wie auf deinem Apple TV.",
        "Le même serveur de sauvegarde et mot de passe que sur votre Apple TV.",
        "O mesmo servidor de cópias e palavra-passe que na sua Apple TV.",
        "Ten sam serwer kopii i hasło co na Apple TV."),
    "Restore": ("Restaurar", "Wiederherstellen", "Restaurer", "Restaurar", "Przywróć"),
    "On the Apple TV: Settings › Backup & restore › Back up to a code. Then enter the server, its password and the code here.": (
        "En el Apple TV: Ajustes › Copia y restauración › Hacer copia en un código. Luego introduce aquí el servidor, su contraseña y el código.",
        "Auf dem Apple TV: Einstellungen › Sichern & wiederherstellen › In einen Code sichern. Gib dann hier den Server, sein Passwort und den Code ein.",
        "Sur l'Apple TV : Réglages › Sauvegarde et restauration › Sauvegarder dans un code. Saisissez ensuite ici le serveur, son mot de passe et le code.",
        "Na Apple TV: Definições › Cópia e restauro › Copiar para um código. Depois introduza aqui o servidor, a palavra-passe e o código.",
        "Na Apple TV: Ustawienia › Kopia i przywracanie › Utwórz kopię jako kod. Następnie wpisz tutaj serwer, jego hasło i kod."),
    "Backup code": ("Código de copia", "Backup-Code", "Code de sauvegarde", "Código da cópia", "Kod kopii"),
    "Code": ("Código", "Code", "Code", "Código", "Kod"),
    "8 characters": ("8 caracteres", "8 Zeichen", "8 caractères", "8 caracteres", "8 znaków"),
    "Restoring…": ("Restaurando…", "Wird wiederhergestellt …", "Restauration…", "A restaurar…", "Przywracanie…"),
    "Replace this device's settings": ("Reemplazar los ajustes de este dispositivo",
                                       "Einstellungen dieses Geräts ersetzen",
                                       "Remplacer les réglages de cet appareil",
                                       "Substituir as definições deste dispositivo",
                                       "Zastąp ustawienia tego urządzenia"),
    "On another device: Settings › Backup & restore › Restore from a code, and enter this.": (
        "En otro dispositivo: Ajustes › Copia y restauración › Restaurar desde un código, e introduce esto.",
        "Auf einem anderen Gerät: Einstellungen › Sichern & wiederherstellen › Aus einem Code wiederherstellen, und dies eingeben.",
        "Sur un autre appareil : Réglages › Sauvegarde et restauration › Restaurer depuis un code, puis saisissez ceci.",
        "Noutro dispositivo: Definições › Cópia e restauro › Restaurar a partir de um código, e introduza isto.",
        "Na innym urządzeniu: Ustawienia › Kopia i przywracanie › Przywróć z kodu, i wpisz to."),
    "Bring your Apple TV setup": ("Trae la configuración de tu Apple TV", "Übernimm die Einrichtung deines Apple TV",
                                  "Récupérez la configuration de votre Apple TV", "Traga a configuração da sua Apple TV",
                                  "Przenieś konfigurację z Apple TV"),
    "Restore with your 8-character backup code": ("Restaura con tu código de copia de 8 caracteres",
                                                  "Mit deinem 8-stelligen Backup-Code wiederherstellen",
                                                  "Restaurez avec votre code de sauvegarde de 8 caractères",
                                                  "Restaure com o seu código de cópia de 8 caracteres",
                                                  "Przywróć za pomocą 8-znakowego kodu kopii"),
    "Switch a group off to hide it everywhere, or open it to hide single channels.": (
        "Desactiva un grupo para ocultarlo en todas partes, o ábrelo para ocultar canales sueltos.",
        "Schalte eine Gruppe aus, um sie überall auszublenden, oder öffne sie, um einzelne Sender auszublenden.",
        "Désactivez un groupe pour le masquer partout, ou ouvrez-le pour masquer des chaînes une par une.",
        "Desative um grupo para o ocultar em todo o lado, ou abra-o para ocultar canais individuais.",
        "Wyłącz grupę, aby ukryć ją wszędzie, albo otwórz ją, aby ukryć pojedyncze kanały."),
    "Find a group": ("Buscar un grupo", "Gruppe finden", "Trouver un groupe", "Procurar um grupo", "Znajdź grupę"),
    "This whole group is hidden. Switch it back on in the list of groups.": (
        "Todo este grupo está oculto. Vuelve a activarlo en la lista de grupos.",
        "Diese ganze Gruppe ist ausgeblendet. Schalte sie in der Gruppenliste wieder ein.",
        "Ce groupe entier est masqué. Réactivez-le dans la liste des groupes.",
        "Este grupo inteiro está oculto. Volte a ativá-lo na lista de grupos.",
        "Cała ta grupa jest ukryta. Włącz ją ponownie na liście grup."),
    "Folders are your own Live TV groups. A channel can be in several folders and stays in its original group too. Swipe left on a folder to delete it.": (
        "Las carpetas son tus propios grupos de TV en directo. Un canal puede estar en varias carpetas y sigue también en su grupo original. Desliza a la izquierda sobre una carpeta para eliminarla.",
        "Ordner sind deine eigenen Live-TV-Gruppen. Ein Sender kann in mehreren Ordnern sein und bleibt auch in seiner ursprünglichen Gruppe. Wische auf einem Ordner nach links, um ihn zu löschen.",
        "Les dossiers sont vos propres groupes de TV en direct. Une chaîne peut être dans plusieurs dossiers et reste aussi dans son groupe d'origine. Balayez un dossier vers la gauche pour le supprimer.",
        "As pastas são os seus próprios grupos de TV em direto. Um canal pode estar em várias pastas e continua também no grupo original. Deslize para a esquerda numa pasta para a apagar.",
        "Foldery to Twoje własne grupy telewizji na żywo. Kanał może być w kilku folderach i pozostaje też w swojej pierwotnej grupie. Przesuń folder w lewo, aby go usunąć."),
    "Create": ("Crear", "Erstellen", "Créer", "Criar", "Utwórz"),
    "Drag to reorder, swipe left to take a channel out.": (
        "Arrastra para reordenar, desliza a la izquierda para quitar un canal.",
        "Ziehen zum Umsortieren, nach links wischen, um einen Sender zu entfernen.",
        "Faites glisser pour réorganiser, balayez vers la gauche pour retirer une chaîne.",
        "Arraste para reordenar, deslize para a esquerda para retirar um canal.",
        "Przeciągnij, aby zmienić kolejność; przesuń w lewo, aby usunąć kanał."),
    "Pick the groups to split. Tellio sorts them again every time the channels load, so new channels land in the right folder. The original group is hidden; switch a group off to bring it back. Channel names in these groups lose the country tag at the start and HEVC, 4K, UHD, FHD, HD and SD; a name with no quality counts as SD.": (
        "Elige los grupos que quieres dividir. Tellio los vuelve a ordenar cada vez que se cargan los canales, así que los nuevos acaban en la carpeta correcta. El grupo original se oculta; desactiva un grupo para recuperarlo. Los nombres de los canales de estos grupos pierden la etiqueta de país del principio y HEVC, 4K, UHD, FHD, HD y SD; un nombre sin calidad cuenta como SD.",
        "Wähle die Gruppen, die aufgeteilt werden sollen. Tellio sortiert sie bei jedem Laden der Sender neu, damit neue Sender im richtigen Ordner landen. Die ursprüngliche Gruppe wird ausgeblendet; schalte eine Gruppe aus, um sie zurückzuholen. Sendernamen in diesen Gruppen verlieren das Länderkürzel am Anfang sowie HEVC, 4K, UHD, FHD, HD und SD; ein Name ohne Qualität zählt als SD.",
        "Choisissez les groupes à diviser. Tellio les trie à nouveau à chaque chargement des chaînes, pour que les nouvelles arrivent dans le bon dossier. Le groupe d'origine est masqué ; désactivez un groupe pour le retrouver. Les noms des chaînes de ces groupes perdent l'étiquette de pays au début ainsi que HEVC, 4K, UHD, FHD, HD et SD ; un nom sans qualité compte comme SD.",
        "Escolha os grupos a dividir. O Tellio volta a ordená-los sempre que os canais carregam, para que os novos fiquem na pasta certa. O grupo original fica oculto; desative um grupo para o recuperar. Os nomes dos canais destes grupos perdem a etiqueta do país no início e HEVC, 4K, UHD, FHD, HD e SD; um nome sem qualidade conta como SD.",
        "Wybierz grupy do podziału. Tellio sortuje je ponownie przy każdym wczytaniu kanałów, więc nowe kanały trafiają do właściwego folderu. Pierwotna grupa jest ukryta; wyłącz grupę, aby ją przywrócić. Nazwy kanałów w tych grupach tracą znacznik kraju na początku oraz HEVC, 4K, UHD, FHD, HD i SD; nazwa bez jakości liczy się jako SD."),
    "When streams are sorted by addon order, addons higher in the list come first.": (
        "Cuando las emisiones se ordenan por addon, los addons más arriba en la lista van primero.",
        "Wenn Streams nach Add-on-Reihenfolge sortiert sind, kommen Add-ons weiter oben in der Liste zuerst.",
        "Quand les flux sont triés par add-on, les add-ons placés plus haut dans la liste passent en premier.",
        "Quando as emissões são ordenadas por addon, os addons mais acima na lista aparecem primeiro.",
        "Gdy strumienie są sortowane według dodatków, dodatki wyżej na liście są pierwsze."),
    "Use the manifest link from the addon's own configuration page. Only results with a direct link can be played; torrent-only results are hidden.": (
        "Usa el enlace del manifiesto de la página de configuración del propio addon. Solo se pueden reproducir resultados con enlace directo; los que son solo torrent se ocultan.",
        "Verwende den Manifest-Link von der Konfigurationsseite des Add-ons. Nur Ergebnisse mit direktem Link können abgespielt werden; reine Torrent-Ergebnisse werden ausgeblendet.",
        "Utilisez le lien du manifeste depuis la page de configuration de l'add-on. Seuls les résultats avec un lien direct peuvent être lus ; ceux uniquement en torrent sont masqués.",
        "Use a ligação do manifesto da página de configuração do próprio addon. Só os resultados com ligação direta podem ser reproduzidos; os que são apenas torrent ficam ocultos.",
        "Użyj linku do manifestu ze strony konfiguracji dodatku. Odtwarzać można tylko wyniki z bezpośrednim linkiem; wyniki tylko z torrentem są ukryte."),
    "That isn't a valid address.": ("Esa dirección no es válida.", "Das ist keine gültige Adresse.",
                                    "Cette adresse n'est pas valide.", "Esse endereço não é válido.",
                                    "To nie jest prawidłowy adres."),
    "That addon is already added.": ("Ese addon ya está añadido.", "Dieses Add-on ist bereits hinzugefügt.",
                                     "Cet add-on est déjà ajouté.", "Esse addon já foi adicionado.",
                                     "Ten dodatek jest już dodany."),
    "Couldn't load it. Check the address.": ("No se pudo cargar. Comprueba la dirección.",
                                             "Konnte nicht geladen werden. Prüfe die Adresse.",
                                             "Chargement impossible. Vérifiez l'adresse.",
                                             "Não foi possível carregar. Verifique o endereço.",
                                             "Nie udało się wczytać. Sprawdź adres."),
    "Not set up": ("Sin configurar", "Nicht eingerichtet", "Non configuré", "Não configurado", "Nie skonfigurowano"),
    "Can't reach the server": ("No se puede contactar con el servidor", "Server nicht erreichbar",
                               "Serveur injoignable", "Não é possível contactar o servidor",
                               "Brak połączenia z serwerem"),
    "Connected": ("Conectado", "Verbunden", "Connecté", "Ligado", "Połączono"),
    "Token not accepted": ("Token no aceptado", "Token nicht akzeptiert", "Jeton refusé", "Token não aceite",
                           "Token nie został zaakceptowany"),
    "Can't reach TMDB": ("No se puede contactar con TMDB", "TMDB nicht erreichbar", "TMDB injoignable",
                         "Não é possível contactar o TMDB", "Brak połączenia z TMDB"),
    "Add another account": ("Añadir otra cuenta", "Weiteres Konto hinzufügen", "Ajouter un autre compte",
                            "Adicionar outra conta", "Dodaj kolejne konto"),
    "Live TV uses one account at a time. Open an account and choose Use for Live TV.": (
        "La TV en directo usa una cuenta a la vez. Abre una cuenta y elige Usar para TV en directo.",
        "Live-TV verwendet jeweils ein Konto. Öffne ein Konto und wähle Für Live-TV verwenden.",
        "La TV en direct utilise un compte à la fois. Ouvrez un compte et choisissez Utiliser pour la TV en direct.",
        "A TV em direto usa uma conta de cada vez. Abra uma conta e escolha Usar para TV em direto.",
        "Telewizja na żywo używa jednego konta naraz. Otwórz konto i wybierz Użyj do telewizji na żywo."),
    "Not connected": ("No conectado", "Nicht verbunden", "Non connecté", "Não ligado", "Nie połączono"),
    "Movies and series play from your addons. Streams are tried in the order they're listed here.": (
        "Las películas y series se reproducen desde tus addons. Las emisiones se prueban en el orden en que aparecen aquí.",
        "Filme und Serien werden über deine Add-ons abgespielt. Streams werden in der hier gezeigten Reihenfolge versucht.",
        "Les films et séries sont lus depuis vos add-ons. Les flux sont essayés dans l'ordre affiché ici.",
        "Os filmes e séries são reproduzidos a partir dos seus addons. As emissões são tentadas pela ordem aqui indicada.",
        "Filmy i seriale są odtwarzane z Twoich dodatków. Strumienie są próbowane w kolejności podanej tutaj."),
    "Signs out of TMDB and your IPTV accounts and removes every addon. Your favourites, folders and other settings stay.": (
        "Cierra sesión en TMDB y en tus cuentas IPTV y quita todos los addons. Tus favoritos, carpetas y demás ajustes se mantienen.",
        "Meldet dich bei TMDB und deinen IPTV-Konten ab und entfernt alle Add-ons. Deine Favoriten, Ordner und anderen Einstellungen bleiben.",
        "Vous déconnecte de TMDB et de vos comptes IPTV et supprime tous les add-ons. Vos favoris, dossiers et autres réglages sont conservés.",
        "Termina sessão no TMDB e nas suas contas IPTV e remove todos os addons. Os seus favoritos, pastas e outras definições mantêm-se.",
        "Wylogowuje z TMDB i kont IPTV oraz usuwa wszystkie dodatki. Ulubione, foldery i pozostałe ustawienia zostają."),
    "IPTV account": ("Cuenta IPTV", "IPTV-Konto", "Compte IPTV", "Conta IPTV", "Konto IPTV"),
    "The name is only for you; without one the server is shown.": (
        "El nombre es solo para ti; sin él se muestra el servidor.",
        "Der Name ist nur für dich; ohne ihn wird der Server angezeigt.",
        "Le nom n'est que pour vous ; sans lui, le serveur est affiché.",
        "O nome é só para si; sem ele é mostrado o servidor.",
        "Nazwa jest tylko dla Ciebie; bez niej wyświetlany jest serwer."),
    "Every launch": ("En cada inicio", "Bei jedem Start", "À chaque lancement", "Em cada arranque", "Przy każdym uruchomieniu"),
    "Your token": ("Tu token", "Dein Token", "Votre jeton", "O seu token", "Twój token"),
    "Using the built-in key": ("Usando la clave integrada", "Integrierter Schlüssel wird verwendet",
                               "Clé intégrée utilisée", "A usar a chave integrada", "Używany jest wbudowany klucz"),
    "Save token": ("Guardar token", "Token speichern", "Enregistrer le jeton", "Guardar token", "Zapisz token"),
    "Tellio has a TMDB key built in, so there's nothing to set up. To use your own instead, get the long \"API Read Access Token\" from themoviedb.org › Settings › API.": (
        "Tellio tiene una clave de TMDB integrada, así que no hay nada que configurar. Para usar la tuya, consigue el «API Read Access Token» largo en themoviedb.org › Settings › API.",
        "Tellio hat einen TMDB-Schlüssel eingebaut, es gibt also nichts einzurichten. Um deinen eigenen zu verwenden, hol dir das lange „API Read Access Token“ unter themoviedb.org › Settings › API.",
        "Tellio intègre une clé TMDB, il n'y a donc rien à configurer. Pour utiliser la vôtre, récupérez le long « API Read Access Token » sur themoviedb.org › Settings › API.",
        "O Tellio tem uma chave TMDB integrada, por isso não há nada a configurar. Para usar a sua, obtenha o «API Read Access Token» longo em themoviedb.org › Settings › API.",
        "Tellio ma wbudowany klucz TMDB, więc nie trzeba nic konfigurować. Aby użyć własnego, pobierz długi „API Read Access Token” z themoviedb.org › Settings › API."),
    "Free from themoviedb.org › Settings › API. Use the long \"API Read Access Token\", not the short API key.": (
        "Gratis en themoviedb.org › Settings › API. Usa el «API Read Access Token» largo, no la clave API corta.",
        "Kostenlos unter themoviedb.org › Settings › API. Verwende das lange „API Read Access Token“, nicht den kurzen API-Schlüssel.",
        "Gratuit sur themoviedb.org › Settings › API. Utilisez le long « API Read Access Token », pas la clé API courte.",
        "Gratuito em themoviedb.org › Settings › API. Use o «API Read Access Token» longo, não a chave API curta.",
        "Bezpłatnie na themoviedb.org › Settings › API. Użyj długiego „API Read Access Token”, nie krótkiego klucza API."),
    "Home, Browse and Search need it to show anything.": (
        "Inicio, Explorar y Buscar lo necesitan para mostrar algo.",
        "Start, Entdecken und Suche brauchen ihn, um etwas anzuzeigen.",
        "Accueil, Explorer et Recherche en ont besoin pour afficher quoi que ce soit.",
        "Início, Explorar e Pesquisa precisam dele para mostrar alguma coisa.",
        "Start, Przeglądaj i Szukaj potrzebują go, aby cokolwiek pokazać."),
    "Your account": ("Tu cuenta", "Dein Konto", "Votre compte", "A sua conta", "Twoje konto"),
    "Progress & Continue Watching": ("Progreso y Seguir viendo", "Fortschritt & Weiterschauen",
                                     "Progression et Reprendre", "Progresso e Continuar a ver",
                                     "Postęp i Oglądaj dalej"),
    "Syncs when Tellio opens and every 10 minutes. Scrobbling shows “Watching now” on your Trakt profile and marks things watched at 80%.": (
        "Se sincroniza al abrir Tellio y cada 10 minutos. El scrobbling muestra «Viendo ahora» en tu perfil de Trakt y marca lo visto al 80 %.",
        "Synchronisiert beim Öffnen von Tellio und alle 10 Minuten. Scrobbling zeigt „Schaut gerade“ in deinem Trakt-Profil und markiert Titel bei 80 % als gesehen.",
        "Se synchronise à l'ouverture de Tellio et toutes les 10 minutes. Le scrobbling affiche « En cours » sur votre profil Trakt et marque comme vu à 80 %.",
        "Sincroniza quando o Tellio abre e a cada 10 minutos. O scrobbling mostra «A ver agora» no seu perfil Trakt e marca como visto aos 80%.",
        "Synchronizuje się przy otwarciu Tellio i co 10 minut. Scrobbling pokazuje „Teraz ogląda” na profilu Trakt i oznacza jako obejrzane przy 80%."),
    "Progress and ticks already on this device stay. Nothing is deleted on Trakt.": (
        "El progreso y las marcas que ya hay en este dispositivo se mantienen. No se borra nada en Trakt.",
        "Fortschritt und Häkchen auf diesem Gerät bleiben. Auf Trakt wird nichts gelöscht.",
        "La progression et les coches déjà sur cet appareil sont conservées. Rien n'est supprimé sur Trakt.",
        "O progresso e as marcas já neste dispositivo mantêm-se. Nada é apagado no Trakt.",
        "Postęp i znaczniki na tym urządzeniu zostają. Na Trakt nic nie jest usuwane."),
    "Copy code and open": ("Copiar código y abrir", "Code kopieren und öffnen", "Copier le code et ouvrir",
                           "Copiar código e abrir", "Skopiuj kod i otwórz"),
    "Copied": ("Copiado", "Kopiert", "Copié", "Copiado", "Skopiowano"),
    "Copy": ("Copiar", "Kopieren", "Copier", "Copiar", "Kopiuj"),
    "Using the built-in app": ("Usando la app integrada", "Integrierte App wird verwendet", "App intégrée utilisée",
                               "A usar a app integrada", "Używana jest wbudowana aplikacja"),
    "Client secret": ("Client secret", "Client Secret", "Client secret", "Client secret", "Client secret"),
    "Older apps only": ("Solo apps antiguas", "Nur ältere Apps", "Anciennes apps uniquement", "Só apps antigas",
                        "Tylko starsze aplikacje"),
    "On trakt.tv go to Settings › Your API Apps › New Application, give it any name and use urn:ietf:wg:oauth:2.0:oob as the redirect URI. New apps only have a Client ID; a secret is only needed for older apps. After changing the app, sign in to Trakt again.": (
        "En trakt.tv ve a Settings › Your API Apps › New Application, ponle cualquier nombre y usa urn:ietf:wg:oauth:2.0:oob como URI de redirección. Las apps nuevas solo tienen un Client ID; el secret solo hace falta en apps antiguas. Después de cambiar la app, vuelve a iniciar sesión en Trakt.",
        "Gehe auf trakt.tv zu Settings › Your API Apps › New Application, gib ihr einen beliebigen Namen und verwende urn:ietf:wg:oauth:2.0:oob als Redirect-URI. Neue Apps haben nur eine Client ID; ein Secret brauchen nur ältere Apps. Melde dich nach einer Änderung der App erneut bei Trakt an.",
        "Sur trakt.tv, allez dans Settings › Your API Apps › New Application, donnez-lui un nom et utilisez urn:ietf:wg:oauth:2.0:oob comme URI de redirection. Les nouvelles apps n'ont qu'un Client ID ; le secret n'est nécessaire que pour les anciennes. Après avoir modifié l'app, reconnectez-vous à Trakt.",
        "Em trakt.tv vá a Settings › Your API Apps › New Application, dê-lhe um nome qualquer e use urn:ietf:wg:oauth:2.0:oob como URI de redirecionamento. As apps novas só têm Client ID; o secret só é preciso em apps antigas. Depois de alterar a app, inicie sessão no Trakt novamente.",
        "Na trakt.tv przejdź do Settings › Your API Apps › New Application, nadaj dowolną nazwę i użyj urn:ietf:wg:oauth:2.0:oob jako URI przekierowania. Nowe aplikacje mają tylko Client ID; secret jest potrzebny tylko starszym. Po zmianie aplikacji zaloguj się ponownie do Trakt."),
    "Tap a programme that hasn't started in the guide, then Remind me. You're notified 30 seconds before it begins, even when Tellio is closed.": (
        "Toca en la guía un programa que no haya empezado y luego Recordármelo. Recibirás un aviso 30 segundos antes de que empiece, aunque Tellio esté cerrado.",
        "Tippe im Programm auf eine Sendung, die noch nicht begonnen hat, dann auf Erinnern. Du wirst 30 Sekunden vor Beginn benachrichtigt, auch wenn Tellio geschlossen ist.",
        "Touchez dans le guide un programme qui n'a pas commencé, puis Me le rappeler. Vous êtes prévenu 30 secondes avant le début, même quand Tellio est fermé.",
        "Toque no guia num programa que ainda não começou e depois em Lembrar-me. É notificado 30 segundos antes de começar, mesmo com o Tellio fechado.",
        "Stuknij w przewodniku program, który się jeszcze nie zaczął, a potem Przypomnij. Dostaniesz powiadomienie 30 sekund przed początkiem, nawet gdy Tellio jest zamknięty."),
    "Default view on iPhone": ("Vista predeterminada en iPhone", "Standardansicht auf dem iPhone",
                               "Vue par défaut sur iPhone", "Vista predefinida no iPhone",
                               "Domyślny widok na iPhonie"),
    "Show programme information": ("Mostrar información del programa", "Sendungsinfos anzeigen",
                                   "Afficher les infos des programmes", "Mostrar informação do programa",
                                   "Pokazuj informacje o programie"),
    "Now and next, and the guide": ("Ahora y a continuación, y la guía", "Jetzt und danach, und das Programm",
                                    "Maintenant et ensuite, et le guide", "Agora e a seguir, e o guia",
                                    "Teraz i następnie oraz przewodnik"),
    "Hide groups and channels, or build your own folders, in Settings › Content.": (
        "Oculta grupos y canales, o crea tus propias carpetas, en Ajustes › Contenido.",
        "Blende Gruppen und Sender aus oder erstelle eigene Ordner unter Einstellungen › Inhalte.",
        "Masquez des groupes et des chaînes, ou créez vos propres dossiers, dans Réglages › Contenu.",
        "Oculte grupos e canais, ou crie as suas pastas, em Definições › Conteúdo.",
        "Ukrywaj grupy i kanały albo twórz własne foldery w Ustawienia › Treści."),
    "Timeshift": ("Timeshift", "Timeshift", "Timeshift", "Timeshift", "Timeshift"),
    "Pause and rewind live TV": ("Pausar y rebobinar la TV en directo", "Live-TV pausieren und zurückspulen",
                                 "Mettre en pause et revenir en arrière en direct", "Pausar e recuar na TV em direto",
                                 "Wstrzymuj i przewijaj telewizję na żywo"),
    "30 min": ("30 min", "30 Min.", "30 min", "30 min", "30 min"),
    "Try MPEG-TS if channels fail on HLS. Stable switching starts slower but buffers more.": (
        "Prueba MPEG-TS si los canales fallan con HLS. El cambio estable empieza más despacio pero almacena más.",
        "Versuche MPEG-TS, wenn Sender mit HLS nicht laufen. Stabiles Umschalten startet langsamer, puffert aber mehr.",
        "Essayez MPEG-TS si les chaînes échouent en HLS. Le changement stable démarre plus lentement mais met davantage en mémoire tampon.",
        "Experimente MPEG-TS se os canais falharem em HLS. A troca estável começa mais devagar mas guarda mais em memória.",
        "Spróbuj MPEG-TS, jeśli kanały nie działają w HLS. Stabilne przełączanie startuje wolniej, ale buforuje więcej."),
    "Every time Tellio opens": ("Cada vez que se abre Tellio", "Bei jedem Öffnen von Tellio",
                                "À chaque ouverture de Tellio", "Sempre que o Tellio abre",
                                "Przy każdym otwarciu Tellio"),
    "Guide data is kept on this device between refreshes, so the guide opens quickly and your provider is asked less often.": (
        "Los datos de la guía se guardan en este dispositivo entre actualizaciones, así que la guía abre rápido y se consulta menos a tu proveedor.",
        "Programmdaten bleiben zwischen den Aktualisierungen auf diesem Gerät, sodass das Programm schnell öffnet und dein Anbieter seltener abgefragt wird.",
        "Les données du guide sont conservées sur cet appareil entre deux actualisations : le guide s'ouvre vite et votre fournisseur est moins sollicité.",
        "Os dados do guia ficam neste dispositivo entre atualizações, para que o guia abra depressa e o seu fornecedor seja consultado menos vezes.",
        "Dane przewodnika są przechowywane na tym urządzeniu między odświeżeniami, więc przewodnik otwiera się szybko, a dostawca jest pytany rzadziej."),
    "Adds the film and series libraries that come with your IPTV login as extra rows in Browse.": (
        "Añade las bibliotecas de películas y series de tu acceso IPTV como filas extra en Explorar.",
        "Fügt die Film- und Serienbibliotheken deines IPTV-Zugangs als zusätzliche Reihen in Entdecken hinzu.",
        "Ajoute les bibliothèques de films et séries de votre accès IPTV comme rangées supplémentaires dans Explorer.",
        "Adiciona as bibliotecas de filmes e séries do seu acesso IPTV como filas extra em Explorar.",
        "Dodaje biblioteki filmów i seriali z Twojego konta IPTV jako dodatkowe rzędy w Przeglądaj."),
    "5 minutes": ("5 minutos", "5 Minuten", "5 minutes", "5 minutos", "5 minut"),
    "15 minutes": ("15 minutos", "15 Minuten", "15 minutes", "15 minutos", "15 minut"),
    "4 hours": ("4 horas", "4 Stunden", "4 heures", "4 horas", "4 godziny"),
    "Locked groups and addons need the PIN. Once entered, everything stays unlocked for the time you choose, then locks again. The PIN is shared with the Apple TV through the backup.": (
        "Los grupos y addons bloqueados piden el PIN. Una vez introducido, todo queda desbloqueado durante el tiempo que elijas y luego se vuelve a bloquear. El PIN se comparte con el Apple TV mediante la copia de seguridad.",
        "Gesperrte Gruppen und Add-ons brauchen die PIN. Nach der Eingabe bleibt alles für die gewählte Zeit entsperrt und sperrt sich dann wieder. Die PIN wird über das Backup mit dem Apple TV geteilt.",
        "Les groupes et add-ons verrouillés demandent le code PIN. Une fois saisi, tout reste déverrouillé pendant la durée choisie, puis se verrouille à nouveau. Le PIN est partagé avec l'Apple TV via la sauvegarde.",
        "Os grupos e addons bloqueados pedem o PIN. Depois de introduzido, tudo fica desbloqueado durante o tempo escolhido e volta a bloquear. O PIN é partilhado com a Apple TV através da cópia de segurança.",
        "Zablokowane grupy i dodatki wymagają PIN-u. Po jego wpisaniu wszystko pozostaje odblokowane przez wybrany czas, a potem znów się blokuje. PIN jest udostępniany Apple TV przez kopię zapasową."),
    "Locked addons": ("Addons bloqueados", "Gesperrte Add-ons", "Add-ons verrouillés", "Addons bloqueados",
                      "Zablokowane dodatki"),
    "Skipping": ("Saltos", "Springen", "Sauts", "Saltos", "Przewijanie"),
    "The skip buttons in the player, and double-tapping the left or right side of the picture.": (
        "Los botones de salto del reproductor y el doble toque en el lado izquierdo o derecho de la imagen.",
        "Die Sprungtasten im Player und doppeltes Tippen auf die linke oder rechte Bildseite.",
        "Les boutons de saut du lecteur, et le double toucher sur le côté gauche ou droit de l'image.",
        "Os botões de salto do leitor e o toque duplo no lado esquerdo ou direito da imagem.",
        "Przyciski przewijania w odtwarzaczu i dwukrotne stuknięcie lewej lub prawej strony obrazu."),
    "Night mode": ("Modo nocturno", "Nachtmodus", "Mode nuit", "Modo noturno", "Tryb nocny"),
    "Quieter loud scenes": ("Escenas fuertes más suaves", "Leisere laute Szenen", "Scènes bruyantes adoucies",
                            "Cenas ruidosas mais suaves", "Cichsze głośne sceny"),
    "These are shared with the Apple TV, where they also turn off Dolby Atmos passthrough while on.": (
        "Se comparten con el Apple TV, donde además desactivan el paso directo de Dolby Atmos mientras están activos.",
        "Diese werden mit dem Apple TV geteilt, wo sie außerdem das Dolby-Atmos-Passthrough ausschalten, solange sie an sind.",
        "Ces réglages sont partagés avec l'Apple TV, où ils désactivent aussi le passthrough Dolby Atmos tant qu'ils sont actifs.",
        "São partilhadas com a Apple TV, onde também desligam o passthrough Dolby Atmos enquanto estão ativas.",
        "Są wspólne z Apple TV, gdzie po włączeniu wyłączają też przekazywanie Dolby Atmos."),
    "Drag the handles to reorder. Continue Watching is always first. My List, Favourite Channels and My Teams only appear once they have something in them. The order is shared with the Apple TV.": (
        "Arrastra los tiradores para reordenar. Seguir viendo siempre va primero. Mi lista, Canales favoritos y Mis equipos solo aparecen cuando tienen algo. El orden se comparte con el Apple TV.",
        "Ziehe die Griffe zum Umsortieren. Weiterschauen ist immer zuerst. Meine Liste, Lieblingssender und Meine Teams erscheinen erst, wenn sie etwas enthalten. Die Reihenfolge wird mit dem Apple TV geteilt.",
        "Faites glisser les poignées pour réorganiser. Reprendre est toujours en premier. Ma liste, Chaînes favorites et Mes équipes n'apparaissent que lorsqu'elles contiennent quelque chose. L'ordre est partagé avec l'Apple TV.",
        "Arraste as pegas para reordenar. Continuar a ver aparece sempre primeiro. Minha lista, Canais favoritos e As minhas equipas só aparecem quando têm algo. A ordem é partilhada com a Apple TV.",
        "Przeciągaj uchwyty, aby zmienić kolejność. Oglądaj dalej jest zawsze pierwsze. Moja lista, Ulubione kanały i Moje drużyny pojawiają się dopiero, gdy coś zawierają. Kolejność jest wspólna z Apple TV."),
    "Next only": ("Solo el siguiente", "Nur die nächste", "Le prochain seulement", "Só o seguinte", "Tylko następny"),
    "Next 2": ("Los 2 siguientes", "Die nächsten 2", "Les 2 prochains", "Os 2 seguintes", "Następne 2"),
    "Next 3": ("Los 3 siguientes", "Die nächsten 3", "Les 3 prochains", "Os 3 seguintes", "Następne 3"),
    "Next 5": ("Los 5 siguientes", "Die nächsten 5", "Les 5 prochains", "Os 5 seguintes", "Następne 5"),
    "IPTV, addons, Trakt, TMDB": ("IPTV, addons, Trakt, TMDB", "IPTV, Add-ons, Trakt, TMDB", "IPTV, add-ons, Trakt, TMDB",
                                  "IPTV, addons, Trakt, TMDB", "IPTV, dodatki, Trakt, TMDB"),
    "Groups, folders, sort by quality": ("Grupos, carpetas, ordenar por calidad", "Gruppen, Ordner, nach Qualität sortieren",
                                         "Groupes, dossiers, tri par qualité", "Grupos, pastas, ordenar por qualidade",
                                         "Grupy, foldery, sortowanie wg jakości"),
    "Tellio follows your iPhone's language. To choose another, tap Language, then Language on Tellio's page in the Settings app.": (
        "Tellio usa el idioma de tu iPhone. Para elegir otro, toca Idioma y luego Idioma en la página de Tellio de la app Ajustes.",
        "Tellio folgt der Sprache deines iPhone. Um eine andere zu wählen, tippe auf Sprache und dann auf der Tellio-Seite der Einstellungen-App auf Sprache.",
        "Tellio suit la langue de votre iPhone. Pour en choisir une autre, touchez Langue, puis Langue sur la page de Tellio dans l'app Réglages.",
        "O Tellio segue o idioma do seu iPhone. Para escolher outro, toque em Idioma e depois em Idioma na página do Tellio na app Definições.",
        "Tellio używa języka iPhone'a. Aby wybrać inny, stuknij Język, a potem Język na stronie Tellio w aplikacji Ustawienia."),
    "System player": ("Reproductor del sistema", "System-Player", "Lecteur du système", "Leitor do sistema",
                      "Odtwarzacz systemowy"),
    "A problem or an idea": ("Un problema o una idea", "Ein Problem oder eine Idee", "Un problème ou une idée",
                             "Um problema ou uma ideia", "Problem lub pomysł"),
    "When Tellio crashes, a report is sent the next time it opens. It holds where in Tellio's code it crashed and the iOS version and model, nothing else.": (
        "Cuando Tellio falla, se envía un informe la próxima vez que se abre. Contiene en qué parte del código de Tellio falló, y la versión de iOS y el modelo, nada más.",
        "Wenn Tellio abstürzt, wird beim nächsten Öffnen ein Bericht gesendet. Er enthält, wo im Code von Tellio es abgestürzt ist, sowie die iOS-Version und das Modell, sonst nichts.",
        "Quand Tellio plante, un rapport est envoyé à la prochaine ouverture. Il indique où le code de Tellio a planté, ainsi que la version d'iOS et le modèle, rien d'autre.",
        "Quando o Tellio falha, é enviado um relatório da próxima vez que abre. Indica onde no código do Tellio falhou, e a versão do iOS e o modelo, nada mais.",
        "Gdy Tellio się zawiesi, przy następnym otwarciu wysyłany jest raport. Zawiera miejsce w kodzie Tellio, w którym nastąpiła awaria, oraz wersję iOS i model, nic więcej."),

    # Sports
    "Add your IPTV login in Settings › Connections to find this in your TV guide.": (
        "Añade tu acceso IPTV en Ajustes › Conexiones para encontrarlo en tu guía de TV.",
        "Füge deine IPTV-Zugangsdaten unter Einstellungen › Verbindungen hinzu, um dies in deinem TV-Programm zu finden.",
        "Ajoutez votre identifiant IPTV dans Réglages › Connexions pour le trouver dans votre guide TV.",
        "Adicione o seu acesso IPTV em Definições › Ligações para encontrar isto no seu guia de TV.",
        "Dodaj dane logowania IPTV w Ustawienia › Połączenia, aby znaleźć to w przewodniku TV."),
    "Channels showing this will appear here once it's listed, usually a day or two before.": (
        "Los canales que lo emitan aparecerán aquí cuando esté en la guía, normalmente uno o dos días antes.",
        "Sender, die es zeigen, erscheinen hier, sobald es im Programm steht, meist ein oder zwei Tage vorher.",
        "Les chaînes qui le diffusent apparaîtront ici dès qu'il sera au programme, généralement un ou deux jours avant.",
        "Os canais que o transmitem aparecem aqui quando estiver no guia, normalmente um ou dois dias antes.",
        "Kanały, które to pokazują, pojawią się tutaj, gdy znajdzie się w przewodniku, zwykle dzień lub dwa wcześniej."),
    "Choose your teams to see when they next play or race, with live scores and the channels showing each match.": (
        "Elige tus equipos para ver cuándo juegan o corren, con resultados en directo y los canales que emiten cada partido.",
        "Wähle deine Teams, um zu sehen, wann sie als Nächstes spielen oder fahren, mit Live-Ergebnissen und den Sendern, die jedes Spiel zeigen.",
        "Choisissez vos équipes pour voir quand elles jouent ou courent, avec les scores en direct et les chaînes qui diffusent chaque match.",
        "Escolha as suas equipas para ver quando jogam ou correm, com resultados em direto e os canais que transmitem cada jogo.",
        "Wybierz drużyny, aby widzieć, kiedy grają lub się ścigają, z wynikami na żywo i kanałami pokazującymi każdy mecz."),
    "No teams yet. Search above, or browse by league below.": (
        "Aún no hay equipos. Busca arriba o explora por liga abajo.",
        "Noch keine Teams. Suche oben oder stöbere unten nach Liga.",
        "Aucune équipe pour l'instant. Recherchez ci-dessus ou parcourez par ligue ci-dessous.",
        "Ainda não há equipas. Pesquise acima ou explore por liga abaixo.",
        "Brak drużyn. Wyszukaj powyżej lub przeglądaj według ligi poniżej."),
    "Swipe left on a team to stop following it.": (
        "Desliza a la izquierda sobre un equipo para dejar de seguirlo.",
        "Wische auf einem Team nach links, um ihm nicht mehr zu folgen.",
        "Balayez une équipe vers la gauche pour ne plus la suivre.",
        "Deslize para a esquerda numa equipa para deixar de a seguir.",
        "Przesuń drużynę w lewo, aby przestać ją obserwować."),
    "Search teams, e.g. Porto, McLaren, Bath": ("Busca equipos, p. ej. Porto, McLaren, Bath",
                                                "Teams suchen, z. B. Porto, McLaren, Bath",
                                                "Rechercher des équipes, ex. Porto, McLaren, Bath",
                                                "Pesquise equipas, p. ex. Porto, McLaren, Bath",
                                                "Szukaj drużyn, np. Porto, McLaren, Bath"),
    "Follow": ("Seguir", "Folgen", "Suivre", "Seguir", "Obserwuj"),
    "Find a competition": ("Buscar una competición", "Wettbewerb finden", "Trouver une compétition",
                           "Procurar uma competição", "Znajdź rozgrywki"),
}

# Text with values in it. %@ is text, %lld a number; translations keep the same ones
# (numbered, %1$@ %2$@, where the order changes).
FORMATS = {
    "%@, %@, %@ to %@": ("%1$@, %2$@, de %3$@ a %4$@", "%1$@, %2$@, %3$@ bis %4$@", "%1$@, %2$@, de %3$@ à %4$@",
                         "%1$@, %2$@, das %3$@ às %4$@", "%1$@, %2$@, od %3$@ do %4$@"),
    "%@ is locked.": ("%@ está bloqueado.", "%@ ist gesperrt.", "%@ est verrouillé.", "%@ está bloqueado.",
                      "%@ jest zablokowane."),
    "No channels match “%@”.": ("Ningún canal coincide con «%@».", "Keine Sender passen zu „%@“.",
                                "Aucune chaîne ne correspond à « %@ ».", "Nenhum canal corresponde a «%@».",
                                "Żaden kanał nie pasuje do „%@”."),
    "NOW · %@ – %@": ("AHORA · %@ – %@", "JETZT · %@ – %@", "MAINTENANT · %@ – %@", "AGORA · %@ – %@",
                      "TERAZ · %@ – %@"),
    "Remove %@": ("Quitar %@", "%@ entfernen", "Retirer %@", "Remover %@", "Usuń %@"),
    "%@, playing sound": ("%@, con sonido", "%@, Ton an", "%@, son activé", "%@, com som", "%@, z dźwiękiem"),
    "Track %lld": ("Pista %lld", "Spur %lld", "Piste %lld", "Faixa %lld", "Ścieżka %lld"),
    "%@ on %@": ("%1$@ en %2$@", "%1$@ auf %2$@", "%1$@ sur %2$@", "%1$@ no %2$@", "%1$@ na %2$@"),
    "STARTING NOW · %@": ("EMPIEZA AHORA · %@", "BEGINNT JETZT · %@", "COMMENCE MAINTENANT · %@",
                          "A COMEÇAR AGORA · %@", "ZACZYNA SIĘ TERAZ · %@"),
    "Backup code %@": ("Código de copia %@", "Backup-Code %@", "Code de sauvegarde %@", "Código da cópia %@",
                       "Kod kopii %@"),
    "Go to %@ and enter this code": ("Ve a %@ e introduce este código", "Gehe zu %@ und gib diesen Code ein",
                                     "Allez sur %@ et saisissez ce code", "Vá a %@ e introduza este código",
                                     "Wejdź na %@ i wpisz ten kod"),
    "Code %@": ("Código %@", "Code %@", "Code %@", "Código %@", "Kod %@"),
    "Couldn't start sign-in: %@. Check the client ID.": (
        "No se pudo iniciar sesión: %@. Comprueba el Client ID.",
        "Anmeldung konnte nicht gestartet werden: %@. Prüfe die Client ID.",
        "Impossible de lancer la connexion : %@. Vérifiez le Client ID.",
        "Não foi possível iniciar sessão: %@. Verifique o Client ID.",
        "Nie udało się rozpocząć logowania: %@. Sprawdź Client ID."),
    "● LIVE %@": ("● EN DIRECTO %@", "● LIVE %@", "● EN DIRECT %@", "● EM DIRETO %@", "● NA ŻYWO %@"),
    "You stopped at %@": ("Te quedaste en %@", "Du hast bei %@ aufgehört", "Vous vous êtes arrêté à %@",
                          "Parou em %@", "Zatrzymano na %@"),
    "%@ · resume offered when you pick a stream": (
        "%@ · se ofrecerá continuar al elegir una emisión",
        "%@ · Fortsetzen wird angeboten, wenn du einen Stream wählst",
        "%@ · la reprise vous sera proposée en choisissant un flux",
        "%@ · retomar será sugerido quando escolher uma emissão",
        "%@ · wznowienie pojawi się po wybraniu strumienia"),
    "All · %lld": ("Todo · %lld", "Alle · %lld", "Tout · %lld", "Tudo · %lld", "Wszystko · %lld"),
    "Couldn't reach: %@": ("No se pudo contactar: %@", "Nicht erreichbar: %@", "Injoignable : %@",
                           "Não foi possível contactar: %@", "Brak połączenia: %@"),
    "Resume S%lld · E%lld": ("Continuar T%lld · E%lld", "Fortsetzen S%lld · F%lld", "Reprendre S%lld · É%lld",
                             "Retomar T%lld · E%lld", "Wznów S%lld · O%lld"),
    "Play S%lld · E1": ("Reproducir T%lld · E1", "S%lld · F1 abspielen", "Lire S%lld · É1",
                        "Reproduzir T%lld · E1", "Odtwórz S%lld · O1"),
    "Airs %@": ("Se emite el %@", "Läuft am %@", "Diffusion le %@", "Estreia a %@", "Emisja %@"),
}

PLURALS = {
    "%lld CHANNELS": {
        "en": ("%lld CHANNEL", "%lld CHANNELS"), "es": ("%lld CANAL", "%lld CANALES"),
        "de": ("%lld SENDER", "%lld SENDER"), "fr": ("%lld CHAÎNE", "%lld CHAÎNES"),
        "pt-PT": ("%lld CANAL", "%lld CANAIS"), "pl": ("%lld KANAŁ", "%lld KANAŁY", "%lld KANAŁÓW")},
    "%lld CHANNELS FOUND": {
        "en": ("%lld CHANNEL FOUND", "%lld CHANNELS FOUND"), "es": ("%lld CANAL ENCONTRADO", "%lld CANALES ENCONTRADOS"),
        "de": ("%lld SENDER GEFUNDEN", "%lld SENDER GEFUNDEN"), "fr": ("%lld CHAÎNE TROUVÉE", "%lld CHAÎNES TROUVÉES"),
        "pt-PT": ("%lld CANAL ENCONTRADO", "%lld CANAIS ENCONTRADOS"),
        "pl": ("ZNALEZIONO %lld KANAŁ", "ZNALEZIONO %lld KANAŁY", "ZNALEZIONO %lld KANAŁÓW")},
    "Back %lld seconds": {
        "en": ("Back %lld second", "Back %lld seconds"), "es": ("Atrás %lld segundo", "Atrás %lld segundos"),
        "de": ("%lld Sekunde zurück", "%lld Sekunden zurück"), "fr": ("Reculer de %lld seconde", "Reculer de %lld secondes"),
        "pt-PT": ("Recuar %lld segundo", "Recuar %lld segundos"),
        "pl": ("Cofnij o %lld sekundę", "Cofnij o %lld sekundy", "Cofnij o %lld sekund")},
    "Forward %lld seconds": {
        "en": ("Forward %lld second", "Forward %lld seconds"), "es": ("Adelante %lld segundo", "Adelante %lld segundos"),
        "de": ("%lld Sekunde vor", "%lld Sekunden vor"), "fr": ("Avancer de %lld seconde", "Avancer de %lld secondes"),
        "pt-PT": ("Avançar %lld segundo", "Avançar %lld segundos"),
        "pl": ("Do przodu o %lld sekundę", "Do przodu o %lld sekundy", "Do przodu o %lld sekund")},
    "Every %lld hours": {
        "en": ("Every hour", "Every %lld hours"), "es": ("Cada hora", "Cada %lld horas"),
        "de": ("Jede Stunde", "Alle %lld Stunden"), "fr": ("Toutes les heures", "Toutes les %lld heures"),
        "pt-PT": ("A cada hora", "A cada %lld horas"),
        "pl": ("Co godzinę", "Co %lld godziny", "Co %lld godzin")},
    "%lld of 4 digits entered": {
        "en": ("%lld of 4 digits entered", "%lld of 4 digits entered"),
        "es": ("%lld de 4 dígitos introducido", "%lld de 4 dígitos introducidos"),
        "de": ("%lld von 4 Ziffern eingegeben", "%lld von 4 Ziffern eingegeben"),
        "fr": ("%lld chiffre sur 4 saisi", "%lld chiffres sur 4 saisis"),
        "pt-PT": ("%lld de 4 dígitos introduzido", "%lld de 4 dígitos introduzidos"),
        "pl": ("Wpisano %lld z 4 cyfr", "Wpisano %lld z 4 cyfr", "Wpisano %lld z 4 cyfr")},
    "%lld torrent-only results hidden.": {
        "en": ("%lld torrent-only result hidden.", "%lld torrent-only results hidden."),
        "es": ("%lld resultado solo torrent oculto.", "%lld resultados solo torrent ocultos."),
        "de": ("%lld reines Torrent-Ergebnis ausgeblendet.", "%lld reine Torrent-Ergebnisse ausgeblendet."),
        "fr": ("%lld résultat uniquement torrent masqué.", "%lld résultats uniquement torrent masqués."),
        "pt-PT": ("%lld resultado só torrent oculto.", "%lld resultados só torrent ocultos."),
        "pl": ("Ukryto %lld wynik tylko z torrentem.", "Ukryto %lld wyniki tylko z torrentem.",
               "Ukryto %lld wyników tylko z torrentem.")},
    "%lld seasons": {
        "en": ("%lld season", "%lld seasons"), "es": ("%lld temporada", "%lld temporadas"),
        "de": ("%lld Staffel", "%lld Staffeln"), "fr": ("%lld saison", "%lld saisons"),
        "pt-PT": ("%lld temporada", "%lld temporadas"), "pl": ("%lld sezon", "%lld sezony", "%lld sezonów")},
}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def plural(forms, language):
    if language == "pl":
        one, few, many = forms
        cases = {"one": one, "few": few, "many": many, "other": few}
    else:
        one, other = forms
        cases = {"one": one, "other": other}
    return {"variations": {"plural": {k: unit(v) for k, v in cases.items()}}}


def main():
    strings = {}
    for table in (PLAIN, FORMATS):
        for key, values in table.items():
            assert len(values) == len(LANGUAGES), key
            strings[key] = {"localizations": {lang: unit(v) for lang, v in zip(LANGUAGES, values)}}
    for key, languages in PLURALS.items():
        strings[key] = {"localizations": {lang: plural(forms, lang) for lang, forms in languages.items()}}
    # Tab names keep their English default too, since the key isn't the text.
    for key, english in {"tab.browse": "Browse", "tab.sports": "Sports"}.items():
        strings[key]["localizations"]["en"] = unit(english)

    catalog = {"sourceLanguage": "en", "version": "1.0", "strings": dict(sorted(strings.items()))}
    path = os.path.join(os.path.dirname(__file__), "..", "Resources", "Localizable.xcstrings")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("Wrote {} strings to Resources/Localizable.xcstrings".format(len(strings)))


if __name__ == "__main__":
    main()
