import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Quickshell 1.0
import Quickshell.Io 1.0

Popup {
    id: root
    width: 560
    height: 420
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    property var matches: []
    property string query: ""

    function refreshResults() {
        query = searchField.text.trim();
        if (query.length === 0) {
            matches = [];
            return;
        }

        backend.command = [
            "python3",
            "search.py",
            "--query", query,
            "--sort", "alpha",
            "--limit", "20"
        ];
        backend.start();
    }

    Process {
        id: backend
        running: false
        onExited: {
            if (backend.exitCode !== 0) {
                statusText.text = "Lookup failed";
                return;
            }

            try {
                const payload = JSON.parse(backend.stdout.readAll());
                matches = payload.results || [];
                statusText.text = payload.count ? "Found " + payload.count + " matches" : "No matches";
            } catch (error) {
                statusText.text = "Could not parse search output";
            }
        }
    }

    background: Rectangle {
        color: "#1f2430"
        border.color: "#5ccfe6"
        border.width: 1
        radius: 12
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Label {
            text: "Lexicon"
            font.bold: true
            font.pixelSize: 22
            color: "#f8f8f2"
        }

        TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: "Search word pattern…"
            onTextEdited: root.refreshResults()
            Keys.onReturnPressed: root.refreshResults()
        }

        Label {
            id: statusText
            text: "Type a pattern or rack letters"
            color: "#b8c3d6"
            font.pixelSize: 12
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: matches
            delegate: Rectangle {
                width: ListView.view.width
                height: 32
                color: index % 2 === 0 ? "#2a2f3a" : "#252b36"
                radius: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    text: modelData
                    color: "#f8f8f2"
                    font.pixelSize: 14
                }
            }
        }
    }
}
