// SPDX-FileCopyrightText: 2024 Carl Schwan <carl@carlschwan.eu>
// SPDX-FileCopyrightText: 2024 Gary Wang <opensource@blumia.net>
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

import org.kde.marknote

FormCard.FormCardPage {
    title: i18nc("@title:window", "General")

    FormCard.FormHeader {
        title: i18n("General theme")
    }

    FormCard.FormCard {
        FormCard.FormComboBoxDelegate {
            id: root

            text: i18n("Color theme")
            textRole: "display"
            valueRole: "display"
            model: ColorSchemer.model
            Component.onCompleted: currentIndex = ColorSchemer.indexForScheme(Config.colorScheme)
            onCurrentValueChanged: {
                ColorSchemer.apply(currentIndex);
                Config.colorScheme = ColorSchemer.nameForIndex(currentIndex);
                Config.save();
            }
        }
    }

    FormCard.FormHeader {
        title: i18n("AI Settings")
    }

    Item {
        id: aiEndpointsContainer
        Layout.fillWidth: true
        implicitHeight: childrenRect.height

        function getEndpoints() {
            try {
                return JSON.parse(Config.aiEndpoints || "[]");
            } catch(e) {
                return [];
            }
        }

        function saveEndpoints(newEndpoints) {
            Config.aiEndpoints = JSON.stringify(newEndpoints);
            Config.save();
        }

        ColumnLayout {
            width: parent.width

            Repeater {
                model: aiEndpointsContainer.getEndpoints()
                delegate: ColumnLayout {
                    Layout.fillWidth: true

                    FormCard.FormCard {
                        Layout.fillWidth: true

                        property int endpointIndex: index

                        FormCard.FormTextFieldDelegate {
                            label: i18n("Name (Optional):")
                            text: modelData.name || ""
                            onEditingFinished: {
                                let newEndpoints = aiEndpointsContainer.getEndpoints();
                                newEndpoints[endpointIndex].name = text;
                                aiEndpointsContainer.saveEndpoints(newEndpoints);
                            }
                        }

                        FormCard.FormTextFieldDelegate {
                            label: i18n("URL:")
                            text: modelData.url || ""
                            placeholderText: "http://localhost:11434"
                            onEditingFinished: {
                                let newEndpoints = aiEndpointsContainer.getEndpoints();
                                newEndpoints[endpointIndex].url = text;
                                aiEndpointsContainer.saveEndpoints(newEndpoints);
                            }
                        }

                        FormCard.FormComboBoxDelegate {
                            label: i18n("Type:")
                            model: ["ollama"]
                            currentIndex: modelData.type === "ollama" ? 0 : 0
                            onActivated: {
                                let newEndpoints = aiEndpointsContainer.getEndpoints();
                                newEndpoints[endpointIndex].type = model[currentIndex];
                                aiEndpointsContainer.saveEndpoints(newEndpoints);
                            }
                        }

                        FormCard.FormButtonDelegate {
                            text: i18n("Remove Endpoint")
                            icon.name: "list-remove"
                            onClicked: {
                                let newEndpoints = aiEndpointsContainer.getEndpoints();
                                newEndpoints.splice(endpointIndex, 1);
                                aiEndpointsContainer.saveEndpoints(newEndpoints);
                            }
                        }
                    }
                }
            }

            FormCard.FormCard {
                Layout.fillWidth: true
                FormCard.FormButtonDelegate {
                    text: i18n("Add AI Endpoint")
                    icon.name: "list-add"
                    onClicked: {
                        let newEndpoints = aiEndpointsContainer.getEndpoints();
                        newEndpoints.push({name: "", url: "", type: "ollama"});
                        aiEndpointsContainer.saveEndpoints(newEndpoints);
                    }
                }
            }
        }
    }

    FormCard.FormHeader {
        title: i18n("Editor Settings")
    }

    FormCard.FormCard {
        FormCard.FormFolderDelegate {
            id: notesFolderDelegate
            label: i18nc("@label:textbox", "Notes Directory:")
            enabled: !Config.isStorageImmutable

            currentFolder: Config.storage || StandardPaths.writableLocation(StandardPaths.DocumentsLocation)

            onAccepted: {
                Config.storage = selectedFolder.toString().replace("file://", "");
                console.log(Config.storage);
                Config.save();
            }
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormCard {
            FormCard.FormComboBoxDelegate {
                id: fontFamilyComboBox
                text: i18nc("@label:spinbox", "Font family:")
                enabled: !Config.isEditorFontImmutable

                model: appFontList

                Component.onCompleted: currentIndex = indexOfValue(Config.editorFont.family)

                onActivated: (index) => {
                    if (index < 0) return;

                    var tempFont = Config.editorFont;
                    tempFont.family = currentValue;
                    Config.editorFont = tempFont;
                    Config.save();
                }
            }
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormSpinBoxDelegate {
            id: fontSizeSpinbox
            from: 6
            to: 32
            value: Config.editorFont.pixelSize
            label: i18nc("@label:spinbox", "Font size:")
            enabled: !Config.isEditorFontImmutable
            onValueChanged: {
                Config.editorFont.pixelSize = value;
                Config.save();
            }

            Connections {
                target: Config
                function onEditorFontChanged() {
                    fontSizeSpinbox.value = Config.editorFont.pixelSize;
                }
            }
        }
    }
}
