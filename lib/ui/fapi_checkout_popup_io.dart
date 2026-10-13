/// VM / mobile stub. Popups are a Flutter-web fallback only.
({double width, double height}) readFapiScreenSize() =>
    (width: 1280, height: 800);

bool openCenteredFapiPopup(String url, String features) => false;

void closeFapiPopup() {}
