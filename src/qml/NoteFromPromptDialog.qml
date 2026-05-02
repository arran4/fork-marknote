// SPDX-FileCopyrightText: 2026 Valentyn Bondarenko <bondarenko@vivaldi.net>
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.marknote
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

FormCard.FormCardDialog {
    id: root

    property alias name: nameInput.text
    property alias prompt: promptInput.text
    required property string notebookPath

    title: i18nc("@title:window", "New Note from Prompt")
    standardButtons: Controls.Dialog.NoButton

    property var modelsList: []
    property bool isGenerating: false
    property var aiEndpoints: []

    NotesModel {
        id: notesModel
        path: root.notebookPath
    }

    customFooterActions: [
        Kirigami.Action {
            text: i18n("Cancel")
            icon.name: "dialog-cancel"
            enabled: !root.isGenerating
            onTriggered: {
                root.close();
            }
        },
        Kirigami.Action {
            id: generateAction
            text: root.isGenerating ? i18n("Generating...") : i18n("Save")
            icon.name: "document-save"
            enabled: !root.isGenerating && nameInput.text.length > 0 && promptInput.text.length > 0 && modelComboBox.currentIndex >= 0 && endpointComboBox.currentIndex >= 0
            onTriggered: {
                root.generateNote();
            }
        }
    ]

    onOpened: {
        try {
            root.aiEndpoints = JSON.parse(Config.aiEndpoints || "[]");
        } catch(e) {
            root.aiEndpoints = [];
        }

        nameInput.forceActiveFocus()

        if (root.aiEndpoints.length > 0) {
            endpointComboBox.currentIndex = 0;
            fetchModels();
        }
    }

    onClosed: {
        name = "";
        prompt = "";
        modelsList = [];
        root.destroy();
    }

    function fetchModels() {
        if (endpointComboBox.currentIndex < 0 || root.aiEndpoints.length === 0) {
            root.modelsList = [];
            return;
        }

        var endpoint = root.aiEndpoints[endpointComboBox.currentIndex];
        if (endpoint.type !== "ollama") {
            root.modelsList = [];
            return;
        }

        var url = endpoint.url;
        if (!url.endsWith("/")) {
            url += "/";
        }

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url + "api/tags", true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var models = response.models || [];
                        var modelNames = [];
                        for (var i = 0; i < models.length; i++) {
                            modelNames.push(models[i].name);
                        }
                        root.modelsList = modelNames;
                        if (modelNames.length > 0) {
                            modelComboBox.currentIndex = 0;
                        } else {
                            modelComboBox.currentIndex = -1;
                        }
                    } catch(e) {
                        console.error("Error parsing models:", e);
                        root.modelsList = [];
                    }
                } else {
                    console.error("Failed to fetch models, status:", xhr.status);
                    root.modelsList = [];
                }
            }
        };
        xhr.send();
    }

    function generateNote() {
        if (nameInput.text.length === 0 || promptInput.text.length === 0 || modelComboBox.currentIndex < 0 || root.modelsList.length === 0 || endpointComboBox.currentIndex < 0) {
            return;
        }

        root.isGenerating = true;

        var endpoint = root.aiEndpoints[endpointComboBox.currentIndex];
        var selectedModel = root.modelsList[modelComboBox.currentIndex];
        var promptText = promptInput.text;
        var noteName = root.name;

        if (endpoint.type === "ollama") {
            var url = endpoint.url;
            if (!url.endsWith("/")) {
                url += "/";
            }

            var xhr = new XMLHttpRequest();
            xhr.open("POST", url + "api/generate", true);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    root.isGenerating = false;
                    if (xhr.status === 200) {
                        try {
                            var response = JSON.parse(xhr.responseText);
                            var generatedText = response.response || "";

                            notesModel.addNoteWithContent(noteName, generatedText);
                            NavigationController.notePath = noteName + '.md';
                            root.close();
                        } catch(e) {
                            console.error("Error parsing generate response:", e);
                            Kirigami.applicationWindow().showPassiveNotification(i18n("Error parsing response from AI endpoint."), "short");
                        }
                    } else {
                        console.error("Failed to generate, status:", xhr.status);
                        Kirigami.applicationWindow().showPassiveNotification(i18n("Failed to generate note from AI endpoint. Check network or endpoint configuration."), "short");
                    }
                }
            };
            var data = JSON.stringify({
                "model": selectedModel,
                "prompt": promptText,
                "stream": false
            });
            xhr.send(data);
        } else {
            root.isGenerating = false;
            console.error("Unsupported endpoint type:", endpoint.type);
            Kirigami.applicationWindow().showPassiveNotification(i18n("Unsupported AI endpoint type."), "short");
        }
    }

    FormCard.FormComboBoxDelegate {
        id: endpointComboBox
        textRole: ""
        model: root.aiEndpoints.map(e => e.name ? e.name + " (" + e.url + ")" : e.url)
        label: i18nc("@label:combobox API Endpoint", "Endpoint:")
        onCurrentIndexChanged: {
            fetchModels();
        }
        enabled: !root.isGenerating
    }

    FormCard.FormTextFieldDelegate {
        id: nameInput
        label: i18nc("@label:textbox Note name", "Name:")
        validator: RegularExpressionValidator {
            regularExpression: /^[^./\\][^/\\]*$/
        }
        enabled: !root.isGenerating
    }

    FormCard.FormComboBoxDelegate {
        id: modelComboBox
        textRole: ""
        model: root.modelsList
        label: i18nc("@label:combobox Model", "Model:")
        enabled: !root.isGenerating
    }

    FormCard.FormTextAreaDelegate {
        id: promptInput
        label: i18nc("@label:textarea Prompt", "Prompt:")
        enabled: !root.isGenerating
    }
}
