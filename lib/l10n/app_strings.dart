/// Custom i18n (cs / en / de) — no generated ARB catalog.
class AppStrings {
  AppStrings(this.locale) : _table = _tables[locale] ?? _tables['en']!;

  final String locale;
  final Map<String, String> _table;

  static const supported = ['cs', 'en', 'de'];

  static const keys = [
    'appName',
    'catalogTitle',
    'catalogEmpty',
    'catalogEmptyHint',
    'signIn',
    'signUp',
    'email',
    'password',
    'signOut',
    'free',
    'paid',
    'unlock',
    'unlockWithStripe',
    'openChallenge',
    'storyChallenge',
    'waypoints',
    'locked',
    'completed',
    'verify',
    'takePhoto',
    'photoRequired',
    'uploading',
    'verified',
    'routePlanner',
    'hike',
    'bike',
    'distance',
    'elevation',
    'time',
    'difficulty',
    'openInOsm',
    'diplomaHeadlineDefault',
    'congratulations',
    'language',
    'settings',
    'easy',
    'moderate',
    'hard',
    'expert',
    'challengeLockedPaid',
    'storyLockedHint',
    'missingConfig',
    'errorGeneric',
    'purchasePending',
    'retry',
    'cameraDenied',
    'noAccount',
    'haveAccount',
    'displayName',
    'promoFallbackCta',
    'needAccess',
    'liveCameraOnly',
    'viewDiploma',
    'priceLabel',
    'registerAction',
    'registerTitle',
    'backToSignIn',
    'confirmEmailTitle',
    'confirmEmailBody',
    'otpCode',
    'verifyOtp',
    'enterAfterConfirm',
    'navLastChallenge',
    'navMap',
    'navProfile',
    'lastChallengeEmpty',
    'lastChallengeEmptyHint',
    'lastChallengeMissing',
    'lastChallengeBrowse',
    'mapEmpty',
    'mapEmptyHint',
    'routeStart',
    'routeStartHint',
    'routeSearch',
    'routeUseGps',
    'routeCustomPlace',
    'routePlacesInChallenge',
    'routeFromPlace',
    'routeDestination',
    'routeChoosePlace',
    'routeNeedTwoPoints',
    'routeLoadFailed',
    'routeGpsFailed',
    'routeGpsDenied',
    'routePlaceNotFound',
    'routeWalking',
    'routeCycling',
    'routeSamePoint',
  ];

  String t(String key) => _table[key] ?? _tables['en']![key] ?? key;

  String get appName => t('appName');
  String get catalogTitle => t('catalogTitle');
  String get catalogEmpty => t('catalogEmpty');
  String get catalogEmptyHint => t('catalogEmptyHint');
  String get signIn => t('signIn');
  String get signUp => t('signUp');
  String get email => t('email');
  String get password => t('password');
  String get signOut => t('signOut');
  String get free => t('free');
  String get paid => t('paid');
  String get unlock => t('unlock');
  String get unlockWithStripe => t('unlockWithStripe');
  String get openChallenge => t('openChallenge');
  String get storyChallenge => t('storyChallenge');
  String get waypoints => t('waypoints');
  String get locked => t('locked');
  String get completed => t('completed');
  String get verify => t('verify');
  String get takePhoto => t('takePhoto');
  String get photoRequired => t('photoRequired');
  String get uploading => t('uploading');
  String get verified => t('verified');
  String get routePlanner => t('routePlanner');
  String get hike => t('hike');
  String get bike => t('bike');
  String get distance => t('distance');
  String get elevation => t('elevation');
  String get time => t('time');
  String get difficulty => t('difficulty');
  String get openInOsm => t('openInOsm');
  String get diplomaHeadlineDefault => t('diplomaHeadlineDefault');
  String get congratulations => t('congratulations');
  String get language => t('language');
  String get settings => t('settings');
  String get easy => t('easy');
  String get moderate => t('moderate');
  String get hard => t('hard');
  String get expert => t('expert');
  String get challengeLockedPaid => t('challengeLockedPaid');
  String get storyLockedHint => t('storyLockedHint');
  String get missingConfig => t('missingConfig');
  String get errorGeneric => t('errorGeneric');
  String get purchasePending => t('purchasePending');
  String get retry => t('retry');
  String get cameraDenied => t('cameraDenied');
  String get noAccount => t('noAccount');
  String get haveAccount => t('haveAccount');
  String get displayName => t('displayName');
  String get promoFallbackCta => t('promoFallbackCta');
  String get needAccess => t('needAccess');
  String get liveCameraOnly => t('liveCameraOnly');
  String get viewDiploma => t('viewDiploma');
  String get priceLabel => t('priceLabel');
  String get registerAction => t('registerAction');
  String get registerTitle => t('registerTitle');
  String get backToSignIn => t('backToSignIn');
  String get confirmEmailTitle => t('confirmEmailTitle');
  String get confirmEmailBody => t('confirmEmailBody');
  String get otpCode => t('otpCode');
  String get verifyOtp => t('verifyOtp');
  String get enterAfterConfirm => t('enterAfterConfirm');
  String get navLastChallenge => t('navLastChallenge');
  String get navMap => t('navMap');
  String get navProfile => t('navProfile');
  String get lastChallengeEmpty => t('lastChallengeEmpty');
  String get lastChallengeEmptyHint => t('lastChallengeEmptyHint');
  String get lastChallengeMissing => t('lastChallengeMissing');
  String get lastChallengeBrowse => t('lastChallengeBrowse');
  String get mapEmpty => t('mapEmpty');
  String get mapEmptyHint => t('mapEmptyHint');
  String get routeStart => t('routeStart');
  String get routeStartHint => t('routeStartHint');
  String get routeSearch => t('routeSearch');
  String get routeUseGps => t('routeUseGps');
  String get routeCustomPlace => t('routeCustomPlace');
  String get routePlacesInChallenge => t('routePlacesInChallenge');
  String get routeFromPlace => t('routeFromPlace');
  String get routeDestination => t('routeDestination');
  String get routeChoosePlace => t('routeChoosePlace');
  String get routeNeedTwoPoints => t('routeNeedTwoPoints');
  String get routeLoadFailed => t('routeLoadFailed');
  String get routeGpsFailed => t('routeGpsFailed');
  String get routeGpsDenied => t('routeGpsDenied');
  String get routePlaceNotFound => t('routePlaceNotFound');
  String get routeWalking => t('routeWalking');
  String get routeCycling => t('routeCycling');
  String get routeSamePoint => t('routeSamePoint');

  String difficultyLabel(String name) => t(name);

  static const _tables = <String, Map<String, String>>{
    'en': {
      'appName': 'Viateria',
      'catalogTitle': 'Challenges',
      'catalogEmpty': 'No published challenges yet.',
      'catalogEmptyHint':
          'Content lives in Supabase CMS. Publish a challenge to see it here.',
      'signIn': 'Sign in',
      'signUp': 'Create account',
      'email': 'Email',
      'password': 'Password',
      'signOut': 'Sign out',
      'free': 'Free',
      'paid': 'Paid',
      'unlock': 'Start',
      'unlockWithStripe': 'Unlock with Stripe',
      'openChallenge': 'Open',
      'storyChallenge': 'Story',
      'waypoints': 'Waypoints',
      'locked': 'Locked',
      'completed': 'Completed',
      'verify': 'Verify waypoint',
      'takePhoto': 'Take live photo',
      'photoRequired': 'A live camera photo is required to verify.',
      'uploading': 'Uploading…',
      'verified': 'Verified',
      'routePlanner': 'Route planner',
      'hike': 'Hike',
      'bike': 'Bike',
      'distance': 'Distance',
      'elevation': 'Elevation',
      'time': 'Time',
      'difficulty': 'Difficulty',
      'openInOsm': 'Open in OpenStreetMap',
      'diplomaHeadlineDefault': 'Certificate of completion',
      'congratulations': 'You completed this challenge!',
      'language': 'Language',
      'settings': 'Settings',
      'easy': 'Easy',
      'moderate': 'Moderate',
      'hard': 'Hard',
      'expert': 'Expert',
      'challengeLockedPaid': 'Purchase this challenge to access waypoints.',
      'storyLockedHint': 'Complete the previous waypoint to unlock the next.',
      'missingConfig': 'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY via env.',
      'errorGeneric': 'Something went wrong. Please try again.',
      'purchasePending': 'Payment is still pending.',
      'retry': 'Retry',
      'cameraDenied': 'Camera permission is required for verification.',
      'noAccount': 'Need an account? Sign up',
      'haveAccount': 'Already registered? Sign in',
      'displayName': 'Display name',
      'promoFallbackCta': 'Learn more',
      'needAccess': 'Unlock this challenge to continue.',
      'liveCameraOnly': 'Gallery photos are not accepted.',
      'viewDiploma': 'View diploma',
      'priceLabel': 'Price',
      'registerAction': 'Sign up',
      'registerTitle': 'Create account',
      'backToSignIn': 'Back to sign in',
      'confirmEmailTitle': 'Confirm your email',
      'confirmEmailBody': 'Open the email we sent and enter the 6-digit code. After you confirm, you can enter the app.',
      'otpCode': '6-digit code',
      'verifyOtp': 'Verify code',
      'enterAfterConfirm': "I've confirmed — enter the app",
      'navLastChallenge': 'Last challenge',
      'navMap': 'Map',
      'navProfile': 'Profile',
      'lastChallengeEmpty': 'You have not opened a challenge yet.',
      'lastChallengeEmptyHint': 'Open a challenge from the catalog or the map and it will show up here.',
      'lastChallengeMissing': 'That challenge is no longer available.',
      'lastChallengeBrowse': 'Browse challenges',
      'mapEmpty': 'No published challenges to show on the map.',
      'mapEmptyHint':
          'When challenges have waypoint coordinates, they will appear here.',
      'routeStart': 'Start',
      'routeStartHint': 'Address, place, or lat, lng',
      'routeSearch': 'Search',
      'routeUseGps': 'Use my location',
      'routeCustomPlace': 'Enter a custom place',
      'routePlacesInChallenge': 'Places in this challenge',
      'routeFromPlace': 'Place from this challenge',
      'routeDestination': 'Destination',
      'routeChoosePlace': 'Choose a place',
      'routeNeedTwoPoints':
          'Choose a start and a destination to see walking and cycling routes.',
      'routeLoadFailed': 'Could not load the route.',
      'routeGpsFailed': 'Could not read your location.',
      'routeGpsDenied': 'Location permission was denied.',
      'routePlaceNotFound': 'That place was not found.',
      'routeWalking': 'Walking route',
      'routeCycling': 'Cycling route',
      'routeSamePoint': 'Start and destination must be different.',
    },
    'cs': {
      'appName': 'Viateria',
      'catalogTitle': 'Výzvy',
      'catalogEmpty': 'Zatím žádné zveřejněné výzvy.',
      'catalogEmptyHint':
          'Obsah žije v Supabase CMS. Zveřejněte výzvu, aby se zde objevila.',
      'signIn': 'Přihlásit se',
      'signUp': 'Vytvořit účet',
      'email': 'E-mail',
      'password': 'Heslo',
      'signOut': 'Odhlásit se',
      'free': 'Zdarma',
      'paid': 'Placené',
      'unlock': 'Začít',
      'unlockWithStripe': 'Odemknout přes Stripe',
      'openChallenge': 'Otevřená',
      'storyChallenge': 'Příběh',
      'waypoints': 'Zastávky',
      'locked': 'Zamčeno',
      'completed': 'Dokončeno',
      'verify': 'Ověřit zastávku',
      'takePhoto': 'Pořídit živou fotku',
      'photoRequired': 'K ověření je nutná živá fotka z fotoaparátu.',
      'uploading': 'Nahrávám…',
      'verified': 'Ověřeno',
      'routePlanner': 'Plánovač trasy',
      'hike': 'Pěšky',
      'bike': 'Kolo',
      'distance': 'Vzdálenost',
      'elevation': 'Převýšení',
      'time': 'Čas',
      'difficulty': 'Obtížnost',
      'openInOsm': 'Otevřít v OpenStreetMap',
      'diplomaHeadlineDefault': 'Diplom za dokončení',
      'congratulations': 'Tuto výzvu jste dokončili!',
      'language': 'Jazyk',
      'settings': 'Nastavení',
      'easy': 'Lehká',
      'moderate': 'Střední',
      'hard': 'Těžká',
      'expert': 'Expert',
      'challengeLockedPaid': 'Pro přístup k zastávkám výzvu zakupte.',
      'storyLockedHint': 'Další zastávku odemknete dokončením předchozí.',
      'missingConfig': 'Supabase není nastavené. Doplňte SUPABASE_URL a SUPABASE_ANON_KEY v env.',
      'errorGeneric': 'Něco se pokazilo. Zkuste to znovu.',
      'purchasePending': 'Platba ještě není dokončená.',
      'retry': 'Zkusit znovu',
      'cameraDenied': 'Pro ověření je potřeba oprávnění k fotoaparátu.',
      'noAccount': 'Nemáte účet? Registrace',
      'haveAccount': 'Už máte účet? Přihlášení',
      'displayName': 'Zobrazované jméno',
      'promoFallbackCta': 'Zjistit více',
      'needAccess': 'Pro pokračování výzvu odemkněte.',
      'liveCameraOnly': 'Fotky z galerie se nepřijímají.',
      'viewDiploma': 'Zobrazit diplom',
      'priceLabel': 'Cena',
      'registerAction': 'Zaregistrovat se',
      'registerTitle': 'Registrace',
      'backToSignIn': 'Zpět k přihlášení',
      'confirmEmailTitle': 'Potvrďte e-mail',
      'confirmEmailBody': 'Otevřete e-mail a zadejte 6místný kód. Až účet potvrdíte, můžete vstoupit do aplikace.',
      'otpCode': '6místný kód',
      'verifyOtp': 'Potvrdit kód',
      'enterAfterConfirm': 'E-mail jsem potvrdil(a) — vstoupit',
      'navLastChallenge': 'Poslední výzva',
      'navMap': 'Mapa',
      'navProfile': 'Profil',
      'lastChallengeEmpty': 'Zatím jste neotevřeli žádnou výzvu.',
      'lastChallengeEmptyHint':
          'Otevřete výzvu v katalogu nebo na mapě a objeví se tady.',
      'lastChallengeMissing': 'Poslední výzva už není dostupná.',
      'lastChallengeBrowse': 'Procházet výzvy',
      'mapEmpty': 'Žádné zveřejněné výzvy k zobrazení na mapě.',
      'mapEmptyHint': 'Až budou u výzev souřadnice zastávek, objeví se tady.',
      'routeStart': 'Start',
      'routeStartHint': 'Adresa, místo nebo souřadnice',
      'routeSearch': 'Hledat',
      'routeUseGps': 'Použít moji polohu',
      'routeCustomPlace': 'Zadat vlastní místo',
      'routePlacesInChallenge': 'Místa ve výzvě',
      'routeFromPlace': 'Místo z této výzvy',
      'routeDestination': 'Cíl',
      'routeChoosePlace': 'Vyberte místo',
      'routeNeedTwoPoints':
          'Zvolte start a cíl, abyste viděli pěší a cyklistickou trasu.',
      'routeLoadFailed': 'Trasu se nepodařilo načíst.',
      'routeGpsFailed': 'Polohu se nepodařilo zjistit.',
      'routeGpsDenied': 'Přístup k poloze byl odepřen.',
      'routePlaceNotFound': 'Místo se nenašlo.',
      'routeWalking': 'Pěší trasa',
      'routeCycling': 'Cyklistická trasa',
      'routeSamePoint': 'Start a cíl musí být různé.',
    },
    'de': {
      'appName': 'Viateria',
      'catalogTitle': 'Challenges',
      'catalogEmpty': 'Noch keine veröffentlichten Challenges.',
      'catalogEmptyHint':
          'Inhalte liegen im Supabase-CMS. Veröffentlichen Sie eine Challenge.',
      'signIn': 'Anmelden',
      'signUp': 'Konto erstellen',
      'email': 'E-Mail',
      'password': 'Passwort',
      'signOut': 'Abmelden',
      'free': 'Kostenlos',
      'paid': 'Kostenpflichtig',
      'unlock': 'Starten',
      'unlockWithStripe': 'Mit Stripe freischalten',
      'openChallenge': 'Offen',
      'storyChallenge': 'Geschichte',
      'waypoints': 'Wegpunkte',
      'locked': 'Gesperrt',
      'completed': 'Abgeschlossen',
      'verify': 'Wegpunkt prüfen',
      'takePhoto': 'Live-Foto aufnehmen',
      'photoRequired': 'Zur Prüfung ist ein Live-Kamerafoto erforderlich.',
      'uploading': 'Wird hochgeladen…',
      'verified': 'Geprüft',
      'routePlanner': 'Routenplaner',
      'hike': 'Wandern',
      'bike': 'Rad',
      'distance': 'Distanz',
      'elevation': 'Höhenmeter',
      'time': 'Zeit',
      'difficulty': 'Schwierigkeit',
      'openInOsm': 'In OpenStreetMap öffnen',
      'diplomaHeadlineDefault': 'Abschlussdiplom',
      'congratulations': 'Sie haben diese Challenge abgeschlossen!',
      'language': 'Sprache',
      'settings': 'Einstellungen',
      'easy': 'Leicht',
      'moderate': 'Mittel',
      'hard': 'Schwer',
      'expert': 'Experte',
      'challengeLockedPaid':
          'Kaufen Sie diese Challenge, um Wegpunkte zu sehen.',
      'storyLockedHint': 'Schließen Sie den vorherigen Wegpunkt ab, um den nächsten zu öffnen.',
      'missingConfig': 'Supabase ist nicht konfiguriert. Setzen Sie SUPABASE_URL und SUPABASE_ANON_KEY per Env.',
      'errorGeneric': 'Etwas ist schiefgelaufen. Bitte erneut versuchen.',
      'purchasePending': 'Zahlung steht noch aus.',
      'retry': 'Erneut versuchen',
      'cameraDenied': 'Für die Prüfung ist die Kameraberechtigung nötig.',
      'noAccount': 'Noch kein Konto? Registrieren',
      'haveAccount': 'Bereits registriert? Anmelden',
      'displayName': 'Anzeigename',
      'promoFallbackCta': 'Mehr erfahren',
      'needAccess': 'Schalten Sie diese Challenge frei, um fortzufahren.',
      'liveCameraOnly': 'Galerie-Fotos werden nicht akzeptiert.',
      'viewDiploma': 'Diplom ansehen',
      'priceLabel': 'Preis',
      'registerAction': 'Registrieren',
      'registerTitle': 'Konto erstellen',
      'backToSignIn': 'Zurück zur Anmeldung',
      'confirmEmailTitle': 'E-Mail bestätigen',
      'confirmEmailBody': 'Öffnen Sie die E-Mail und geben Sie den 6-stelligen Code ein. Nach der Bestätigung können Sie die App nutzen.',
      'otpCode': '6-stelliger Code',
      'verifyOtp': 'Code bestätigen',
      'enterAfterConfirm': 'Bestätigt — App öffnen',
      'navLastChallenge': 'Letzte Challenge',
      'navMap': 'Karte',
      'navProfile': 'Profil',
      'lastChallengeEmpty': 'Sie haben noch keine Challenge geöffnet.',
      'lastChallengeEmptyHint': 'Öffnen Sie eine Challenge im Katalog oder auf der Karte, dann finden Sie sie hier.',
      'lastChallengeMissing': 'Die letzte Challenge ist nicht mehr verfügbar.',
      'lastChallengeBrowse': 'Challenges ansehen',
      'mapEmpty': 'Keine veröffentlichten Challenges auf der Karte.',
      'mapEmptyHint':
          'Sobald Wegpunkte Koordinaten haben, erscheinen sie hier.',
      'routeStart': 'Start',
      'routeStartHint': 'Adresse, Ort oder Koordinaten',
      'routeSearch': 'Suchen',
      'routeUseGps': 'Meinen Standort verwenden',
      'routeCustomPlace': 'Eigenen Ort eingeben',
      'routePlacesInChallenge': 'Orte in dieser Challenge',
      'routeFromPlace': 'Ort aus dieser Challenge',
      'routeDestination': 'Ziel',
      'routeChoosePlace': 'Ort wählen',
      'routeNeedTwoPoints':
          'Wählen Sie Start und Ziel, um Fuß- und Radrouten zu sehen.',
      'routeLoadFailed': 'Die Route konnte nicht geladen werden.',
      'routeGpsFailed': 'Standort konnte nicht ermittelt werden.',
      'routeGpsDenied': 'Standortberechtigung wurde verweigert.',
      'routePlaceNotFound': 'Ort wurde nicht gefunden.',
      'routeWalking': 'Fußweg',
      'routeCycling': 'Radweg',
      'routeSamePoint': 'Start und Ziel müssen unterschiedlich sein.',
    },
  };
}
