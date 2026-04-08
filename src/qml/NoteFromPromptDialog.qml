// SPDX-FileCopyrightText: 2026 Valentyn Bondarenko <bondarenko@vivaldi.net>
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.marknote
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.ki18n

FormCard.FormCardDialog {
    id: root

    property alias name: nameInput.text
    property alias prompt: promptInput.text
    required property string notebookPath

    title: KI18n.i18nc("@title:window", "New Note from Prompt")
    standardButtons: Controls.Dialog.Save | Controls.Dialog.Cancel

    property var modelsList: []
    property bool isGenerating: false

    NotesModel {
        id: notesModel
        path: root.notebookPath
    }

    onOpened: {
        nameInput.forceActiveFocus()
        checkSaveButton()
        fetchModels()
    }

    onRejected: {
        if (!isGenerating) {
            root.close();
        }
    }

    onClosed: {
        name = "";
        prompt = "";
        modelsList = [];
    }

    function checkSaveButton() {
        if (!isGenerating && nameInput.text.length > 0 && promptInput.text.length > 0 && modelComboBox.currentIndex >= 0) {
            root.standardButton(Controls.Dialog.Save).enabled = true;
        } else {
            root.standardButton(Controls.Dialog.Save).enabled = false;
        }
    }

    function fetchModels() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://localhost:11434/api/tags", true);
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
                    }
                } else {
                    console.error("Failed to fetch models, status:", xhr.status);
                }
                checkSaveButton();
            }
        };
        xhr.send();
    }

    onAccepted: {
        if (nameInput.text.length === 0 || promptInput.text.length === 0 || modelComboBox.currentIndex < 0 || root.modelsList.length === 0) {
            return;
        }

        root.isGenerating = true;
        checkSaveButton();

        var selectedModel = root.modelsList[modelComboBox.currentIndex];
        var promptText = promptInput.text;
        var noteName = root.name;

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://localhost:11434/api/generate", true);
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
                    } catch(e) {
                        console.error("Error parsing generate response:", e);
                    }
                } else {
                    console.error("Failed to generate, status:", xhr.status);
                }
                root.close();
            }
        };
        var data = JSON.stringify({
            "model": selectedModel,
            "prompt": promptText,
            "stream": false
        });
        xhr.send(data);
    }

    FormCard.FormTextFieldDelegate {
        id: nameInput
        label: KI18n.i18nc("@label:textbox Note name", "Name:")
        validator: RegularExpressionValidator {
            regularExpression: /^[^./\\][^/\\]*$/
        }
        onTextChanged: checkSaveButton()
        enabled: !root.isGenerating
    }

    FormCard.FormComboBoxDelegate {
        id: modelComboBox
        textRole: ""
        model: root.modelsList
        label: KI18n.i18nc("@label:combobox Model", "Model:")
        onCurrentIndexChanged: checkSaveButton()
        enabled: !root.isGenerating
    }

    FormCard.FormTextAreaDelegate {
        id: promptInput
        label: KI18n.i18nc("@label:textarea Prompt", "Prompt:")
        onTextChanged: checkSaveButton()
        enabled: !root.isGenerating
    }
}
