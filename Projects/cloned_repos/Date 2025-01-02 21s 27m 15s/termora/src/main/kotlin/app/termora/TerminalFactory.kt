package app.termora

import app.termora.db.Database
import app.termora.terminal.*
import app.termora.terminal.panel.TerminalPanel
import java.awt.Color
import javax.swing.UIManager

class TerminalFactory {
    private val terminals = mutableListOf<Terminal>()

    companion object {
        val instance by lazy { TerminalFactory() }
    }

    fun createTerminal(): Terminal {
        val terminal = MyVisualTerminal()
        terminals.add(terminal)
        return terminal
    }

    fun getTerminals(): List<Terminal> {
        return terminals
    }

    private inner class MyVisualTerminal : VisualTerminal() {
        private val terminalModel by lazy { MyTerminalModel(this) }

        override fun getTerminalModel(): TerminalModel {
            return terminalModel
        }
    }

    private inner class MyTerminalModel(terminal: Terminal) : TerminalModelImpl(terminal) {
        private val colorPalette by lazy { MyColorPalette(terminal) }
        private val config get() = Database.instance.terminal

        init {
            setData(DataKey.CursorStyle, config.cursor)
            setData(TerminalPanel.Debug, config.debug)
        }

        override fun getColorPalette(): ColorPalette {
            return colorPalette
        }


        @Suppress("UNCHECKED_CAST")
        override fun <T : Any> getData(key: DataKey<T>): T {
            if (key == TerminalPanel.SelectCopy) {
                return config.selectCopy as T
            }
            return super.getData(key)
        }

        @Suppress("UNCHECKED_CAST")
        override fun <T : Any> getData(key: DataKey<T>, defaultValue: T): T {
            if (key == TerminalPanel.SelectCopy) {
                return config.selectCopy as T
            }
            return super.getData(key, defaultValue)
        }

        override fun getMaxRows(): Int {
            return config.maxRows
        }
    }

    class FlatLafColorTheme : ColorTheme {
        private fun Color.toRGB(): Int {
            return 65536 * red + 256 * green + blue
        }

        override fun getColor(color: TerminalColor): Int {
            val laf = UIManager.getLookAndFeel()
            if (laf is ColorTheme) {
                val c = laf.getColor(color)
                if (c != Int.MAX_VALUE) return c
            }

            return when (color) {
                TerminalColor.Basic.FOREGROUND -> UIManager.getColor("windowText").toRGB()
                TerminalColor.Basic.BACKGROUND -> UIManager.getColor("window").toRGB()
                TerminalColor.Basic.SELECTION_FOREGROUND -> UIManager.getColor("textHighlightText").toRGB()
                TerminalColor.Basic.SELECTION_BACKGROUND -> UIManager.getColor("textHighlight").toRGB()
                TerminalColor.Cursor.BACKGROUND -> getColor(TerminalColor.Basic.FOREGROUND)
                TerminalColor.Find.BACKGROUND -> UIManager.getColor("Component.warning.focusedBorderColor").toRGB()
                TerminalColor.Find.FOREGROUND -> UIManager.getColor("windowText").toRGB()
                TerminalColor.Basic.HYPERLINK -> UIManager.getColor("Hyperlink.linkColor")?.toRGB() ?: getColor(
                    TerminalColor.Basic.SELECTION_FOREGROUND
                )

                else -> DefaultColorTheme.instance.getColor(color)
            }

        }

    }

    private inner class MyColorPalette(terminal: Terminal) : ColorPaletteImpl(terminal) {
        private val colorTheme by lazy { FlatLafColorTheme() }
        override fun getTheme(): ColorTheme {
            return colorTheme
        }
    }
}