import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1180
    height: 760
    minimumWidth: 980
    minimumHeight: 680
    visible: true
    title: "TwinBench — M3 Live"
    color: "#15181d"

    readonly property color panel: "#20242b"
    readonly property color panel2: "#272c34"
    readonly property color textMain: "#edf0f3"
    readonly property color textMuted: "#9ca5af"
    readonly property color accent: "#63a7d8"
    readonly property color warning: "#d7a95b"
    readonly property color ok: "#77ae8b"
    property bool showFrozenCapture: false

    component ValueCard: Rectangle {
        property string label: ""
        property string value: ""
        property string unit: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 78
        radius: 7
        color: root.panel2
        border.color: "#343b45"
        Column {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 5
            Text { text: label; color: root.textMuted; font.pixelSize: 12 }
            Row {
                spacing: 5
                Text { text: value; color: root.textMain; font.pixelSize: 23; font.family: "Consolas" }
                Text { text: unit; color: root.textMuted; font.pixelSize: 13; anchors.baseline: parent.children[0].baseline }
            }
        }
    }

    component StatusTag: Rectangle {
        property string label: ""
        property bool active: false
        Layout.preferredWidth: 104
        Layout.preferredHeight: 30
        radius: 5
        color: active ? "#304a3b" : "#292e35"
        border.color: active ? root.ok : "#3b424c"
        Text { anchors.centerIn: parent; text: label; color: active ? "#dff2e5" : root.textMuted; font.pixelSize: 12 }
    }

    header: Rectangle {
        height: 58
        color: "#1c2026"
        border.color: "#303640"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 12
            Text { text: "TWINBENCH  /  TRANSLATION M3"; color: root.textMain; font.pixelSize: 18; font.weight: Font.DemiBold }
            Rectangle {
                width: 45; height: 22; radius: 4; color: "#3c3426"; border.color: root.warning
                Text { anchors.centerIn: parent; text: "POC"; color: "#f0d6a7"; font.pixelSize: 11; font.bold: true }
            }
            Rectangle {
                width: 92; height: 22; radius: 4; color: "#243b4b"; border.color: root.accent
                Text { anchors.centerIn: parent; text: backend.source; color: "#c8e7f8"; font.pixelSize: 11; font.bold: true }
            }
            Item { Layout.fillWidth: true }
            Text { text: backend.source === "SIMULATION" ? "FMU 10 ms  •  50 Hz = 1 m/s" : "Télémétrie UDP  •  lecture seule"; color: root.textMuted; font.pixelSize: 13 }
            Rectangle { width: 9; height: 9; radius: 5; color: backend.running ? root.ok : root.warning }
            Text { text: backend.running ? "EN COURS" : "PAUSE"; color: root.textMain; font.pixelSize: 13 }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 226
            radius: 8
            color: root.panel
            border.color: "#303640"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "POSITION DU CHARIOT"; color: root.textMuted; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Text { text: backend.position.toFixed(3) + " m"; color: root.textMain; font.pixelSize: 21; font.family: "Consolas" }
                }
                Item {
                    id: trackArea
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    property real leftX: 28
                    property real rightX: width - 28
                    function xForPosition(position) { return leftX + (Math.max(-0.3, Math.min(30.3, position)) + 0.3) / 30.6 * (rightX - leftX) }
                    Rectangle { x: trackArea.leftX; y: 43; width: trackArea.rightX-trackArea.leftX; height: 6; radius: 3; color: "#4a515b" }
                    Repeater {
                        model: [ {n:"TRÉMIE",p:0}, {n:"PV",p:5}, {n:"P2",p:15}, {n:"P1",p:20}, {n:"MAINT.",p:30} ]
                        delegate: Item {
                            x: trackArea.xForPosition(modelData.p) - 28
                            y: 14
                            width: 56
                            height: 60
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 24; width: 2; height: 25; color: "#727b86" }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.n; color: root.textMuted; font.pixelSize: 10 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 51; text: modelData.p + " m"; color: "#6f7882"; font.pixelSize: 9 }
                        }
                    }
                    Rectangle {
                        x: trackArea.xForPosition(backend.position) - width/2
                        y: 32
                        width: 34; height: 27; radius: 5
                        color: root.accent
                        border.color: "#b8dcf3"
                        Behavior on x { NumberAnimation { duration: 45 } }
                        Rectangle { x: 5; y: 23; width: 7; height: 7; radius: 4; color: "#101318" }
                        Rectangle { x: 22; y: 23; width: 7; height: 7; radius: 4; color: "#101318" }
                    }
                    Rectangle { x: trackArea.xForPosition(-0.3)-3; y: 35; width: 6; height: 22; color: root.warning }
                    Rectangle { x: trackArea.xForPosition(30.3)-3; y: 35; width: 6; height: 22; color: root.warning }
                }
                RowLayout {
                    Layout.fillWidth: true
                    StatusTag { label: "TRÉMIE"; active: backend.tremie }
                    StatusTag { label: "PV"; active: backend.pv }
                    StatusTag { label: "P2"; active: backend.p2 }
                    StatusTag { label: "P1"; active: backend.p1 }
                    StatusTag { label: "MAINTENANCE"; active: backend.maintenance }
                    Item { Layout.fillWidth: true }
                    Text { text: "Capteurs  " + backend.sensorsWord.toString(2).padStart(5,"0"); color: root.textMuted; font.family: "Consolas"; font.pixelSize: 12 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 5
                    color: "#191c21"
                    border.color: "#343944"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "ZOOM ACCOSTAGE · ±0,50 m · 2 s"; color: root.textMain; font.pixelSize: 10; font.weight: Font.DemiBold }
                            Item { Layout.fillWidth: true }
                            Text { text: backend.approachTargetLabel + " · écart " + backend.approachDistance.toFixed(3) + " m"; color: root.warning; font.pixelSize: 10; font.weight: Font.DemiBold }
                            Text { text: "freinage* " + backend.approachBrakingDistance.toFixed(3) + " m"; color: root.textMuted; font.pixelSize: 10 }
                        }
                        Canvas {
                            id: approachCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Connections { target: backend; function onTraceChanged() { approachCanvas.requestPaint() } function onStateChanged() { approachCanvas.requestPaint() } }
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var w = width, h = height, left = 42, right = 12, top = 3, bottom = 3
                                ctx.fillStyle = "#191c21"; ctx.fillRect(0, 0, w, h)
                                var target = backend.approachTargetPosition
                                var low = target - 0.5, high = target + 0.5
                                function posToX(position) { return left + (position - low) * (w-left-right) }
                                ctx.strokeStyle = "#343944"; ctx.lineWidth = 1
                                for (var tick = 0; tick <= 4; ++tick) {
                                    var x = left + (w-left-right) * tick / 4
                                    ctx.beginPath(); ctx.moveTo(x, top); ctx.lineTo(x, h-bottom); ctx.stroke()
                                }
                                ctx.setLineDash([4, 3]); ctx.strokeStyle = root.warning
                                var targetX = posToX(target)
                                ctx.beginPath(); ctx.moveTo(targetX, top); ctx.lineTo(targetX, h-bottom); ctx.stroke()
                                var secondary = backend.approachSecondaryPosition
                                if (secondary >= low && secondary <= high) {
                                    ctx.strokeStyle = "#d77b66"
                                    var secondX = posToX(secondary)
                                    ctx.beginPath(); ctx.moveTo(secondX, top); ctx.lineTo(secondX, h-bottom); ctx.stroke()
                                }
                                ctx.setLineDash([])
                                var points = backend.tracePoints
                                if (points.length < 2) return
                                var tMax = points[points.length-1][0]
                                var tMin = Math.max(0, tMax-2.0)
                                var started = false
                                ctx.strokeStyle = root.accent; ctx.lineWidth = 1.5; ctx.beginPath()
                                for (var i = 0; i < points.length; ++i) {
                                    if (points[i][0] < tMin || points[i][4] < low || points[i][4] > high) continue
                                    var y = top + (tMax-points[i][0]) / 2.0 * (h-top-bottom)
                                    if (!started) { ctx.moveTo(posToX(points[i][4]), y); started = true }
                                    else ctx.lineTo(posToX(points[i][4]), y)
                                }
                                ctx.stroke()
                                var current = points[points.length-1]
                                if (current[4] >= low && current[4] <= high) {
                                    var currentY = top + (tMax-current[0]) / 2.0 * (h-top-bottom)
                                    ctx.fillStyle = "#edf0f3"; ctx.beginPath(); ctx.arc(posToX(current[4]), currentY, 3, 0, Math.PI*2); ctx.fill()
                                }
                                ctx.fillStyle = "#9ca5af"; ctx.font = "9px Consolas"
                                ctx.fillText(low.toFixed(2)+" m", left, h-1)
                                ctx.fillText(high.toFixed(2)+" m", w-right-38, h-1)
                                if (secondary >= low && secondary <= high)
                                    ctx.fillText(backend.approachSecondaryLabel, Math.max(left, posToX(secondary)+3), 10)
                                ctx.fillText("cible", Math.max(left, targetX+3), h-1)
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: backend.hardStopTremie ? "BUTÉE MÉCANIQUE TRÉMIE" : (backend.hardStopMaintenance ? "BUTÉE MÉCANIQUE MAINTENANCE" : "BUTÉES MÉCANIQUES LIBRES"); color: backend.hardStop ? root.warning : root.textMuted; font.pixelSize: 10; font.bold: backend.hardStop }
                    Item { Layout.fillWidth: true }
                    Text { text: "* estimation visuelle"; color: root.textMuted; font.pixelSize: 9 }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                radius: 8
                color: root.panel
                border.color: "#303640"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10
                    Text { text: "COMMANDE LIVE"; color: root.textMuted; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Item {
                        id: joystick
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 240
                        Layout.preferredHeight: 102
                        Rectangle { anchors.centerIn: parent; width: 224; height: 58; radius: 29; color: "#171a1f"; border.color: "#444c56" }
                        Rectangle { x: parent.width/2-1; y: 30; width: 2; height: 42; color: "#59616b" }
                        Rectangle {
                            id: stick
                            width: 50; height: 50; radius: 25
                            x: (parent.width-width)/2 + backend.direction * 82
                            y: 26
                            color: root.accent
                            border.color: "#b8dcf3"
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: backend.source === "SIMULATION"
                            onPressed: updateAxis(mouse.x)
                            onPositionChanged: if (pressed) updateAxis(mouse.x)
                            onReleased: backend.manualJoystick(0)
                            function updateAxis(mouseX) { backend.manualJoystick(Math.max(-1, Math.min(1, (mouseX - width/2) / 82))) }
                        }
                        Text { anchors.left: parent.left; anchors.bottom: parent.bottom; text: "◀ TRÉMIE"; color: root.textMuted; font.pixelSize: 11 }
                        Text { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "MAINT. ▶"; color: root.textMuted; font.pixelSize: 11 }
                    }
                    Text { text: "Consigne fréquence  " + Math.round(freqSlider.value) + " Hz"; color: root.textMain; font.pixelSize: 13 }
                    Slider {
                        id: freqSlider
                        Layout.fillWidth: true
                        enabled: backend.source === "SIMULATION"
                        from: 0; to: 50; stepSize: 1; value: 40
                        onMoved: backend.frequencyRequest = value
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Button { text: backend.running ? "Pause" : "Démarrer"; Layout.fillWidth: true; enabled: backend.source === "SIMULATION"; onClicked: backend.running ? backend.pause() : backend.start() }
                        Button { text: "Reset P1"; enabled: backend.source === "SIMULATION"; onClicked: backend.reset() }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: backend.autoCycleActive ? "AUTO-CYCLE : STOP" : (backend.autoCycleCount > 0 ? "REJOUER AUTO-CYCLE" : "AUTO-CYCLE")
                            Layout.preferredWidth: 158
                            enabled: backend.source === "SIMULATION"
                            onClicked: backend.toggleAutoCycle()
                            background: Rectangle {
                                radius: 5
                                color: backend.autoCycleActive ? "#d7a95b" : "#63a7d8"
                                border.color: backend.autoCycleActive ? "#f0d6a7" : "#b8dcf3"
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "#15181d"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 5
                            color: backend.autoCycleActive ? "#304a3b" : (backend.autoCycleCount > 0 ? "#263442" : "transparent")
                            border.color: backend.autoCycleActive ? "#77ae8b" : (backend.autoCycleCount > 0 ? "#63a7d8" : "transparent")
                            Text {
                                anchors.fill: parent
                                anchors.margins: 5
                                text: backend.autoCycleActive ? backend.autoCyclePhaseText + " · " + backend.autoCycleCount + " cycle(s)" : (backend.autoCycleCount > 0 ? backend.autoCyclePhaseText + " · " + backend.autoCycleCount + " terminé(s)" : "Simulation seule")
                                color: "#edf0f3"
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#343a43" }
                    GridLayout {
                        columns: 2
                        Layout.fillWidth: true
                        Text { text: "Demande frein"; color: root.textMuted; font.pixelSize: 12 }
                        Text { text: backend.brakeRequestText; color: backend.source === "SIMULATION" && backend.brakeRequest ? root.warning : root.textMain; font.pixelSize: 12; font.bold: true }
                        Text { text: "Retour frein"; color: root.textMuted; font.pixelSize: 12 }
                        Text { text: backend.brakeOpen ? "OUVERT" : "APPLIQUÉ"; color: backend.brakeOpen ? root.ok : root.textMain; font.pixelSize: 12; font.bold: true }
                        Text { text: "Status variateur"; color: root.textMuted; font.pixelSize: 12 }
                        Text { text: "WORD#" + backend.driveStatusWord; color: root.textMain; font.family: "Consolas"; font.pixelSize: 12 }
                        Text { text: "Butée mécanique"; color: root.textMuted; font.pixelSize: 12 }
                        Text { text: backend.hardStop ? "ACTIVE" : "libre"; color: backend.hardStop ? root.warning : root.textMain; font.pixelSize: 12; font.bold: true }
                    }
                    Item { Layout.fillHeight: true }
                    Text { text: "Joystick prioritaire : il coupe AUTO-CYCLE au prochain pas de 10 ms."; color: root.textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true; font.pixelSize: 11 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    ValueCard { label: "CONSIGNE"; value: backend.frequencyCommand.toFixed(2); unit: "Hz" }
                    ValueCard { label: "MESURE VARIATEUR"; value: backend.frequencyActual.toFixed(2); unit: "Hz" }
                    ValueCard { label: "VITESSE"; value: backend.velocity.toFixed(3); unit: "m/s" }
                    ValueCard { label: backend.sampleCounterLabel; value: backend.scanCounter.toString(); unit: backend.sampleCounterUnit }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: root.panel
                    border.color: "#303640"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: root.showFrozenCapture ? "ACCOSTAGE BUTÉE — TRACE FIGÉE" : "TRACE LIVE — 2 SECONDES"; color: root.textMuted; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Button {
                                text: "LIVE"
                                onClicked: root.showFrozenCapture = false
                                background: Rectangle { radius: 4; color: root.showFrozenCapture ? root.panel2 : "#34516a" }
                                contentItem: Text { text: parent.text; color: root.textMain; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "CAPTURE BUTÉE"
                                enabled: backend.captureComplete
                                onClicked: root.showFrozenCapture = true
                                background: Rectangle { radius: 4; color: enabled ? (root.showFrozenCapture ? "#554326" : root.panel2) : "#25292f" }
                                contentItem: Text { text: parent.text; color: enabled ? root.textMain : root.textMuted; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle { width: 9; height: 9; radius: 5; color: root.accent }
                            Text { text: "Hz mesurés"; color: root.textMuted; font.pixelSize: 11 }
                            Rectangle { width: 16; height: 2; color: root.warning }
                            Text { text: "Hz consigne"; color: root.textMuted; font.pixelSize: 11 }
                            Text { text: root.showFrozenCapture ? backend.captureStatus : backend.tracePointLabel; color: root.showFrozenCapture ? root.warning : root.textMuted; font.pixelSize: 11 }
                        }
                        Canvas {
                            id: traceCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Connections {
                                target: backend
                                function onTraceChanged() { traceCanvas.requestPaint() }
                                function onCaptureChanged() {
                                    if (backend.captureComplete) root.showFrozenCapture = true
                                    traceCanvas.requestPaint()
                                }
                            }
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var w = width, h = height, left = 42, right = 12, top = 10, bottom = 28
                                ctx.fillStyle = "#191c21"; ctx.fillRect(0,0,w,h)
                                ctx.strokeStyle = "#333944"; ctx.lineWidth = 1
                                for (var y=0; y<=5; ++y) {
                                    var py = top + (h-top-bottom)*y/5
                                    ctx.beginPath(); ctx.moveTo(left,py); ctx.lineTo(w-right,py); ctx.stroke()
                                    ctx.fillStyle = "#7e8792"; ctx.font = "10px Consolas"; ctx.fillText((50-y*10).toString(), 8, py+3)
                                }
                                for (var x=0; x<=4; ++x) {
                                    var gridX = left + (w-left-right)*x/4
                                    ctx.beginPath(); ctx.moveTo(gridX,top); ctx.lineTo(gridX,h-bottom); ctx.stroke()
                                }
                                var pts = root.showFrozenCapture ? backend.frozenTracePoints : backend.tracePoints
                                if (pts.length < 2) return
                                var frozen = root.showFrozenCapture
                                var tMax = pts[pts.length-1][0]
                                var tMin = frozen ? backend.captureTriggerTime - 1.0 : Math.max(0, tMax-2.0)
                                var timeSpan = frozen ? 2.0 : 2.0
                                function timeToX(t) { return left + (t-tMin)/timeSpan*(w-left-right) }
                                function valueToY(v) { return top + (50-Math.max(0,Math.min(50,v)))/50*(h-top-bottom-2) }
                                ctx.strokeStyle = root.warning; ctx.lineWidth = 1.5; ctx.beginPath()
                                var started = false
                                for (var i=0; i<pts.length; ++i) if (pts[i][0] >= tMin) {
                                    if (!started) { ctx.moveTo(timeToX(pts[i][0]),valueToY(pts[i][1])); started=true } else ctx.lineTo(timeToX(pts[i][0]),valueToY(pts[i][1]))
                                }
                                ctx.stroke()
                                ctx.strokeStyle = root.accent; ctx.fillStyle = root.accent; ctx.lineWidth = 1.2; ctx.beginPath(); started=false
                                for (i=0; i<pts.length; ++i) if (pts[i][0] >= tMin) {
                                    var xx=timeToX(pts[i][0]), yy=valueToY(pts[i][2])
                                    if (!started) { ctx.moveTo(xx,yy); started=true } else ctx.lineTo(xx,yy)
                                }
                                ctx.stroke()
                                for (i=0; i<pts.length; ++i) if (pts[i][0] >= tMin) { ctx.beginPath(); ctx.arc(timeToX(pts[i][0]),valueToY(pts[i][2]),1.5,0,Math.PI*2); ctx.fill() }
                                if (frozen) {
                                    var triggerX = timeToX(backend.captureTriggerTime)
                                    ctx.setLineDash([4,3]); ctx.strokeStyle = root.warning; ctx.lineWidth = 1.2
                                    ctx.beginPath(); ctx.moveTo(triggerX,top); ctx.lineTo(triggerX,h-bottom); ctx.stroke(); ctx.setLineDash([])
                                    var selected = Math.max(0,Math.min(backend.capturePointIndex,pts.length-1))
                                    var cursorX = timeToX(pts[selected][0])
                                    ctx.strokeStyle = "#edf0f3"; ctx.lineWidth = 1
                                    ctx.beginPath(); ctx.moveTo(cursorX,top); ctx.lineTo(cursorX,h-bottom); ctx.stroke()
                                    ctx.fillStyle = "#7e8792"; ctx.font = "10px Consolas"
                                    ctx.fillText("−1 s",left,h-8); ctx.fillText("0 · BUTÉE",Math.max(left,triggerX+3),h-8); ctx.fillText("+1 s",w-right-35,h-8)
                                } else {
                                    ctx.fillStyle = "#7e8792"; ctx.font = "10px Consolas"; ctx.fillText(tMin.toFixed(2)+" s", left, h-8); ctx.fillText(tMax.toFixed(2)+" s", w-right-42, h-8)
                                }
                            }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: Math.max(0, backend.frozenTracePoints.length - 1)
                            value: backend.capturePointIndex
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            enabled: root.showFrozenCapture && backend.captureComplete
                            onMoved: backend.selectCapturePoint(Math.round(value))
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.showFrozenCapture
                            text: backend.captureReadout
                            color: root.textMain
                            font.family: "Consolas"
                            font.pixelSize: 10
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Temps simulé " + backend.simulationTime.toFixed(3) + " s"; color: root.textMuted; font.family: "Consolas"; font.pixelSize: 11 }
            Text { text: "  Ratio temps réel ×" + backend.realTimeRatio.toFixed(2); color: root.textMuted; font.family: "Consolas"; font.pixelSize: 11 }
            Text { text: "  HYPOTHÈSE: 50 Hz = 1 m/s"; color: root.warning; font.pixelSize: 10 }
            Text { text: "  BUTÉE +0,30 m après capteur"; color: root.warning; font.pixelSize: 10 }
            Item { Layout.fillWidth: true }
            Text { visible: backend.errorText.length > 0; text: backend.errorText; color: "#e28a8a"; font.pixelSize: 11 }
            Text { text: backend.stale ? "DONNÉES PERDUES" : (backend.source === "SIMULATION" ? "AUCUN PLC · AUCUNE SORTIE MACHINE" : "PLC · LECTURE SEULE"); color: backend.stale ? "#e28a8a" : root.textMuted; font.pixelSize: 11; font.weight: Font.DemiBold }
        }
    }
}
