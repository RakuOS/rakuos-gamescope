var panel = new Panel
var panelScreen = panel.screen

panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2)

const maximumAspectRatio = 21/9;
if (panel.formFactor === "horizontal") {
    const geo = screenGeometry(panelScreen);
    const maximumWidth = Math.ceil(geo.height * maximumAspectRatio);
    if (geo.width > maximumWidth) {
        panel.alignment = "center";
        panel.minimumLength = maximumWidth;
        panel.maximumLength = maximumWidth;
    }
}

var kickoff = panel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "/usr/share/pixmaps/rakuos-logo-outline.svg");

panel.addWidget("org.kde.plasma.pager");
panel.addWidget("org.kde.plasma.icontasks");
panel.addWidget("org.kde.plasma.marginsseparator");

var langIds = ["as","bn","bo","brx","doi","gu","hi","ja","kn","ko","kok","ks",
               "lep","mai","ml","mni","mr","ne","or","pa","sa","sat","sd","si",
               "ta","te","th","ur","vi","zh_CN","zh_TW"];
if (langIds.indexOf(languageId) !== -1) {
    panel.addWidget("org.kde.plasma.kimpanel");
}

panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
panel.addWidget("org.kde.plasma.showdesktop");

const allPanels = panels();
for (let i = 0; i < allPanels.length; i++) {
    const widgets = allPanels[i].widgets();
    for (let j = 0; j < widgets.length; j++) {
        if (widgets[j].type === "org.kde.plasma.icontasks") {
            widgets[j].currentConfigGroup = ["General"];
            const currentLaunchers = widgets[j].readConfig("launchers", "");
            if (!currentLaunchers || currentLaunchers.trim() === "") {
                widgets[j].writeConfig("launchers", [
                    "preferred://browser",
                    "preferred://filemanager",
                    "applications:systemsettings.desktop",
                ]);
                widgets[j].reloadConfig();
            }
        }
    }
}
