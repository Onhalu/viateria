var app = "com.viateria.viateria://vandery-plus?vandery_plus=return";
var lang = (navigator.language || "cs").toLowerCase().slice(0, 2);
var copy = {
  cs: ["Platba odeslána. Vrať se do aplikace VANDERY.", "Otevřít aplikaci", "Pokračovat na webu"],
  en: ["Payment sent. Return to the VANDERY app.", "Open the app", "Continue on the web"],
  de: ["Zahlung gesendet. Kehre zur VANDERY-App zurück.", "App öffnen", "Im Web fortfahren"]
};
var row = copy[lang] || copy.cs;
document.getElementById("lead").textContent = row[0];
document.getElementById("open").textContent = row[1];
document.getElementById("web").textContent = row[2];
location.replace(app);
