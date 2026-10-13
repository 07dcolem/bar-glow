import QtQuick
import "../PlainEdit.js" as Edit

// Offscreen checks for the line editor. No clipboard and no TextInput.
Window {
  visible: true
  width: 20
  height: 20
  Component.onCompleted: {
    var failed = 0
    function check(name, cond) {
      if (!cond) {
        console.log("FAIL " + name)
        failed++
      }
    }

    var mid = Edit.insert("ab", 1, 1, "XY", 32)
    check("insert middle", mid.text === "aXYb" && mid.cursor === 3 && mid.anchor === 3)

    var capped = Edit.insert("", 0, 0, "abcdefghijklmnopqrstuvwxyz0123456789", 32)
    check("cap length", capped.text.length === 32 && capped.text === "abcdefghijklmnopqrstuvwxyz012345")

    var controls = Edit.insert("a", 1, 1, "b\n\u0000c\u007fd", 32)
    check("drop controls", controls.text === "abcd")

    var replaced = Edit.insert("hello", 1, 4, "i", 32)
    check("replace selection", replaced.text === "hio" && replaced.cursor === 2)

    var over = Edit.insert("abcd", 0, 2, "zzzz", 4)
    check("cap with selection", over.text === "zzcd" && over.text.length === 4)

    var bs = Edit.backspace("ab", 2, 2)
    check("backspace char", bs.text === "a" && bs.cursor === 1)
    var bsSel = Edit.backspace("hello", 1, 4)
    check("backspace selection", bsSel.text === "ho" && bsSel.cursor === 1)
    var bs0 = Edit.backspace("a", 0, 0)
    check("backspace at start", bs0.text === "a" && bs0.cursor === 0)

    var del = Edit.deleteForward("ab", 0, 0)
    check("delete char", del.text === "b" && del.cursor === 0)
    var delSel = Edit.deleteForward("hello", 4, 1)
    check("delete selection", delSel.text === "ho")

    var left = Edit.move("abcd", 2, 2, -1, false)
    check("move left", left.cursor === 1 && left.anchor === 1)
    var extend = Edit.move("abcd", 2, 2, 1, true)
    check("extend right", extend.cursor === 3 && extend.anchor === 2)
    var clamped = Edit.move("ab", 0, 0, -5, false)
    check("clamp move", clamped.cursor === 0)

    var start = Edit.home("abcd", 3, true)
    check("home extend", start.cursor === 0 && start.anchor === 3)
    var finish = Edit.end("abcd", 0, false)
    check("end", finish.cursor === 4 && finish.anchor === 4)

    check("normalize", Edit.normalize("a\nb\u0000c", 2) === "ab")
    check("usable rejects newline", Edit.usable("\n") === false)
    check("usable accepts hash", Edit.usable("#") === true)

    if (failed) {
      console.log(failed + " failed")
      Qt.exit(1)
    } else {
      console.log("plain-edit ok")
      Qt.exit(0)
    }
  }
}
